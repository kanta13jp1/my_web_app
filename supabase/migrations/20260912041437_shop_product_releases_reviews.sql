-- Product release history + purchaser reviews. No billing/storage mutation.
-- Keep account linkage out of the exposed API schema. All RPCs are invoker
-- functions: grants and RLS remain the authority, even for direct REST writes.
create schema if not exists shop_review_private;
revoke all on schema shop_review_private from public, anon;
grant usage on schema shop_review_private to authenticated, service_role;

create table public.shop_product_releases (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references public.shop_products(id) on delete cascade,
  release_key text not null check (char_length(release_key) between 1 and 80),
  version text not null check (char_length(btrim(version)) between 1 and 80),
  title_ja text not null check (char_length(btrim(title_ja)) between 1 and 160),
  notes_ja text not null check (char_length(btrim(notes_ja)) between 1 and 10000),
  sha256 text check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  published_at timestamptz,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  unique (product_id, release_key)
);
create index shop_product_releases_history_idx
  on public.shop_product_releases (product_id, created_at desc, id desc);
alter table public.shop_product_releases enable row level security;
revoke all on public.shop_product_releases from public, anon, authenticated;
grant select on public.shop_product_releases to anon, authenticated;
grant all on public.shop_product_releases to service_role;
create policy shop_product_releases_read on public.shop_product_releases
  for select to anon, authenticated using (
    is_published and (published_at is null or published_at <= now())
    and exists (select 1 from public.shop_products p where p.id = product_id)
  );

