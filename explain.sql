-- var1: table expression

explain analyze
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
            left join consignment_note cn on c.id = cn.customer_id
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
order by 2 desc, 3 desc, 4 desc, 5 desc, 6 desc;
select
    pc.id as "pricelist_category",
    ni.registered_count as "notes registered",
    ni.canceled_count as "notes canceled",
    ci.active_count as "active customers",
    ci.total_count as "total customers",
    round(ci.active_count::decimal / (case when ci.total_count = 0 then 1 else ci.total_count end) * 100, 2) as "activity share, %"
from pricelist_category pc
    left join (
        select
            c.pricelist_category_id as pc_id,
            count(c.id) as total_count,
            sum(case when exists(select * from consignment_note where customer_id = c.id and current_timestamp - created < interval '1 year') then 1 else 0 end) as active_count
        from customer c
        group by pricelist_category_id
    ) as ci on ci.pc_id = pc.id
    left join (
        select
            pc.id as pc_id,
            sum(case when cn.is_canceled = false then 1 else 0 end) as registered_count,
            sum(case when cn.is_canceled = true then 1 else 0 end) as canceled_count
        from pricelist_category pc
            left join customer c on c.pricelist_category_id = pc.id
            left join consignment_note cn on c.id = cn.customer_id
        group by pc.id
    ) as ni on ni.pc_id = pc.id
order by 2 desc, 3 desc, 4 desc, 5 desc, 6 desc;


/*

Sort  (cost=29227.99..29228.24 rows=98 width=68) (actual time=0.188..0.191 rows=3 loops=1)
"  Sort Key: ni.registered_count DESC, ni.canceled_count DESC, (sum(CASE WHEN (alternatives: SubPlan 1 or hashed SubPlan 2) THEN 1 ELSE 0 END)) DESC, (count(c.id)) DESC, (round(((((sum(CASE WHEN (alternatives: SubPlan 1 or hashed SubPlan 2) THEN 1 ELSE 0 END)))::numeric / (CASE WHEN ((count(c.id)) = 0) THEN '1'::bigint ELSE (count(c.id)) END)::numeric) * '100'::numeric), 2)) DESC"
  Sort Method: quicksort  Memory: 25kB
  ->  Nested Loop  (cost=202.67..29224.75 rows=98 width=68) (actual time=0.165..0.180 rows=3 loops=1)
        ->  Hash Join  (cost=202.52..29167.19 rows=140 width=40) (actual time=0.148..0.155 rows=3 loops=1)
              Hash Cond: (c.pricelist_category_id = ni.pc_id)
              ->  GroupAggregate  (cost=100.64..29062.76 rows=200 width=20) (actual time=0.044..0.049 rows=3 loops=1)
                    Group Key: c.pricelist_category_id
                    ->  Sort  (cost=100.64..104.26 rows=1450 width=8) (actual time=0.013..0.014 rows=6 loops=1)
                          Sort Key: c.pricelist_category_id
                          Sort Method: quicksort  Memory: 25kB
                          ->  Seq Scan on customer c  (cost=0.00..24.50 rows=1450 width=8) (actual time=0.007..0.008 rows=6 loops=1)
                    SubPlan 1
                      ->  Seq Scan on consignment_note  (cost=0.00..39.92 rows=2 width=0) (never executed)
                            Filter: ((customer_id = c.id) AND ((CURRENT_TIMESTAMP - (created)::timestamp with time zone) < '1 year'::interval))
                    SubPlan 2
                      ->  Seq Scan on consignment_note consignment_note_1  (cost=0.00..36.60 rows=443 width=4) (actual time=0.010..0.014 rows=9 loops=1)
                            Filter: ((CURRENT_TIMESTAMP - (created)::timestamp with time zone) < '1 year'::interval)
                            Rows Removed by Filter: 1
              ->  Hash  (cost=100.14..100.14 rows=140 width=20) (actual time=0.098..0.099 rows=3 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 9kB
                    ->  Subquery Scan on ni  (cost=97.34..100.14 rows=140 width=20) (actual time=0.091..0.094 rows=3 loops=1)
                          ->  HashAggregate  (cost=97.34..98.74 rows=140 width=20) (actual time=0.090..0.093 rows=3 loops=1)
                                Group Key: pc_1.id
                                Batches: 1  Memory Usage: 40kB
                                ->  Hash Right Join  (cost=55.77..86.46 rows=1450 width=5) (actual time=0.065..0.083 rows=11 loops=1)
                                      Hash Cond: (c_1.pricelist_category_id = pc_1.id)
                                      ->  Hash Right Join  (cost=42.63..69.43 rows=1450 width=5) (actual time=0.037..0.049 rows=11 loops=1)
                                            Hash Cond: (cn.customer_id = c_1.id)
                                            ->  Seq Scan on consignment_note cn  (cost=0.00..23.30 rows=1330 width=5) (actual time=0.008..0.010 rows=10 loops=1)
                                            ->  Hash  (cost=24.50..24.50 rows=1450 width=8) (actual time=0.018..0.018 rows=6 loops=1)
                                                  Buckets: 2048  Batches: 1  Memory Usage: 17kB
                                                  ->  Seq Scan on customer c_1  (cost=0.00..24.50 rows=1450 width=8) (actual time=0.008..0.009 rows=6 loops=1)
                                      ->  Hash  (cost=11.40..11.40 rows=140 width=4) (actual time=0.025..0.025 rows=3 loops=1)
                                            Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                            ->  Seq Scan on pricelist_category pc_1  (cost=0.00..11.40 rows=140 width=4) (actual time=0.018..0.019 rows=3 loops=1)
        ->  Index Only Scan using pricelist_category_pkey on pricelist_category pc  (cost=0.14..0.40 rows=1 width=4) (actual time=0.006..0.006 rows=1 loops=3)
              Index Cond: (id = c.pricelist_category_id)
              Heap Fetches: 3
Planning Time: 0.665 ms
Execution Time: 0.369 ms


*/

