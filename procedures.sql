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