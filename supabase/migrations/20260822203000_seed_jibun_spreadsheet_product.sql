-- Jibun Spreadsheet Windows版を、公開前の買い切り商品候補として登録する。
-- Stripe Price、Storage upload、is_active=true は別の明示承認を必要とする。

alter table public.shop_products
  drop constraint if exists shop_products_product_type_check;

alter table public.shop_products
  add constraint shop_products_product_type_check check (
    product_type in (
      'image', 'audio', 'video', 'design', 'writing',
      'prompt', 'idea', 'game', 'application', 'template'
    )
  );

alter table public.artifact_candidates
  drop constraint if exists artifact_candidates_artifact_kind_check;

alter table public.artifact_candidates
  add constraint artifact_candidates_artifact_kind_check check (
    artifact_kind in (
      'image', 'audio', 'video', 'design', 'writing',
      'prompt', 'idea', 'game', 'application', 'template', 'bundle'
    )
  );

insert into public.shop_products (
  id,
  name_ja,
  summary_ja,
  description_ja,
  price_jpy,
  storage_bucket,
  storage_path,
  version,
  file_size_bytes,
  sha256,
  product_type,
  format_label,
  requirements_ja,
  license_summary_ja,
  download_file_name,
  preview_image_url,
  sort_order,
  is_active
)
values (
  'jibun-spreadsheet-win64',
  'Jibun Spreadsheet (Windows版)',
  'セル計算、複数シート、CSV入出力、自動保存に対応したローカル表計算アプリ。',
  'Windows 10 / 11向けの買い切り表計算アプリです。四則演算、SUM・AVERAGE・MIN・MAX、セル参照と範囲参照、複数シート、CSV入出力、自動保存、元に戻す・やり直しを利用できます。Microsoft Excelの全機能やXLSX形式との完全互換を保証する製品ではありません。',
  980,
  'product-downloads',
  'jibun-spreadsheet-win64/v1.0.0/JibunSpreadsheet-v1.0.0-win64.zip',
  '1.0.0',
  30725914,
  '5ed8e0f8fb414d999c09f6d978012672f0e4c3f0e5e2dd89b6f2626e4e613d0f',
  'application',
  'Windowsアプリ / ZIP',
  'Windows 10 / 11（64bit）。1280 × 720以上を推奨。インターネット接続は不要です。',
  '購入者本人が管理するWindows端末で利用できます。アプリ本体・DLL・同梱物の再配布、共有、再販売は禁止します。作成した表やCSVは個人・商用に利用できます。',
  'JibunSpreadsheet-v1.0.0-win64.zip',
  null,
  20,
  false
)
on conflict (id) do update
set
  name_ja = excluded.name_ja,
  summary_ja = excluded.summary_ja,
  description_ja = excluded.description_ja,
  price_jpy = excluded.price_jpy,
  storage_bucket = excluded.storage_bucket,
  storage_path = excluded.storage_path,
  version = excluded.version,
  file_size_bytes = excluded.file_size_bytes,
  sha256 = excluded.sha256,
  product_type = excluded.product_type,
  format_label = excluded.format_label,
  requirements_ja = excluded.requirements_ja,
  license_summary_ja = excluded.license_summary_ja,
  download_file_name = excluded.download_file_name,
  preview_image_url = excluded.preview_image_url,
  sort_order = excluded.sort_order;

-- on conflictでstripe_price_id、is_active、published_atを上書きしない。
-- 再適用時にも決済設定や既存販売状態を破壊しないため。

