--Indexes
create index if not exists idx_shop_cust on public.customers(shop_id);

create index if not exists idx_comp_oi on public.order_items(order_id, product_id, shop_id);

create index if not exists idx_order_date on public.orders(order_date);

--Constraints
do $$
begin
	if (select count(1) from pg_constraint where conname = 'fk_order_customer_id') = 0 then
	  alter table orders add constraint fk_order_customer_id foreign key(customer_id) references customers(customer_id);
	 end if;
end$$;

do $$
begin
	if (select count(1) from pg_constraint where conname = 'fk_oi_order_id') = 0 then
	  alter table order_items add constraint fk_oi_order_id foreign key(order_id) references orders(order_id);
	 end if;
end$$;

do $$
begin
	if (select count(1) from pg_constraint where conname = 'fk_oi_product_id') = 0 then
	  alter table order_items add constraint fk_oi_product_id foreign key(product_id) references products(product_id);
	 end if;
end$$;