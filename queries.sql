with
    customers_info(pc_id, total_count, active_count) as (
        select
            c.pricelist_category_id,
            count(c.id),
            sum(case when exists(select * from consignment_note where customer_id = c.id and current_timestamp - created < interval '1 year') then 1 else 0 end)
        from customer c
        group by pricelist_category_id
    ),
    notes_info(pc_id, registered_count, canceled_count) as (
        select
            pc.id,
            sum(case when cn.is_canceled = false then 1 else 0 end),
            sum(case when cn.is_canceled = true then 1 else 0 end)
        from pricelist_category pc
            left join customer c on c.pricelist_category_id = pc.id
            left join consignment_note cn on c.id = cn.customer_id and current_timestamp - cn.created < interval '1 year'
        group by pc.id
    )
select
    pc.id as "pricelist_category",
    ni.registered_count as "notes registered",
    ni.canceled_count as "notes canceled",
    ci.active_count as "active customers",
    ci.total_count as "total customers",
    round(ci.active_count::decimal / (case when ci.total_count = 0 then 1 else ci.total_count end) * 100, 2) as "activity share, %"
from pricelist_category pc
    join customers_info ci on ci.pc_id = pc.id
    join notes_info ni on ni.pc_id = pc.id
where ni.registered_count = (select max(registered_count) from notes_info);


select
    c.id as "customer id",
    c.code as "customer code",
    c.registered as "registration date",
    l.inn as "inn",
    l.payment_account as "payment account",
    l.name as "name",
    p.first_name as "first name",
    p.second_name as "second name",
    p.last_name as "last name",
    c.type as "customer type",
    coalesce(registered_count, 0) as "notes registered",
    coalesce(potential_income, 0) as "potential income",
    coalesce(canceled_count, 0) as "notes canceled",
    coalesce(lost_income, 0) as "unearned income",
    coalesce(unpaid_count, 0) as "notes unpaid",
    coalesce(debt, 0) as "debt"
from customer c
    left join legal l on c.id = l.id
    left join person p on c.id = p.id
    left join (
        select
            cn.customer_id as customer_id,
            sum(case when not cn.is_canceled then 1 else 0 end) as registered_count,
            sum(case when cn.is_canceled then 1 else 0 end) as canceled_count,
            sum(case when not cn.is_canceled then item_info.item_price else 0 end) as potential_income,
            sum(case when cn.is_canceled then item_info.item_price else 0 end) as lost_income,
            sum(case when cn.paid is null and not cn.is_canceled then 1 else 0 end) as unpaid_count,
            sum(case when not cn.is_canceled then item_info.item_price else 0 end) - sum(payment_sum) as debt
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
        group by cn.customer_id
    ) as notes_info on notes_info.customer_id = c.id
order by 13 desc;


select
    g.id,
    g.name as "name",
    coalesce(pricelist_info.pi_count, 0) as "pricelists count",
    coalesce(pricelist_info.avg_price, 0) as "average price",
    coalesce(income_info.total_ordered, 0) as "total ordered",
    coalesce(income_info.sales_count, 0) as "sales count",
    coalesce(income_info.sales_income, 0) as "sales income",
    coalesce(income_info.cancel_count, 0)  as "cancel count",
    coalesce(income_info.total_canceled, 0) as "total canceled",
    coalesce(income_info.lost_income, 0) as "lost income"
