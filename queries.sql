-- compare this query with simply referring to count(customer) twice

with
    active_customers(count, pc_id) as (
        select count(c.id), c.pricelist_category_id
        from customer c
        where exists(select id from consignment_note where customer_id = c.id)
        group by c.pricelist_category_id
    ),
    total_customers(count, pc_id) as (
        select
            (select count(*) from (select distinct id from customer where pricelist_category_id = pc.id) sub),
            pc.id
        from pricelist_category pc
    )
select
    pc.id as "pricelist category",
    sum(case when cn.is_canceled = false then 1 else 0 end) as "notes registered",
    sum(case when cn.is_canceled = true then 1 else 0 end) as "notes canceled",
    coalesce(ac.count, 0) as "active customers",
    tc.count as "total customers",
    round(coalesce(ac.count, 0)::decimal / coalesce(tc.count, 1) * 100, 2) as "activity share"
from pricelist_category pc
    join total_customers tc on tc.pc_id = pc.id
    left join customer c on pc.id = c.pricelist_category_id
    left join consignment_note cn on c.id = cn.customer_id
    left join active_customers ac on ac.pc_id = pc.id
group by pc.id, ac.count, tc.count
order by 2 desc, 3 desc;


select
    c.id as "customer id",
    c.code as "customer code",
    c.registered as "registration date",
    l.inn as "inn",
    l.payment_account as "payment account",
    p.first_name as "first name",
    p.second_name as "second name",
    p.last_name as "last name",
    c.type as "customer type",
    coalesce(registered_count, 0) as "notes registered",
    coalesce(potential_income, 0) as "potential income",
    coalesce(canceled_count, 0) as "notes canceled",
    coalesce(unearned_income, 0) as "unearned income",
    coalesce(unpaid_count, 0) as "notes unpaid",
    coalesce(debt, 0) as "debt"
from customer c
    left join legal l on c.id = l.id
    left join person p on c.id = p.id
    left join (
        select
            cn.customer_id as customer_id,
            count(cn.id) as registered_count,
            sum(item_info.item_price) as potential_income
        from consignment_note cn
            left join (
                select
                    cni.consignment_note_id as cn_id,
                    sum(cni.ordered * pi.price) as item_price
                from consignment_note_item cni
                    join pricelist_item pi on cni.pricelist_id = pi.pricelist_id and cni.good_id = pi.good_id
                group by cn_id
            ) as item_info on item_info.cn_id = cn.id
        where not cn.is_canceled
        group by cn.customer_id
    ) as registered_notes on registered_notes.customer_id = c.id
    left join (
        select
            cn.customer_id as customer_id,
            count(cn.id) as canceled_count,
            sum(item_info.item_price) as unearned_income
        from consignment_note cn
            left join (
                select
                    cni.consignment_note_id as cn_id,
                    sum(cni.ordered * pi.price) as item_price
                from consignment_note_item cni
                    join pricelist_item pi on cni.pricelist_id = pi.pricelist_id and cni.good_id = pi.good_id
                group by cn_id
            ) as item_info on item_info.cn_id = cn.id
        where cn.is_canceled
        group by cn.customer_id
    ) as canceled_notes on canceled_notes.customer_id = c.id
    left join (
        select
            cn.customer_id as customer_id,
            count(cn.id) as unpaid_count,
            sum(item_info.item_price) - sum(payment_sum) as debt
        from consignment_note cn
            left join (
                select
                    cni.consignment_note_id as cn_id,
                    sum(cni.ordered * pi.price) as item_price
                from consignment_note_item cni
                    join pricelist_item pi on cni.pricelist_id = pi.pricelist_id and cni.good_id = pi.good_id
                group by cn_id
            ) as item_info on item_info.cn_id = cn.id
            left join (
                select
                    consignment_note_id as cn_id,
                    sum(payment) as payment_sum
                from payment_document
                group by consignment_note_id
            ) as payment_info on payment_info.cn_id = cn.id
        where cn.payment_document_id is null
        group by cn.customer_id
    ) as unpaid_notes on unpaid_notes.customer_id = c.id;
