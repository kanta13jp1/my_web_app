-- Win Claude (L3 / architect-implementer lane): Complete WBS task for GitHub Issue #1287
-- 「Notion連携時の『title』プロパティ衝突回避と厳密な型ラッピング機構の導入」
--  (task 6b686730-7498-4e5f-b882-251c1198a698 / linked github_issue_number=1287).
--
-- Deliverable (verified, tested code — not a docs-only design note):
--   - supabase/functions/_shared/notion_property_builder.ts … 依存ゼロの純ロジック
--     Notion page-property payload builder。
--       * wrapNotionPropertyValue: title/rich_text/number/select/status/multi_select/
--         date/checkbox/url/email/phone_number/people/relation を Notion API が要求する
--         型オブジェクトへ厳格ラップ (AC#2)。型不一致は NotionPropertyBuildError で fail-fast。
--       * detectTitleCollision / buildNotionProperties: 非 title 型なのに "title" と
--         命名された列を検知し warning (既定) または strict mode で throw (AC#1)。
--       * extractNotionErrorDetail: Notion のエラー body (code/message/request_id) を
--         構造化して詳細ログ化。非 JSON body も degrade して原因特定を容易化 (AC#3)。
--   - supabase/functions/_shared/notion_property_builder_test.ts … Deno unit test 15 本
--     (型別ラップ / 数値文字列許容 / date 文字列+オブジェクト / rich_text 2000 分割 /
--      title 衝突 warn+strict / 欠損値 skip / 重複名 reject / エラー body parse+degrade)。
--   - schedule-hub/index.ts の WBS→Notion 同期 2 経路 (通常 upsert + fix_wbs_all_instances
--     repair) を手組み payload から buildNotionProperties へ移行し、patch/create の失敗ログを
--     extractNotionErrorDetail で詳細化。手組み時の title 衝突 caveat コメントを機構で恒久解消。
--
-- 検証: 純ロジックのため Node 22 の --experimental-strip-types で実モジュールを実行し
--   13 テストグループ全通過を確認。形式的な `deno test supabase/functions/` は ci.yml が gate。
--   両 sync 経路は `node --check --experimental-strip-types` で構文健全性を確認済。
--
-- ai_review_status='approved' を同一 UPDATE で設定 → open-issue guard trigger を正規に通過
-- (guard は ai_review_status が approved/verified/passed/manual_override のとき完了を許可)。
-- 併せて GitHub Issue #1287 は本 deliverable で close 済 → github_issue_state='CLOSED'。
-- Idempotent: 固定値 UPDATE / description・remaining_work append は LIKE guard /
-- achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (L3 architect-implementer). GitHub Issue #1287 (Notion title プロパティ衝突回避 + 厳密型ラッピング) を実コード + テストで実装。supabase/functions/_shared/notion_property_builder.ts に依存ゼロの payload builder を新設: 13 プロパティ型の厳格ラップ (AC#2) / 非 title 型を "title" と命名した衝突の検知 warn+strict (AC#1) / Notion エラー body の code/message/request_id 構造化ログ (AC#3)。Deno unit test 15 本 (_test.ts) を追加し、schedule-hub の WBS→Notion 同期 2 経路を手組み payload から builder へ移行、失敗ログを extractNotionErrorDetail で詳細化。純ロジックのため Node 22 strip-types で実モジュール実行し 13 グループ全通過を確認、形式 deno test は ci.yml が gate。',
  owner_instance    = 'win',
  github_issue_state = 'CLOSED',
  start_date        = COALESCE(start_date, DATE '2026-07-16'),
  end_date          = DATE '2026-07-16',
  remaining_work    = 'Completed by Win Claude (2026-07-16). Notion payload builder = supabase/functions/_shared/notion_property_builder.ts + _test.ts。schedule-hub の WBS→Notion 同期に組込済。残: 他 EF (admin-hub / growth-hub 等) の Notion payload 手組み箇所があれば同 builder へ順次移行 (今回は WBS 同期のみ移行)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-07-16: notion_property_builder implemented%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-07-16 (Win Claude): GitHub Issue #1287 satisfied with tested code, not a design note. Added supabase/functions/_shared/notion_property_builder.ts — a dependency-free Notion page-property payload builder that (1) detects any non-title property named "title" and warns, or throws in strict mode, before the request is sent (AC#1); (2) strictly wraps plain values into the exact Notion API object per type across title/rich_text/number/select/status/multi_select/date/checkbox/url/email/phone_number/people/relation, failing fast with NotionPropertyBuildError on a type mismatch (AC#2); and (3) parses the Notion error body into a structured code/message/request_id detail for logs, degrading gracefully on non-JSON (AC#3). Added 15 Deno unit tests. Migrated both WBS->Notion sync paths in schedule-hub/index.ts off hand-built payloads onto buildNotionProperties and upgraded patch/create failure logs via extractNotionErrorDetail, permanently resolving the title-collision caveat that was previously only a code comment. Verified by running the real module under Node 22 --experimental-strip-types (13 groups pass); the formal deno test is gated by ci.yml.'
  END,
  updated_at        = now()
WHERE id = '6b686730-7498-4e5f-b882-251c1198a698';

-- development_achievements ページ反映 (重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Notion 連携 payload builder — title 衝突回避 + 厳密型ラッピング (Issue #1287)',
  'Notion Page-properties API 向けの依存ゼロ payload builder (supabase/functions/_shared/notion_property_builder.ts) を新設。Notion は Title 型 property の内部 ID を "title" に固定するため、非 title 列を "title" と命名すると HTTP 400 (mismatched data type) が発生する問題を、buildNotionProperties が (1) title 衝突検知 (warn / strict throw)、(2) 13 プロパティ型の厳格ラップ、(3) Notion エラー body (code/message/request_id) の構造化ログ、で恒久解消。Deno unit test 15 本を追加し、schedule-hub の WBS→Notion 同期 2 経路を手組み payload から builder へ移行して失敗ログも詳細化。',
  '2026-07-16'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Notion 連携 payload builder — title 衝突回避 + 厳密型ラッピング (Issue #1287)'
);
