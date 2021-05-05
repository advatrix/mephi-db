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
order by 2 desc;
