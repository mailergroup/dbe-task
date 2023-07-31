# DBE task
# Provisioning the infraestructure


We need to clone the repository and build the image with docker compose
I choosed and tests with PostgreSQL 14.6 but we can manage that dynamically, we can use version 15 without problems by example.

``` bash
docker-compose build --build-arg POSTGRES_VERSION=14.6
```

And then startup the database

``` bash
docker-compose up
```

Now we need to execute automation for roles.

``` bash
cd terraform
terraform init
terraform plan
terraform apply
```

To check the grants of bob and dave, we can get the passwords on the output of terraform apply and connect on database.

That's it!

# Explaining my strategy

I builded the docker image using a old project of mine, i use this image a lot to do local tests because the database start with a lot of extensions and configurations, this helped me a lot on this task to configure pg_partman and schedule the maintenances with pg_cron. My repo link https://github.com/brunobrn/fully-extension-docker-postgres

I choosed fix the configuration file to startup the databse already ready, the partitions, indexes and FK's created at the first startup of the database, the project of a new app/database has to be correclty planned at the begging.

But also we have things to manage when the database/app is already running and we can do all of that with no downtime.

Create indexes,FKs, adjusts of autovacuum, fillfactor or partition a table after the database is running is simple too.

We can create a index with CONCURRENTLY, FKs with not valid option and for partition we can create a simple automation in ansible to rename and populate the new partition table with the old data.

For the automation i choosed terraform because of the statefile, we can upload the statefile to cloud and manage it from there.

For the queries, time of execution is relative, what really matters is the costs and how many hits we need to do on storage.

## Queries
1. Benchmark some common queries.
   
Before we start query by query, the queries asked here basically are for reports, we need to hit the storage frequently to bring the data, to improve this we can parition some tables and create some indexes on PKs, FKs and related columns. And for this queries unfortunately i don't finded a good way to create partial indexes.

   - Retrieve the names of customers who have placed orders in the last 30 days

I do a CTE query getting the orders from the last 30 days and group by the customer_id to bring only one name by row. In second part of the CTE i concat the first and last name joining it customers table

The partition by week here will work well, but we cannot partition by range on order_id and order_date, because we will lose the data consistency between orders and order_items tables.

```SQL
WITH CTE AS
	(SELECT DISTINCT O.CUSTOMER_ID
		FROM ORDERS O
		WHERE O.ORDER_DATE > NOW() - interval '30 day')
SELECT CONCAT(C.FIRST_NAME || ' ' || C.LAST_NAME) AS FULL_NAME
FROM CUSTOMERS C
JOIN CTE D ON C.CUSTOMER_ID = D.CUSTOMER_ID;
```
Costs
```
Hash Join  (cost=623.71..788.11 rows=3319 width=32) (actual time=17.075..20.316 rows=2996 loops=1)
  Output: concat((((c.first_name)::text || ' '::text) || (c.last_name)::text))
  Inner Unique: true
  Hash Cond: (c.customer_id = o.customer_id)
  Buffers: shared hit=170
  ->  Append  (cost=0.00..130.78 rows=3319 width=43) (actual time=0.014..1.209 rows=3000 loops=1)
        Buffers: shared hit=42
        ->  Seq Scan on public.customers_p0 c_1  (cost=0.00..22.99 rows=999 width=19) (actual time=0.013..0.190 rows=999 loops=1)
              Output: c_1.first_name, c_1.last_name, c_1.customer_id
              Buffers: shared hit=13
        ->  Seq Scan on public.customers_p1000 c_2  (cost=0.00..24.00 rows=1000 width=23) (actual time=0.011..0.316 rows=1000 loops=1)
              Output: c_2.first_name, c_2.last_name, c_2.customer_id
              Buffers: shared hit=14
        ->  Seq Scan on public.customers_p2000 c_3  (cost=0.00..24.00 rows=1000 width=23) (actual time=0.009..0.282 rows=1000 loops=1)
              Output: c_3.first_name, c_3.last_name, c_3.customer_id
              Buffers: shared hit=14
        ->  Seq Scan on public.customers_p3000 c_4  (cost=0.00..10.80 rows=80 width=240) (actual time=0.004..0.005 rows=1 loops=1)
              Output: c_4.first_name, c_4.last_name, c_4.customer_id
              Buffers: shared hit=1
        ->  Seq Scan on public.customers_p4000 c_5  (cost=0.00..10.80 rows=80 width=240) (actual time=0.002..0.002 rows=0 loops=1)
              Output: c_5.first_name, c_5.last_name, c_5.customer_id
        ->  Seq Scan on public.customers_p5000 c_6  (cost=0.00..10.80 rows=80 width=240) (actual time=0.002..0.002 rows=0 loops=1)
              Output: c_6.first_name, c_6.last_name, c_6.customer_id
        ->  Seq Scan on public.customers_default c_7  (cost=0.00..10.80 rows=80 width=240) (actual time=0.001..0.001 rows=0 loops=1)
              Output: c_7.first_name, c_7.last_name, c_7.customer_id
  ->  Hash  (cost=586.26..586.26 rows=2996 width=4) (actual time=17.045..17.046 rows=2996 loops=1)
        Output: o.customer_id
        Buckets: 4096  Batches: 1  Memory Usage: 138kB
        Buffers: shared hit=128
        ->  HashAggregate  (cost=526.34..556.30 rows=2996 width=4) (actual time=15.468..16.184 rows=2996 loops=1)
              Output: o.customer_id
              Group Key: o.customer_id
              Batches: 1  Memory Usage: 369kB
              Buffers: shared hit=128
              ->  Seq Scan on public.orders o  (cost=0.00..478.00 rows=19334 width=4) (actual time=0.007..9.561 rows=19334 loops=1)
                    Output: o.order_id, o.customer_id, o.shop_id, o.order_date, o.total_amount
                    Filter: (o.order_date > (now() - '30 days'::interval))
                    Rows Removed by Filter: 666
                    Buffers: shared hit=128
Query Identifier: -2651271541265055639
Planning:
  Buffers: shared hit=9
Planning Time: 0.465 ms
Execution Time: 20.633 ms
```