create table shop_review_private.owners (
  id uuid primary key default gen_random_uuid(),
  product_id text not null references public.shop_products(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  unique (user_id, product_id),
  unique (id, product_id)
);
create index shop_review_owners_product_idx on shop_review_private.owners(product_id);
alter table shop_review_private.owners enable row level security;
revoke all on shop_review_private.owners from public, anon, authenticated;
grant select on shop_review_private.owners to authenticated;
grant insert (product_id) on shop_review_private.owners to authenticated;
grant all on shop_review_private.owners to service_role;
create policy shop_review_owner_read on shop_review_private.owners
  for select to authenticated using (user_id = (select auth.uid()));
create policy shop_review_owner_insert on shop_review_private.owners
  for insert to authenticated with check (
    user_id = (select auth.uid()) and exists (
      select 1 from public.shop_purchases p
      where p.product_id = owners.product_id
        and p.user_id = (select auth.uid()) and p.status = 'paid'
    )
  );

create table public.shop_product_reviews (
  id uuid primary key,
  product_id text not null references public.shop_products(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  body text not null default '' check (char_length(body) <= 2000),
  posted_version text not null default '',
  is_visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (id, product_id) references shop_review_private.owners(id, product_id)
    on delete cascade
);
create index shop_product_reviews_page_idx
  on public.shop_product_reviews (product_id, created_at desc, id desc)
  where is_visible;
-- Also cover the non-partial FK lookup for moderation/deletion.
create index shop_product_reviews_product_idx on public.shop_product_reviews(product_id);
alter table public.shop_product_reviews enable row level security;
revoke all on public.shop_product_reviews from public, anon, authenticated;
grant select on public.shop_product_reviews to anon, authenticated;
grant insert (id, product_id, rating, body) on public.shop_product_reviews to authenticated;
grant update (rating, body) on public.shop_product_reviews to authenticated;
grant delete on public.shop_product_reviews to authenticated;
grant all on public.shop_product_reviews to service_role;

create policy shop_product_reviews_public_read on public.shop_product_reviews
  for select to anon, authenticated using (
    is_visible and exists (
      select 1 from public.shop_products p where p.id = product_id and p.is_active
    )
  );
create policy shop_product_reviews_own_read on public.shop_product_reviews
  for select to authenticated using (
    id in (select o.id from shop_review_private.owners o where o.user_id = (select auth.uid()))
  );
create policy shop_product_reviews_insert on public.shop_product_reviews
  for insert to authenticated with check (
    id in (select o.id from shop_review_private.owners o where o.user_id = (select auth.uid()))
    and exists (select 1 from public.shop_purchases p
      where p.product_id = shop_product_reviews.product_id
        and p.user_id = (select auth.uid()) and p.status = 'paid')
  );
create policy shop_product_reviews_update on public.shop_product_reviews
  for update to authenticated using (
    id in (select o.id from shop_review_private.owners o where o.user_id = (select auth.uid()))
    and exists (select 1 from public.shop_purchases p
      where p.product_id = shop_product_reviews.product_id
        and p.user_id = (select auth.uid()) and p.status = 'paid')
  ) with check (
    id in (select o.id from shop_review_private.owners o where o.user_id = (select auth.uid()))
    and exists (select 1 from public.shop_purchases p
      where p.product_id = shop_product_reviews.product_id
        and p.user_id = (select auth.uid()) and p.status = 'paid')
  );
-- Refunded purchasers can still remove their own public content.
create policy shop_product_reviews_delete on public.shop_product_reviews
  for delete to authenticated using (
    id in (select o.id from shop_review_private.owners o where o.user_id = (select auth.uid()))
  );

create function shop_review_private.stamp_review()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  new.body := btrim(new.body);
  new.updated_at := now();
  select coalesce(p.version, '') into new.posted_version
    from public.shop_products p where p.id = new.product_id;
  return new;
end;
$$;
revoke all on function shop_review_private.stamp_review() from public, anon, authenticated;
create trigger shop_product_review_stamp before insert or update on public.shop_product_reviews
  for each row execute function shop_review_private.stamp_review();

create function public.get_my_shop_product_review(p_product_id text)
returns jsonb language plpgsql stable security invoker set search_path = '' as $$
declare own_review jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  select to_jsonb(r) into own_review
    from public.shop_product_reviews r join shop_review_private.owners o on o.id = r.id
    where o.product_id = p_product_id and o.user_id = (select auth.uid());
  return jsonb_build_object('review', own_review, 'can_review', exists (
    select 1 from public.shop_purchases p where p.product_id = p_product_id
      and p.user_id = (select auth.uid()) and p.status = 'paid'
  ));
end;
$$;
revoke all on function public.get_my_shop_product_review(text) from public, anon, authenticated;
grant execute on function public.get_my_shop_product_review(text) to authenticated;

create function public.save_shop_product_review(p_product_id text, p_rating integer, p_body text)
returns void language plpgsql security invoker set search_path = '' as $$
declare review_id uuid;
begin
  if auth.uid() is null or not exists (
    select 1 from public.shop_purchases p where p.product_id = p_product_id
      and p.user_id = (select auth.uid()) and p.status = 'paid'
  ) then raise exception 'Paid purchase required' using errcode = '42501'; end if;
  if p_rating is null or p_rating not between 1 and 5
     or p_body is null or char_length(p_body) > 2000 then
    raise exception 'Invalid review' using errcode = '22023';
  end if;
  insert into shop_review_private.owners(product_id) values (p_product_id)
    on conflict (user_id, product_id) do nothing;
  select o.id into review_id from shop_review_private.owners o
    where o.product_id = p_product_id and o.user_id = (select auth.uid());
  insert into public.shop_product_reviews(id, product_id, rating, body)
    values (review_id, p_product_id, p_rating, p_body)
    on conflict (id) do update set rating = excluded.rating, body = excluded.body;
end;
$$;
revoke all on function public.save_shop_product_review(text, integer, text) from public, anon, authenticated;
grant execute on function public.save_shop_product_review(text, integer, text) to authenticated;

create function public.get_shop_product_reviews(
  p_product_id text, p_before_created_at timestamptz default null, p_before_id uuid default null
)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'count', (select count(*) from public.shop_product_reviews r
      where r.product_id = p_product_id and r.is_visible
        and exists(select 1 from public.shop_products p where p.id = p_product_id and p.is_active)),
    'average', (select avg(r.rating) from public.shop_product_reviews r
      where r.product_id = p_product_id and r.is_visible
        and exists(select 1 from public.shop_products p where p.id = p_product_id and p.is_active)),
    'items', coalesce((select jsonb_agg(to_jsonb(page) order by page.created_at desc, page.id desc)
      from (select r.* from public.shop_product_reviews r
        where r.product_id = p_product_id and r.is_visible
          and exists(select 1 from public.shop_products p where p.id = p_product_id and p.is_active)
          and (p_before_created_at is null or (r.created_at, r.id) < (p_before_created_at, p_before_id))
        order by r.created_at desc, r.id desc limit 11) page), '[]'::jsonb)
  );
$$;
revoke all on function public.get_shop_product_reviews(text, timestamptz, uuid) from public, anon, authenticated;
grant execute on function public.get_shop_product_reviews(text, timestamptz, uuid) to anon, authenticated;

-- Verified package description, not an invented release date or change log.
-- Seed only when the deployed product has exactly the independently checked hash.
insert into public.shop_product_releases
  (product_id, release_key, version, title_ja, notes_ja, sha256, is_published)
select p.id, 'stage4m-20260814', p.version, 'Stage 4M — 配布内容',
  '通常4Xとウルク編を収録。ウルク編では、情報を受け取る共同体ごとの処理力と理解率を推定ゲーム値として扱い、交渉結果を確認できます。公開日の確定記録がないため日付は未記録です。',
  p.sha256, true from public.shop_products p
where p.id = 'hexciv-win64'
  and p.sha256 = '66bf4bf96459b3d8cf2c35785e91c5cc0d75f2fb89a8993f3b379727cafc6490';

comment on table public.shop_product_reviews is
  'Public purchaser reviews without account IDs. Ownership is in a non-exposed RLS-protected schema.';
comment on column public.shop_product_reviews.posted_version is
  'Catalog distribution version at submission/edit time, not a verified played version.';
comment on column public.shop_product_releases.published_at is
  'Verified public release timestamp. NULL means unknown, not the migration execution date.';