-- var2: nested joins

explain analyze
select
    pc.id as "pricelist_category",
    ni.registered_count as "notes registered",
    ni.canceled_count as "notes canceled",
    ci.active_count as "active customers",
    ci.total_count as "total customers",
    round(ci.active_count::decimal / (case when ci.total_count = 0 then 1 else ci.total_count end) * 100, 2) as "activity share, %"
from pricelist_category pc
    left join (
        select
            c.pricelist_category_id as pc_id,
            count(c.id) as total_count,
            sum(case when exists(select * from consignment_note where customer_id = c.id and current_timestamp - created < interval '1 year') then 1 else 0 end) as active_count
        from customer c
        group by pricelist_category_id
    ) as ci on ci.pc_id = pc.id
    left join (
        select
            pc.id as pc_id,
            sum(case when cn.is_canceled = false then 1 else 0 end) as registered_count,
            sum(case when cn.is_canceled = true then 1 else 0 end) as canceled_count
        from pricelist_category pc
            left join customer c on c.pricelist_category_id = pc.id
            left join consignment_note cn on c.id = cn.customer_id
        group by pc.id
    ) as ni on ni.pc_id = pc.id
order by 2 desc, 3 desc, 4 desc, 5 desc, 6 desc;

/*

Sort  (cost=29189.42..29189.77 rows=140 width=68) (actual time=0.173..0.177 rows=3 loops=1)
"  Sort Key: ni.registered_count DESC, ni.canceled_count DESC, (sum(CASE WHEN (alternatives: SubPlan 1 or hashed SubPlan 2) THEN 1 ELSE 0 END)) DESC, (count(c.id)) DESC, (round(((((sum(CASE WHEN (alternatives: SubPlan 1 or hashed SubPlan 2) THEN 1 ELSE 0 END)))::numeric / (CASE WHEN ((count(c.id)) = 0) THEN '1'::bigint ELSE (count(c.id)) END)::numeric) * '100'::numeric), 2)) DESC"
  Sort Method: quicksort  Memory: 25kB
  ->  Hash Right Join  (cost=216.05..29184.43 rows=140 width=68) (actual time=0.151..0.166 rows=3 loops=1)
        Hash Cond: (c.pricelist_category_id = pc.id)
        ->  GroupAggregate  (cost=100.64..29062.76 rows=200 width=20) (actual time=0.043..0.048 rows=3 loops=1)
              Group Key: c.pricelist_category_id
              ->  Sort  (cost=100.64..104.26 rows=1450 width=8) (actual time=0.016..0.017 rows=6 loops=1)
                    Sort Key: c.pricelist_category_id
                    Sort Method: quicksort  Memory: 25kB
                    ->  Seq Scan on customer c  (cost=0.00..24.50 rows=1450 width=8) (actual time=0.009..0.010 rows=6 loops=1)
              SubPlan 1
                ->  Seq Scan on consignment_note  (cost=0.00..39.92 rows=2 width=0) (never executed)
                      Filter: ((customer_id = c.id) AND ((CURRENT_TIMESTAMP - (created)::timestamp with time zone) < '1 year'::interval))
              SubPlan 2
                ->  Seq Scan on consignment_note consignment_note_1  (cost=0.00..36.60 rows=443 width=4) (actual time=0.010..0.014 rows=9 loops=1)
                      Filter: ((CURRENT_TIMESTAMP - (created)::timestamp with time zone) < '1 year'::interval)
                      Rows Removed by Filter: 1
        ->  Hash  (cost=113.67..113.67 rows=140 width=20) (actual time=0.102..0.104 rows=3 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 9kB
              ->  Hash Left Join  (cost=101.89..113.67 rows=140 width=20) (actual time=0.098..0.101 rows=3 loops=1)
                    Hash Cond: (pc.id = ni.pc_id)
                    ->  Seq Scan on pricelist_category pc  (cost=0.00..11.40 rows=140 width=4) (actual time=0.016..0.016 rows=3 loops=1)
                    ->  Hash  (cost=100.14..100.14 rows=140 width=20) (actual time=0.077..0.079 rows=3 loops=1)
                          Buckets: 1024  Batches: 1  Memory Usage: 9kB
                          ->  Subquery Scan on ni  (cost=97.34..100.14 rows=140 width=20) (actual time=0.072..0.075 rows=3 loops=1)
                                ->  HashAggregate  (cost=97.34..98.74 rows=140 width=20) (actual time=0.072..0.074 rows=3 loops=1)
                                      Group Key: pc_1.id
                                      Batches: 1  Memory Usage: 40kB
                                      ->  Hash Right Join  (cost=55.77..86.46 rows=1450 width=5) (actual time=0.046..0.064 rows=11 loops=1)
                                            Hash Cond: (c_1.pricelist_category_id = pc_1.id)
                                            ->  Hash Right Join  (cost=42.63..69.43 rows=1450 width=5) (actual time=0.031..0.043 rows=11 loops=1)
                                                  Hash Cond: (cn.customer_id = c_1.id)
                                                  ->  Seq Scan on consignment_note cn  (cost=0.00..23.30 rows=1330 width=5) (actual time=0.008..0.010 rows=10 loops=1)
                                                  ->  Hash  (cost=24.50..24.50 rows=1450 width=8) (actual time=0.019..0.020 rows=6 loops=1)
                                                        Buckets: 2048  Batches: 1  Memory Usage: 17kB
                                                        ->  Seq Scan on customer c_1  (cost=0.00..24.50 rows=1450 width=8) (actual time=0.008..0.009 rows=6 loops=1)
                                            ->  Hash  (cost=11.40..11.40 rows=140 width=4) (actual time=0.011..0.011 rows=3 loops=1)
                                                  Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                                  ->  Seq Scan on pricelist_category pc_1  (cost=0.00..11.40 rows=140 width=4) (actual time=0.007..0.008 rows=3 loops=1)
Planning Time: 0.510 ms
Execution Time: 0.339 ms



*/

