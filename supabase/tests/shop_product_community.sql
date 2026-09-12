-- ONLY for an empty, ephemeral PostgreSQL database named shop_community_test.
-- No production credentials, Supabase link, or real customer records are used.
\set ON_ERROR_STOP on
do $$ begin
  if current_database() <> 'shop_community_test' then
    raise exception 'Ephemeral database required';
  end if;
end $$;
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema public, auth to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;
-- Supabase-style grants: the feature migration must explicitly remove them.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
create schema storage;
create table storage.buckets(id text primary key, name text, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);

\ir ../migrations/20260728010000_create_shop_product_downloads.sql
\ir ../migrations/20260821015546_generalize_digital_product_store.sql
update public.shop_products set is_active = true,
  sha256 = '66bf4bf96459b3d8cf2c35785e91c5cc0d75f2fb89a8993f3b379727cafc6490'
  where id = 'hexciv-win64';
insert into public.shop_products(id,name_ja,price_jpy,storage_path,version,is_active)
  values ('other','Other product',500,'private.zip','2.0',true);
insert into auth.users values
  ('00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000000002'),
  ('00000000-0000-4000-8000-000000000003');
insert into public.shop_purchases(user_id,product_id,amount_jpy,status) values
  ('00000000-0000-4000-8000-000000000001','hexciv-win64',500,'paid'),
  ('00000000-0000-4000-8000-000000000002','hexciv-win64',500,'paid'),
  ('00000000-0000-4000-8000-000000000001','other',500,'paid');

\ir ../migrations/20260912041437_shop_product_releases_reviews.sql

create function public.test_assert(ok boolean, message text) returns void
language plpgsql security invoker as $$ begin
  if ok is distinct from true then raise exception 'FAIL: %', message; end if;
  raise notice 'PASS: %', message;
end $$;
create function public.test_denied(statement text, expected_state text) returns void
language plpgsql security invoker as $$ begin
  begin
    execute statement;
  exception when others then
    if sqlstate = expected_state then
      raise notice 'PASS: denied with %', expected_state;
      return;
    end if;
    raise;
  end;
  raise exception 'FAIL: statement unexpectedly allowed';
end $$;
grant execute on function public.test_assert(boolean,text), public.test_denied(text,text) to anon, authenticated;

insert into public.shop_product_releases(product_id,release_key,version,title_ja,notes_ja,is_published,published_at)
values ('hexciv-win64','draft','2','Draft','Not public',false,null),
  ('hexciv-win64','future','3','Future','Scheduled',true,now()+interval '1 year');

set role anon;
select public.test_assert((select count(*) = 1 from public.shop_product_releases), 'only published, non-future release');
select public.test_assert((select published_at is null from public.shop_product_releases), 'unknown release date remains unknown');
select public.test_assert(public.get_shop_product_reviews('hexciv-win64')->>'count' = '0', 'empty count');
select public.test_assert(public.get_shop_product_reviews('hexciv-win64')->'average' = 'null'::jsonb, 'no fabricated average');
select public.test_denied($q$select public.save_shop_product_review('hexciv-win64',5,'bad')$q$, '42501');
select public.test_denied('select * from shop_review_private.owners', '42501');
select public.test_denied($q$insert into public.shop_product_releases(product_id,release_key,version,title_ja,notes_ja) values('other','bad','1','bad','bad')$q$, '42501');
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',false);
select public.test_denied($q$select public.save_shop_product_review('hexciv-win64',5,'unpaid')$q$, '42501');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
select public.test_denied($q$select public.save_shop_product_review('hexciv-win64',0,'bad')$q$, '22023');
select public.test_denied($q$select public.save_shop_product_review('hexciv-win64',6,'bad')$q$, '22023');
select public.test_denied($q$select public.save_shop_product_review('hexciv-win64',5,repeat('字',2001))$q$, '22023');
select public.save_shop_product_review('hexciv-win64',5,' 最初の口コミ ');
select public.test_assert(public.get_my_shop_product_review('hexciv-win64')->'review'->>'body' = '最初の口コミ', 'paid save trims body');
select public.test_assert(public.get_my_shop_product_review('hexciv-win64')->'review'->>'posted_version' = '1.0', 'server stamps version');
select public.save_shop_product_review('hexciv-win64',3,'編集');
select public.test_assert(public.get_shop_product_reviews('hexciv-win64')->>'count' = '1', 'upsert prevents duplicate reviews');
select public.test_assert((public.get_shop_product_reviews('hexciv-win64')->>'average')::numeric = 3, 'edited rating replaces average');
select public.test_denied($q$update public.shop_product_reviews set is_visible = false$q$, '42501');
select public.test_denied($q$update public.shop_product_reviews set posted_version = '999'$q$, '42501');
select public.test_denied($q$update public.shop_product_reviews set product_id = 'other'$q$, '42501');
select public.test_denied($q$insert into shop_review_private.owners(product_id,user_id) values('other','00000000-0000-4000-8000-000000000002')$q$, '42501');
select public.test_denied($q$insert into public.shop_product_reviews(id,product_id,rating,body) select id,'other',5,'forged product' from shop_review_private.owners where product_id='hexciv-win64'$q$, '23505');