from good g
    left join (
        select
            sub.good_id as good_id,
            count(sub) as pi_count,
            avg(sub.price) as avg_price
        from (
            (
                select
                    pi.good_id as good_id,
                    pi.price as price
                from good g
                    join pricelist_item pi on g.id = pi.good_id
                    join pricelist p on pi.pricelist_id = p.id
                where p.created > current_date - interval '6 months'
            ) union all (
                select
                    pi2.good_id as good_id,
                    pi2.price as price
                from good g2
                    join pricelist_item pi2 on g2.id = pi2.good_id
                    join pricelist p2 on pi2.pricelist_id = p2.id
                where p2.created = (select max(created) from pricelist where created <= current_date - interval '6 months' and id = pi2.pricelist_id)
            )
        ) as sub
        group by sub.good_id
    ) as pricelist_info on pricelist_info.good_id = g.id
    left join (
        select
            cni.good_id as good_id,
            sum(case when not cn.is_canceled then 1 else 0 end) as sales_count,
            sum(case when not cn.is_canceled then cni.ordered else 0 end) as total_ordered,
            sum(case when not cn.is_canceled then cni.ordered * pi.price else 0 end) as sales_income,
            sum(case when cn.is_canceled then 1 else 0 end) as cancel_count,
            sum(case when cn.is_canceled then cni.ordered else 0 end) as total_canceled,
            sum(case when cn.is_canceled then cni.ordered * pi.price else 0 end) as lost_income
        from consignment_note_item cni
            join consignment_note cn on cni.consignment_note_id = cn.id
            join pricelist_item pi on pi.pricelist_id = cn.pricelist_id and pi.good_id = cni.good_id
        where cn.created >= current_date - interval '6 months'
        group by cni.good_id
    ) as income_info on income_info.good_id = g.id;


select
    p.id as "pricelist id",
    p.category_id as "category id",
    p.created as "created",
    coalesce(good_info.goods_count, 0) as "goods count",
    coalesce(customer_info.customers_count, 0) as "customers count"
from pricelist p
    left join (
        select
            cni.pricelist_id as "pricelist_id",
            count(distinct cni.good_id) as "goods_count"
        from consignment_note_item cni
        group by cni.pricelist_id
    ) as good_info on good_info.pricelist_id = p.id
    left join (
        select
            cn.pricelist_id as pricelist_id,
            count(distinct cn.customer_id) as customers_count
        from consignment_note cn
        group by cn.pricelist_id
    ) as customer_info on customer_info.pricelist_id = p.id
where not exists(
    select * from consignment_note where pricelist_id = p.id and current_timestamp - created <= interval '6 months'
);


select
    c.id as "customer id",
    c.code as "customer code",
    c.registered as "registration date",
    l.inn as "inn",
    l.payment_account as "payment account",
    l.name as "name",
    p.first_name as "first name",
    p.second_name as "second name",
    p.last_name as "last name",
    c.type as "customer type",
    cgipi.notes_count as "notes count",
    coalesce(cgipi.goods_ordered, 0) as "goods ordered",
    coalesce(cgipi.expected_income, 0) as "expected income",
    coalesce(cgipi.canceled_notes, 0) as "canceled notes",
    coalesce(cgipi.canceled_notes, 0) as "lost income",
    coalesce(cgipi.expected_income, 0) - coalesce(already_paid, 0) as "debt"
from customer c
    left join legal l on c.id = l.id
    left join person p on c.id = p.id
    join (
        select
            cn.customer_id as customer_id,
            count(cn) as notes_count,
            sum(goods_info.goods_ordered) as goods_ordered,
            sum(goods_info.expected_income) as expected_income,
            sum(case when cn.is_canceled = true then 1 else 0 end) as canceled_notes,
            sum(payment_info.already_paid) as already_paid,
            sum(goods_info.lost_income) as lost_income
        from consignment_note cn
            left join (
                select
                    cni.consignment_note_id as cn_id,
                    sum(case when not n.is_canceled then cni.ordered else 0 end) as goods_ordered,
                    sum(case when not n.is_canceled then cni.ordered * pi.price else 0 end) as expected_income,
                    sum(case when n.is_canceled then cni.ordered * pi.price else 0 end) as lost_income
                from consignment_note_item cni
                    join consignment_note n on cni.consignment_note_id = n.id
                    join pricelist_item pi on cni.pricelist_id = pi.pricelist_id and cni.good_id = pi.good_id
                where not n.is_canceled
                group by cni.consignment_note_id
            ) as goods_info on goods_info.cn_id = cn.id
            left join (
                select
                    pd.consignment_note_id as cn_id,
                    sum(pd.payment) as already_paid
                from payment_document pd
                group by pd.consignment_note_id
            ) as payment_info on payment_info.cn_id = cn.id
        where not cn.is_canceled
        group by cn.customer_id
    ) as cgipi on cgipi.customer_id = c.id
where not exists(
    select * from consignment_note where paid is not null and customer_id = c.id
);
