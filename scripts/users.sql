do $$
begin
	if not exists (select 1 from pg_user where usename = 'bob') then
		create user bob with login password 'bob';
		grant select on all tables in schema public to bob;
	end if;
	if not exists (select 1 from pg_user where usename = 'dave') then
		create user dave with login password 'dave';
		grant insert, select, update, delete on all tables in schema public to dave;
	end if;
end$$;