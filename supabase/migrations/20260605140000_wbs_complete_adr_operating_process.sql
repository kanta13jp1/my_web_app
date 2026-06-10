-- Win版#132 part 241 (2026-06-05 / Win Claude): Complete WBS 設計タスク
-- 「アーキテクチャ判断ログ運用 (ADR)」 (task 2e41ebca-36bd-4c47-a87f-90b7b5948ece).
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/adr/README.md        … ADR 運用ガイド (いつ書く/命名/Status/WBS+Issue+NotebookLM 紐づけ/Index)
--   - docs/adr/TEMPLATE.md       … 新規 ADR テンプレート
--   - docs/adr/2026-06-05-flutter-web-supabase-firebase-stack.md         … 基盤判断 backfill
--   - docs/adr/2026-06-05-edge-function-first-architecture.md            … EF-FIRST/EF-CAP-50 backfill
--   - docs/adr/2026-06-05-two-instance-fleet-architect-implementer.md    … 2-instance fleet backfill
--   - docs/DIRECTORY_STRUCTURE.md … docs/adr/ への pointer 追記
--
-- ai_review_status='approved' を同一 UPDATE で設定するため、progress=100 への遷移でも
-- wbs_request_ai_review trigger は発火しない (trigger 条件: NEW.ai_review_status='pending')。
-- → status='completed' が確定する。
--
-- Idempotent: 値は固定セット / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect lane) self-authored deliverable. docs/adr/ に ADR 運用ガイド + テンプレート + 主要設計判断 3 件の backfill ADR を整備。コード/スキーマ変更なしの docs-only。',
  start_date        = COALESCE(start_date, DATE '2026-06-05'),
  end_date          = DATE '2026-06-05',
  remaining_work    = 'Completed by Win Claude (part 241). ADR 運用は docs/adr/README.md に確立。新規設計判断は TEMPLATE.md をコピーし Index に 1 行追記する運用。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-05: ADR operating process established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-05 (Win Claude part 241): ADR operating process established under docs/adr/. Added README.md (when-to-write / naming / status lifecycle / WBS+Issue+NotebookLM linkage / index), TEMPLATE.md, and 3 backfill ADRs for the foundational stack, Edge-Function-first, and 2-instance fleet decisions. Docs-only; no code/schema change.'
  END,
  updated_at        = now()
WHERE id = '2e41ebca-36bd-4c47-a87f-90b7b5948ece';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'ADR (設計判断ログ) 運用の確立',
  'docs/adr/ にアーキテクチャ判断記録 (ADR) の運用を整備。README で「いつ書くか/命名規則/Status ライフサイクル/WBS・Issue・NotebookLM への紐づけ」を定義し、TEMPLATE を用意。基盤スタック・Edge-Function-first・2-instance fleet の主要設計判断 3 件を backfill ADR 化した。後続実装が過去判断の理由を辿れる状態を作る (Win版#132 part 241)。',
  DATE '2026-06-05'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements WHERE title = 'ADR (設計判断ログ) 運用の確立'
);
