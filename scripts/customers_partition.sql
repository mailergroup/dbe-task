do $$
begin
	if not exists (select 1 from pg_tables where tablename = 'customers_old') then
		CREATE TABLE public.customers_p (
			customer_id int4 NOT NULL,
			shop_id int4 NULL,
			first_name varchar(50) NULL,
			last_name varchar(50) NULL,
			email varchar(100) NULL,
			address varchar(200) NULL,
			phone_number varchar(20) NULL,
			CONSTRAINT customers_pkey_pt PRIMARY KEY (customer_id)
		)
		partition by range (customer_id)
		;

		create table public.customers_p_1_to_1000 partition of public.customers_p
		for values from (1) to (1000); 

		create table public.customers_p_1000_to_2000 partition of public.customers_p
		for values from (1000) to (2000);

		create table public.customers_p_2000_to_3000 partition of public.customers_p
		for values from (2000) to (3001);

		create table public.customers_p_default partition of public.customers_p default;

		insert into public.customers_p select * from public.customers;

		alter table public.customers rename to customers_old;

		alter table public.customers_p rename to customers;
	end if;
end $$;