do $$
begin
	if not exists (select 1 from pg_tables where tablename = 'orders_old') then
		CREATE TABLE public.orders_p (
			order_id int4 NOT NULL,
			customer_id int4 NULL,
			shop_id int4 NULL,
			order_date date NULL,
			total_amount numeric(10, 2) NULL,
			CONSTRAINT orders_pkey_p PRIMARY KEY (order_id),
			CONSTRAINT fk_order_customer_id_p FOREIGN KEY (customer_id) REFERENCES public.customers(customer_id)
		)
		partition by range (order_id)
		;

		CREATE INDEX idx_order_date_p ON public.orders_p (order_date);

		create table public.orders_p_1_to_5000 partition of public.orders_p
		for values from (1) to (5001); 

		create table public.orders_p_5001_to_10000 partition of public.orders_p
		for values from (5001) to (10001);

		create table public.orders_p_10001_to_15000 partition of public.orders_p
		for values from (10001) to (15001);

		create table public.orders_p_15001_to_20000 partition of public.orders_p
		for values from (15001) to (20001);

		create table public.orders_p_default partition of public.orders_p default;

		insert into public.orders_p select * from public.orders;

		alter table public.orders rename to orders_old;

		alter table public.orders_p rename to orders;
	end if;
end $$;