With the CTE and select distinct we reduce the cost of hash join.

- Calculate the total revenue generated by the e-commerce shop for a specific date range.

A simple query here, aggregate functions is always a problem in huge tables, maybe we have other options like a M View or a trigger function to control amount by day in other table.
Creating a index on orders table and putting order_date column twice we can reduce the storage hits searching for date ranges.


```SQL
SELECT SUM(TOTAL_AMOUNT) AS AMOUNT
FROM PUBLIC.ORDERS O
WHERE O.ORDER_DATE >= '2023-07-15'
AND O.ORDER_DATE <= '2023-07-27';

-- OR
	
SELECT SUM(TOTAL_AMOUNT) AS AMOUNT
FROM PUBLIC.ORDERS O
WHERE O.ORDER_DATE between '2023-07-15'
AND  '2023-07-27';
```
costs
```
Aggregate  (cost=404.91..404.92 rows=1 width=32) (actual time=5.510..5.512 rows=1 loops=1)
  Output: sum(total_amount)
  Buffers: shared hit=138
  ->  Bitmap Heap Scan on public.orders o  (cost=125.17..383.23 rows=8671 width=6) (actual time=0.470..2.524 rows=8671 loops=1)
        Output: order_id, customer_id, shop_id, order_date, total_amount
        Recheck Cond: ((o.order_date >= '2023-07-15'::date) AND (o.order_date <= '2023-07-27'::date))
        Heap Blocks: exact=128
        Buffers: shared hit=138
        ->  Bitmap Index Scan on orders_order_date_order_date_idx  (cost=0.00..123.00 rows=8671 width=0) (actual time=0.430..0.431 rows=8671 loops=1)
              Index Cond: ((o.order_date >= '2023-07-15'::date) AND (o.order_date <= '2023-07-27'::date))
              Buffers: shared hit=10
Query Identifier: 7079703650810536227
Planning Time: 0.233 ms
Execution Time: 5.558 ms
```

- Find the top-selling products based on the quantity sold.

A simple CTE with a join between order_items and products table geting the sum of products grouping by product_id.
The CTE here will help us to reduce the SORT operation costs.

