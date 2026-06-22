-- Win版#132 part 259 (2026-06-10 / Win Claude): stale-premise タスクの cancelled 化 (triage)
-- 「[Issue #2647] [notebooklm:64fc639e:3] ドキュメント（CLAUDE.md）とSupabase実データベース間の
--  スキーマ自動整合性テスト の導入」
--  (task 2c4d2f03-babf-4688-a27f-101c5a48d19a / owner schedule→win 是正の上 cancelled)
--
-- Triage 判定 (verify 済み / part 254 監査手順の第 3 類型 = stale-premise):
--   本タスク/Issue の前提 = 「CLAUDE.md にテーブル定義 (スキーマ) が記載されている」だが、
--   CLAUDE.md は part 133 (2026-05-05) の Karpathy 80 行化以降 **pointer hub でありスキーマ定義を
--   一切含まない** → 受入基準 (CLAUDE.md 記載のテーブル定義と実 DB の自動比較 CI) は記述のまま
--   実装不能 = premise が現状と乖離。
--   underlying need (スキーマ乖離の早期検知) は現行で次が担う:
--     - supabase/migrations/ = スキーマの SSOT (repo 管理 / レビュー必須)
--     - PR CI の「DB + Edge smoke」+ migration timestamp collision check
--   よって as-written は cancelled が正直なステータス (completed-by-reference ではない =
--   要求された CI ジョブ自体は存在しないため「完了」と主張しない)。
--   将来 doc×schema 同期検証が必要になった場合は、実際にスキーマを記載している doc を対象に
--   再起票する (Issue #2647 close コメントに再起票ガイダンスを記載)。
--
-- 新規成果物なし → development_achievements INSERT なし。progress は変更しない (100 にしない =
-- ai-review trigger の発火条件を踏まない)。Idempotent: 固定値 UPDATE / description append は LIKE guard。

UPDATE public.wbs_tasks
SET
  status            = 'cancelled',
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (L3 / part 259 stale-premise triage)。前提 (CLAUDE.md にスキーマ定義あり) が part 133 の 80 行 pointer hub 化以降 false → 受入基準が記述のまま実装不能のため cancelled。スキーマ乖離検知の実需は migrations SSOT + PR CI (DB+Edge smoke / timestamp collision check) が担う。再起票条件 = 実際にスキーマを記載する doc を対象化したとき。Issue #2647 は根拠コメント付き close。',
  owner_instance    = 'win',
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Cancelled (part 259 triage) — premise stale。再起票条件: スキーマを実記載する doc を対象とした sync 検証が必要になったとき (その際は L2 実装レーン)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Cancelled 2026-06-10: stale premise%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nCancelled 2026-06-10: stale premise (Win Claude part 259 triage). This task assumes CLAUDE.md contains table/schema definitions to diff against the live database, but CLAUDE.md has been an 80-line pointer hub with no schema content since part 133 (2026-05-05), so the acceptance criteria are unimplementable as written. The underlying need (early detection of schema drift) is currently served by supabase/migrations as the schema SSOT plus the PR CI "DB + Edge smoke" job and the migration-timestamp-collision check. Closed as cancelled rather than completed because the requested CI job itself was never built and should not be claimed. If doc-to-schema consistency checking becomes needed again, re-file scoped to a document that actually carries schema definitions (L2 implementation lane). GitHub Issue #2647 closed with the same rationale.'
  END,
  updated_at        = now()
WHERE id = '2c4d2f03-babf-4688-a27f-101c5a48d19a';
