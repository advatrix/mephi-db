-- регистрация частного или юридического лица

create or replace procedure register_customer(
    in_code int8,
    in_type char,
    in_pricelist_category_id int,
    in_name varchar(256) = null,
    in_payment_account int8 = null,
    in_first_name varchar(50) = null,
    in_second_name varchar(50) = null,
    in_last_name varchar(50) = null
)
language plpgsql
as
    $$
    declare
        new_id int;
    begin
        if exists(select * from customer c where c.code = in_code) then raise exception 'Customer already exists';
        end if;

        insert into "customer" (pricelist_category_id, type, code)
        values (in_pricelist_category_id, in_type, in_code)
        returning id into new_id;

        if in_type = 'l' then
            insert into "legal" (id, inn, name, payment_account)
            values (new_id, in_code, in_name, in_payment_account);
        else
            insert into "person" (id, first_name, second_name, last_name, passport)
            values (new_id, in_first_name, in_second_name, in_last_name, in_code);
        end if;

        raise notice 'Successfully registered new customer with id = %', new_id;
    end
    $$;

-- оплата накладной

create or replace procedure process_payment(
    in in_consignment_note_id int,
    in payment_sum numeric(8, 2),
    in in_customer_id int,
    inout result varchar(255) = null,
    inout debt numeric(8, 2) = null
)
language plpgsql
as
    $$
    declare
        new_payment_document_id int;
        total_consignment_payment_sum numeric(8, 2);
        total_consignment_cost numeric(8, 2);
    begin

        if not exists(select id from consignment_note where id = in_consignment_note_id) then
            result := 'Consignment note not exists';
            return;
        end if;

        if (select customer_id from consignment_note where id = in_consignment_note_id) != in_customer_id then
            result := 'Wrong customer';
            return;
        end if;

        if (select cn.payment_document_id is not null from consignment_note cn where cn.id = in_consignment_note_id)
            then
            result := 'Consignment note is already fully paid';
            return;
        end if;

        select sum(pi.price * cni.ordered) into total_consignment_cost
        from "consignment_note" cn
        join consignment_note_item cni on cn.id = cni.consignment_note_id
        join "pricelist" p on cn.pricelist_id = p.id
        join "pricelist_item" pi on p.id = pi.pricelist_id and pi.good_id = cni.good_id
        where cn.id = in_consignment_note_id;

        raise notice 'Total consignment cost: %', total_consignment_cost;

        select coalesce(sum(pd.payment), 0) + payment_sum into total_consignment_payment_sum
        from "consignment_note" cn
        join payment_document pd on cn.id = pd.consignment_note_id
        where cn.id = in_consignment_note_id;

        raise notice 'Total consignment payment sum (including current payment): %', total_consignment_payment_sum;

        if total_consignment_payment_sum >= total_consignment_cost then

            insert into "payment_document" (consignment_note_id, payment)
            values (in_consignment_note_id, total_consignment_cost - total_consignment_payment_sum + payment_sum)
            returning id into new_payment_document_id;

            update consignment_note
            set
                paid = current_timestamp,
                payment_document_id = new_payment_document_id
            where id = in_consignment_note_id;

            result := 'Consignment note is fully paid';

        else
            insert into "payment_document" (consignment_note_id, payment)
            values (in_consignment_note_id, payment_sum);

            result := 'Success';
        end if;

        debt := total_consignment_cost - total_consignment_payment_sum;

    end
    $$;

-- поступление товара на склад

create or replace procedure process_supply(
    in in_good_id int, -- may be null when supplying a new good
    in in_quantity int,
    in in_name varchar(255) = null,
    inout count int = 0
)
language plpgsql
as
    $$
    declare
        c_cni refcursor;
        rec_cni record;
        good_quantity int;
        to_reserve int;
    begin
        if in_good_id is null then -- new good, insertion
            if exists(select * from good where name = in_name) then raise exception 'Good with this name already exists';
            else
                insert into good (name, quantity)
                values (in_name, in_quantity);
            end if;
        else -- updating
            update good
            set quantity = quantity + in_quantity
            where id = in_good_id
            returning quantity into good_quantity;

            open c_cni for
                select cni.consignment_note_id, cni.good_id, cni.pricelist_id
                from consignment_note_item cni
                join consignment_note cn on cni.consignment_note_id = cn.id
                where good_id = in_good_id and ordered != reserved
                order by cn.created;

            loop
                fetch next from c_cni into rec_cni;
                exit when rec_cni is null;

                count := count + 1;

                raise notice 'fetched next from cursor: pl_id = %, g_id = %, cn_id = %', rec_cni.pricelist_id, rec_cni.good_id, rec_cni.consignment_note_id;
                raise notice 'good quantity = %', good_quantity;

                select ordered - reserved into to_reserve
                from consignment_note_item
                where
                    pricelist_id = rec_cni.pricelist_id
                    and good_id = rec_cni.good_id
                    and consignment_note_id = rec_cni.consignment_note_id;

                raise notice 'to reserve = %', to_reserve;

                if good_quantity >= to_reserve then
                    update consignment_note_item
                    set
                        reserved = reserved + to_reserve
                    where
                        pricelist_id = rec_cni.pricelist_id
                        and good_id = rec_cni.good_id
                        and consignment_note_id = rec_cni.consignment_note_id;

                    good_quantity := good_quantity - to_reserve;
                else
                    update consignment_note_item
                    set
                        reserved = reserved + good_quantity
                    where
                        pricelist_id = rec_cni.pricelist_id
                        and good_id = rec_cni.good_id
                        and consignment_note_id = rec_cni.consignment_note_id;

                    good_quantity := 0;

                    exit;
                end if;
            end loop;

            update good set quantity = good_quantity where id = in_good_id;

            raise notice 'quantity: % updated to good', good_quantity;
        end if;
    end
    $$;