-- #2594: アジア太平洋地域向け多言語・多通貨メタデータスキーマ基盤構築
-- public.notes への地域・言語・基準通貨・為替要検証フラグ列の冪等追加と、
-- 所有者 RLS 保護付き public.regional_knowledge_documents テーブルの新設。

alter table if exists public.notes
  add column if not exists target_region text default 'JP',
  add column if not exists content_locale text default 'ja-JP',
  add column if not exists base_currency_code text default 'JPY',
  add column if not exists fx_requires_verification boolean not null default false;

do $$
begin
  if to_regclass('public.notes') is not null then
    create index if not exists idx_notes_regional_locale_currency
      on public.notes (user_id, target_region, content_locale, base_currency_code);
  end if;
end
$$;

create table if not exists public.regional_knowledge_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  target_region text not null check (target_region in ('JP','SG','AU','ID','VN','TH','APAC')),
  content_locale text not null check (content_locale in ('ja-JP','en-SG','en-AU','id-ID','vi-VN','th-TH')),
  base_currency_code text not null check (base_currency_code in ('JPY','SGD','AUD','USD','IDR','VND','THB')),
  amount_minor_or_decimal numeric(18,4),
  fx_requires_verification boolean not null default true,
  verification_note text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists idx_regional_knowledge_documents_user_created
  on public.regional_knowledge_documents (user_id, created_at desc);

create index if not exists idx_regional_knowledge_documents_region_currency
  on public.regional_knowledge_documents (target_region, content_locale, base_currency_code);

alter table public.regional_knowledge_documents enable row level security;

revoke all on table public.regional_knowledge_documents from anon;
revoke all on table public.regional_knowledge_documents from authenticated;
grant select, insert, update, delete
  on table public.regional_knowledge_documents to authenticated;
grant all on table public.regional_knowledge_documents to service_role;

drop policy if exists "Users can view own regional knowledge documents"
  on public.regional_knowledge_documents;
create policy "Users can view own regional knowledge documents"
  on public.regional_knowledge_documents
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own regional knowledge documents"
  on public.regional_knowledge_documents;
create policy "Users can insert own regional knowledge documents"
  on public.regional_knowledge_documents
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own regional knowledge documents"
  on public.regional_knowledge_documents;
create policy "Users can update own regional knowledge documents"
  on public.regional_knowledge_documents
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own regional knowledge documents"
  on public.regional_knowledge_documents;
create policy "Users can delete own regional knowledge documents"
  on public.regional_knowledge_documents
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);

comment on table public.regional_knowledge_documents is
  'APAC地域の多言語・多通貨ナレッジ及び財務評価メタデータ（為替要検証フラグ付き / #2594）。';
comment on column public.regional_knowledge_documents.fx_requires_verification is
  '外部機関・為替レート依存のため UI 上で要検証警告の表示が必要かどうかを示すフラグ。';
