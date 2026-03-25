-- ============================================================
-- Seed: 2026-03-25 session4
-- ============================================================

insert into public.development_achievements (title, completed_at) values
  ('競合名「Claude works」→「Claude Cowork」に全ファイル変更 (Dart/TypeScript/Markdown 23箇所一括置換・growth_plans DB も UPDATE マイグレーションで同期)', '2026-03-25 18:00:00+00'),
  ('FinancialReportPage を SharedPreferences → Supabase cfo_assets テーブルへ完全移行 (クロスデバイス同期・dart:convert 不要 import 削除)', '2026-03-25 18:30:00+00'),
  ('AssetManagementPage の個人銀行名ハードコード (三井住友銀行大塚支店等) を撤廃: 汎用デフォルト選択肢 + _loadSourceOptionsFromDb() で past payment_source を自動補完', '2026-03-25 19:00:00+00')
on conflict do nothing;