```SQL
WITH CTE AS
	(SELECT O.PRODUCT_ID AS PRODUCT_ID,
			SUM(O.QUANTITY) AS QUANTITY_SOLD
		FROM ORDER_ITEMS O
		GROUP BY PRODUCT_ID)
SELECT PRODUCT_NAME,
	QUANTITY_SOLD
FROM CTE
JOIN PRODUCTS P ON P.PRODUCT_ID = CTE.PRODUCT_ID
ORDER BY QUANTITY_SOLD DESC;
```
costs
```
Sort  (cost=1676.55..1679.05 rows=1000 width=18) (actual time=32.754..32.878 rows=1000 loops=1)
  Output: p.product_name, cte.quantity_sold
  Sort Key: cte.quantity_sold DESC
  Sort Method: quicksort  Memory: 87kB
  Buffers: shared hit=528
  ->  Hash Join  (cost=1603.09..1626.72 rows=1000 width=18) (actual time=31.588..32.257 rows=1000 loops=1)
        Output: p.product_name, cte.quantity_sold
        Inner Unique: true
        Hash Cond: (p.product_id = cte.product_id)
        Buffers: shared hit=528
        ->  Seq Scan on public.products p  (cost=0.00..21.00 rows=1000 width=14) (actual time=0.010..0.185 rows=1000 loops=1)
              Output: p.product_id, p.shop_id, p.product_name, p.price, p.description
              Buffers: shared hit=11
        ->  Hash  (cost=1590.59..1590.59 rows=1000 width=12) (actual time=31.570..31.572 rows=1000 loops=1)
              Output: cte.quantity_sold, cte.product_id
              Buckets: 1024  Batches: 1  Memory Usage: 51kB
              Buffers: shared hit=517
              ->  Subquery Scan on cte  (cost=1570.59..1590.59 rows=1000 width=12) (actual time=30.835..31.278 rows=1000 loops=1)
                    Output: cte.quantity_sold, cte.product_id
                    Buffers: shared hit=517
                    ->  HashAggregate  (cost=1570.59..1580.59 rows=1000 width=12) (actual time=30.832..31.101 rows=1000 loops=1)
                          Output: o.product_id, sum(o.quantity)
                          Group Key: o.product_id
                          Batches: 1  Memory Usage: 193kB
                          Buffers: shared hit=517
                          ->  Seq Scan on public.order_items o  (cost=0.00..1219.39 rows=70239 width=8) (actual time=0.002..7.526 rows=70239 loops=1)
                                Output: o.order_item_id, o.order_id, o.product_id, o.shop_id, o.quantity, o.subtotal
                                Buffers: shared hit=517
Query Identifier: -2735059738195607728
Planning Time: 0.174 ms
Execution Time: 33.010 ms
```


# Roles

2. Create some roles and permissions
   - Create a user for "bob" and grant read only permissions.
   - Create a user for "dave" and grant read write permissions.

Running the terraform configuration files we will create the two roles with the correct grants and generating random passawords.

This passwords needs to be sensitivy and the database password has to be encrypted in a vault, this is only a test but we can startup a hashicorp vault and put the this secrets there and manage from there, never in any corporate environment we manage the passwords like this.

The grants are in <b>main.tf</b> file after line 26

3. Review the database schema and implement any improvements or optimizations, you could make for better performance and scalability.

Looking in to the tables structure, i missed a table with more data about shopping stores, so i create the <b>shop_stores</b> i put some random data like in other tables, this will help us to make better reports using these data.

I fixed the consistency problem with FKs between all the tables, this will help us to mantain the consistency and realibility of the data stored. I also fixed some not null values on tables.

For tables shop_stores,orders and products i configure the fillfactor in 70 percent, we can change this parameter with more accuracy when we got more data about the DML operations on this tables, the fillfactor parameter will help us to do hotupdates on this tables. To do this we need to configure our updates statements correctly to avoid update indexed columns.

I dont configure any autovacuum configurations because i need more data with the appplication already running, to do fine adjustments at table level.

I adjust some parameters for improve querie performance and help with automavacuum jobs.

``` SQL
alter system set work_mem = 8192;
alter system set max_worker_processes = 16;
alter system set max_parallel_workers_per_gather = 4;
alter system set max_parallel_maintenance_workers = 8;
alter system set wal_buffers = 16384;
```

4. Identify the tables that can benefit from partitioning based on their characteristics and usage patterns.

The customers table will not be a good option when the database are small, but when the database grow up this will help us to recuce hits on storage and use less CPU.

The orders table can be partioned too, but we need change somethings in the app code to undestand this change. Do the partition by range on order_id and order_date will help us a lot on the future, but doing this right now we will lose the consistence of data between orders and order_items tables.
This effort will be rewarded in the future with less maintence work and incredible performance gains. (We need to do our JOB as a DBA but always together with the development team)


5. Design a partitioning strategy for the selected tables, considering factors such as data distribution, query patterns, and data growth. Document and implement the partitioning strategy.

I partitioned only the customers table as i explained above, this solve problems like data distruibution and data growth. Query patterns has always to use our created indexes, but if we add new queries in the future and we need to create other indexes, this definitely will not be a problem.

The paritions will be created at the start of the database, the DDL codes is already on the init.sql file doing the creations automatically when we up the docker-compose. But we can do all this adjustments with the database running.