-- A different paid buyer cannot change or delete user 1's visible review.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',false);
select public.test_assert((select count(*) = 0 from shop_review_private.owners), 'ownership RLS hides other user IDs');
with changed as (update public.shop_product_reviews set body = 'attack' returning id)
select public.test_assert((select count(*) = 0 from changed), 'cross-user edit denied');
with removed as (delete from public.shop_product_reviews returning id)
select public.test_assert((select count(*) = 0 from removed), 'cross-user delete denied');
select public.save_shop_product_review('hexciv-win64',5,'Second buyer');
select public.test_assert((public.get_shop_product_reviews('hexciv-win64')->>'average')::numeric = 4, 'average includes two visible buyers');
reset role;

-- Only the server moderation role can hide a review.
update public.shop_product_reviews set is_visible = false
where id in (select id from shop_review_private.owners where user_id = '00000000-0000-4000-8000-000000000001');
set role anon;
select public.test_assert(public.get_shop_product_reviews('hexciv-win64')->>'count' = '1', 'hidden review excluded from count');
select public.test_assert((public.get_shop_product_reviews('hexciv-win64')->>'average')::numeric = 5, 'hidden review excluded from average');
select public.test_assert(not exists(select 1 from information_schema.columns where table_schema='public' and table_name='shop_product_reviews' and column_name='user_id'), 'public review has no account ID');
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',false);
select public.test_assert(public.get_my_shop_product_review('hexciv-win64')->'review'->>'is_visible' = 'false', 'owner sees moderation state');
select public.save_shop_product_review('hexciv-win64',2,'修正');
select public.test_assert(public.get_my_shop_product_review('hexciv-win64')->'review'->>'is_visible' = 'false', 'edit cannot bypass moderation');
reset role;
update public.shop_purchases set status = 'refunded' where user_id='00000000-0000-4000-8000-000000000001' and product_id='hexciv-win64';
set role authenticated;
select public.test_denied($q$select public.save_shop_product_review('hexciv-win64',4,'refunded edit')$q$, '42501');
with removed as (delete from public.shop_product_reviews returning id)
select public.test_assert((select count(*) = 1 from removed), 'refunded owner may delete own review');
reset role;

-- Cursor pages are bounded, deterministic even when creation times tie.
insert into auth.users select ('10000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid from generate_series(1,12) i;
insert into shop_review_private.owners(product_id,user_id)
select 'other',id from auth.users where id::text like '10000000%';
insert into public.shop_product_reviews(id,product_id,rating,body)
select id,product_id,4,'pagination fixture' from shop_review_private.owners where product_id='other';
set role anon;
select public.test_assert(jsonb_array_length(public.get_shop_product_reviews('other')->'items') = 11, 'only 10 plus sentinel fetched');
with first as (select public.get_shop_product_reviews('other')->'items' as items),
next as (select public.get_shop_product_reviews('other', (items->9->>'created_at')::timestamptz, (items->9->>'id')::uuid) as result from first)
select public.test_assert((select jsonb_array_length(result->'items') = 2 from next), 'cursor yields last two without overlap');
reset role;
update public.shop_products set is_active=false where id='other';
set role anon;
select public.test_assert(public.get_shop_product_reviews('other')->>'count' = '0', 'inactive product reviews hidden publicly');
reset role;
select public.test_assert(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='shop_review_private' or p.proname in ('get_my_shop_product_review','save_shop_product_review','get_shop_product_reviews')) and p.prosecdef), 'no definer privilege escalation');
select 'SHOP COMMUNITY SQL PASS' as result;
