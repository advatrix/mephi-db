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


create or replace procedure process_payment(
    in_consignment_note_id int,
    payment_sum numeric(8, 2)
)
language plpgsql
as
    $$
    declare
        new_payment_document_id int;
        total_consignment_payment_sum numeric(8, 2);
        total_consignment_cost numeric(8, 2);
    begin
        if (select cn.payment_document_id is not null from consignment_note cn where cn.id = in_consignment_note_id)
            then raise exception 'Consignment note has been already fully paid';
        end if;

        insert into "payment_document" (consignment_note_id, payment)
        values (in_consignment_note_id, payment_sum)
        returning id into new_payment_document_id;

        raise notice 'Successfully created new payment document with id %', new_payment_document_id;

        select sum(pi.price * cni.ordered) into total_consignment_cost
        from "consignment_note" cn
        join consignment_note_item cni on cn.id = cni.consignment_note_id
        join "pricelist" p on cn.pricelist_id = p.id
        join "pricelist_item" pi on p.id = pi.pricelist_id and pi.good_id = cni.good_id
        where cn.id = in_consignment_note_id;

        raise notice 'Total consignment cost: %', total_consignment_cost;

        select sum(pd.payment) into total_consignment_payment_sum
        from "consignment_note" cn
        join payment_document pd on cn.id = pd.consignment_note_id
        where cn.id = in_consignment_note_id;

        raise notice 'Total consignment payment sum (including current payment): %', total_consignment_payment_sum;

        if total_consignment_payment_sum >= total_consignment_cost then
            update consignment_note
            set
                paid = current_timestamp,
                payment_document_id = new_payment_document_id
            where id = in_consignment_note_id;

            raise notice 'Consignment note is fully paid!';
        else
            raise notice '% left to pay', total_consignment_cost - total_consignment_payment_sum;
        end if;

    end
    $$;