-- Win Claude (L3): Partial progress for GitHub Issue #1239
-- 「CSVファイルを用いたデータ一括登録機能」 (task d87a697c-ba10-404a-bbf8-29fd5fcdd380).
--
-- 本 migration は **完了ではなく進捗更新** (honest scope)。GitHub Issue #1239 は open のまま。
--
-- 着地した成果物 (deterministic core / 実コード + テスト):
--   - lib/services/csv_bulk_upsert_planner.dart … Flutter/Supabase 非依存の純ロジック。
--     CSV parse (quoted field / CRLF / BOM) → header を schema 検証 → 各セルを型強制
--     (text/integer/number/boolean/date) → key 一致で INSERT/UPDATE を判定 (AC#2) →
--     行番号付きの per-row エラー収集 + 成功/エラー/新規/更新 件数 (AC#3, AC#4)。
--   - test/services/csv_bulk_upsert_planner_test.dart … 9 ケース (insert/update 分割 /
--     型エラー行番号+列 / 必須値空 / key 空・重複 / 必須列欠落で file reject /
--     未知列 warn / quoted+改行+BOM / summaryLabel / schema 不正 throw)。
--
-- 検証: dart 未導入のため実 Dart test はローカル実行不可 → ロジックを faithful に JS へ
--   ミラーして Node で 9 グループ全通過を確認 (logic check)。正本の `flutter test` は ci.yml が gate。
--
-- 残作業 (Codex 実装レーン + 実機 QA / 本 migration では完了を主張しない):
--   1. import ページに file picker (AC#1) を接続し、planCsvBulkUpsert の plan を表示。
--   2. 既存 key を Supabase から取得 (existingKeys) → plan.rows を chunk 化して upsert 実行。
--   3. plan.summaryLabel と plan.errors を UI に表示 (成功/エラー件数 + 対象行)。
--   4. 実機 (Flutter Web) で file 選択→upsert→件数表示→エラー行確認の E2E QA。
--
-- open GitHub issue guard に抵触しないよう progress<100 / status=in_progress を維持。

UPDATE public.wbs_tasks
SET
  status         = 'in_progress',
  progress       = GREATEST(COALESCE(progress, 0), 60),
  owner_instance = COALESCE(NULLIF(owner_instance, ''), 'win'),
  remaining_work = 'CSV 一括登録の deterministic core = lib/services/csv_bulk_upsert_planner.dart (+ _test.dart 9 ケース) 着地。残: (1) import ページに file picker 接続 (AC#1) / (2) 既存 key 取得 + plan.rows を chunk upsert 実行 / (3) plan.summaryLabel + plan.errors を UI 表示 (成功/エラー件数 + 対象行, AC#3/#4) / (4) 実機 Flutter Web で E2E QA。実装は Codex レーン、正本 test は ci.yml の flutter test。',
  description    = CASE
    WHEN COALESCE(description, '') LIKE '%Progress 2026-07-16: csv_bulk_upsert_planner core landed%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nProgress 2026-07-16 (Win Claude): csv_bulk_upsert_planner core landed. Added lib/services/csv_bulk_upsert_planner.dart, a Flutter/Supabase-free pure core for CSV bulk register/update: it parses CSV (quoted fields, CRLF, BOM), validates the header against a column schema, coerces each cell by declared type (text/integer/number/boolean/date), decides INSERT vs UPDATE per row by matching the key column against existing keys (AC#2), and returns per-row errors with 1-based row numbers plus success/error/insert/update counts (AC#3, AC#4). Added test/services/csv_bulk_upsert_planner_test.dart (9 cases). Dart is not installed here, so the real flutter test runs in CI; the logic was faithfully mirrored to JS and verified under Node (9 groups pass). Not complete: the file-picker UI (AC#1), the Supabase chunked upsert write, and real Flutter Web E2E QA remain (Codex lane). This migration reports progress only and does not claim completion; Issue #1239 stays open.'
  END,
  updated_at     = now()
WHERE id = 'd87a697c-ba10-404a-bbf8-29fd5fcdd380';
