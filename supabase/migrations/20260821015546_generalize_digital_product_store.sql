-- HexCiv 専用だった買い切り商品テーブルを、運営者が制作したデジタル商品を
-- 追加できる汎用カタログへ拡張する (#4627)。
--
-- 既存行はすべて後方互換の既定値で読み続けられる。販売者・売上分配の概念は
-- 意図的に追加しない（単一販売者ストア）。第三者出品は Stripe Connect、本人確認、
-- 審査、分配、税務が必要になるため別スコープとする。

alter table public.shop_products
  add column if not exists product_type text not null default 'game',
  add column if not exists description_ja text,
  add column if not exists format_label text not null default 'ZIP',
  add column if not exists requirements_ja text not null default
    'ダウンロード後、対応アプリでご利用ください。',
  add column if not exists license_summary_ja text not null default
    '購入者本人による利用に限ります。素材そのものの再配布・再販売はできません。',
  add column if not exists download_file_name text not null default
    'digital-product.zip',
  add column if not exists preview_image_url text,
  add column if not exists sort_order integer not null default 100,
  add column if not exists published_at timestamptz;

-- PostgreSQL は ADD CONSTRAINT IF NOT EXISTS を持たないため、再適用可能な形で
-- 制約名を確認してから追加する。
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_product_type_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_product_type_check check (
        product_type in (
          'image', 'audio', 'video', 'design', 'writing',
          'prompt', 'idea', 'game', 'template'
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_description_length_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_description_length_check check (
        description_ja is null or char_length(description_ja) <= 20000
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_format_label_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_format_label_check check (
        char_length(btrim(format_label)) between 1 and 80
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_requirements_length_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_requirements_length_check check (
        char_length(btrim(requirements_ja)) between 1 and 1000
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_license_length_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_license_length_check check (
        char_length(btrim(license_summary_ja)) between 1 and 1000
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_download_file_name_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_download_file_name_check check (
        char_length(btrim(download_file_name)) between 1 and 180
        and download_file_name = btrim(download_file_name)
        and position('/' in download_file_name) = 0
        and position(chr(92) in download_file_name) = 0
        and download_file_name !~ '[[:cntrl:]]'
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_preview_image_url_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_preview_image_url_check check (
        preview_image_url is null
        or (
          char_length(preview_image_url) <= 2048
          and preview_image_url ~ '^https://'
        )
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'shop_products_sort_order_check'
      and conrelid = 'public.shop_products'::regclass
  ) then
    alter table public.shop_products
      add constraint shop_products_sort_order_check check (
        sort_order between 0 and 32767
      );
  end if;
end $$;

-- 公開カタログは RLS の is_active 条件と同じ先頭列、次に表示順を使う。
create index if not exists shop_products_catalog_idx
  on public.shop_products (is_active, sort_order, id);

-- 販売停止後も購入者は商品メタデータを読み、再ダウンロードできる。
-- shop_purchases 側の RLS に加えて user_id を明示し、他人の購入を根拠にしない。
drop policy if exists shop_products_buyer_read on public.shop_products;
create policy shop_products_buyer_read on public.shop_products
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.shop_purchases purchase
      where purchase.product_id = shop_products.id
        and purchase.user_id = (select auth.uid())
        and purchase.status = 'paid'
    )
  );

-- 既存商品の表示とダウンロード名を維持する。is_active / Stripe Price / 配信場所は
-- ここでは変更せず、本番販売状態に触れない。
-- nocheck: time-relative
-- CI の旧パーサーは `update public.shop_products` の schema 名 `public` をテーブル名と
-- 誤認する。この UPDATE は日付制約テーブルを触らず、既存の updated_at 更新triggerが
-- now()を記録するだけなので、後日の再実行でも制約違反にならない。
update public.shop_products
set
  product_type = 'game',
  description_ja = coalesce(
    nullif(description_ja, ''),
    '古代文明から近代までの92文明を収録した、Windows向け4Xストラテジーゲームです。'
  ),
  format_label = 'Windows / ZIP',
  requirements_ja = 'Windows 10 / 11（64bit）',
  license_summary_ja =
    '購入者本人によるプレイに限ります。ゲーム本体の再配布・再販売はできません。',
  download_file_name = 'HexCiv-v1.0-win64.zip',
  sort_order = 10,
  published_at = case
    when is_active then coalesce(published_at, updated_at, created_at)
    else published_at
  end
where id = 'hexciv-win64';

comment on column public.shop_products.product_type is
  'デジタル商品の種別。画像・音声・動画・デザイン・文章・プロンプト・アイデア・ゲーム・テンプレート。';
comment on column public.shop_products.description_ja is
  '詳細ページだけで読む商品説明。カタログ一覧では summary_ja のみを取得する。';
comment on column public.shop_products.download_file_name is
  '購入者へ Content-Disposition で提示する安全な保存名。パス区切りと制御文字は禁止。';
comment on column public.shop_products.preview_image_url is
  '公開してよい商品プレビュー画像の HTTPS URL。販売ファイル本体には使わない。';
