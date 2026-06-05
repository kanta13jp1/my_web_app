-- Win版#132 part 242 (2026-06-05 / Win Claude): Complete WBS 企画タスク
-- 「プロダクト要件定義書 (PRD) 整備」 (task 5ef83c7e-1808-4dc2-9e9d-f19c799e8240).
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/PRD.md … v1 PRD baseline (ビジョン / ペルソナ / 6 部署提供価値 / スコープ /
--                    非目標 / KPI 2 層 / 原則整合 / living-doc 運用)。
--                    既存 canon (PHILOSOPHY / 本番機能 / 競合 / WBS マイルストーン) から codify。
--   - docs/DIRECTORY_STRUCTURE.md … docs/PRD.md への pointer 追記
--
-- ai_review_status='approved' を同一 UPDATE で設定するため、progress=100 への遷移でも
-- wbs_request_ai_review trigger は発火しない → status='completed' が確定する。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect lane) self-authored deliverable. docs/PRD.md に v1 PRD baseline を整備 (persona/scope/非目標/KPI)。L1 Antigravity 探索結果で継続精緻化する living doc。コード/スキーマ変更なしの docs-only。',
  start_date        = COALESCE(start_date, DATE '2026-06-05'),
  end_date          = DATE '2026-06-05',
  remaining_work    = 'Completed by Win Claude (part 242). PRD baseline は docs/PRD.md。週次レビューで更新、スコープ拡大は feature Issue 分割、設計判断は docs/adr/ に ADR 化する運用。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-05: PRD v1 baseline established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-05 (Win Claude part 242): PRD v1 baseline established at docs/PRD.md. Codified vision, target personas, 6-department value model, in-scope/non-goals, two-tier KPI (wellbeing North-Star + business milestones), and philosophy alignment from existing canon (PHILOSOPHY.md, production features, competitors, WBS milestones). Living doc to be refined with L1 Antigravity exploration. Docs-only; no code/schema change.'
  END,
  updated_at        = now()
WHERE id = '5ef83c7e-1808-4dc2-9e9d-f19c799e8240';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'プロダクト要件定義書 (PRD) v1 の整備',
  'docs/PRD.md に自分株式会社の PRD v1 baseline を整備。ビジョン (人生を会社として経営)、ターゲットペルソナ、6 部署の提供価値、スコープと非目標、ウェルビーイングを North-Star とし事業マイルストーンをガードレールとする 2 層 KPI、9 原則整合を 1 枚に固定。後続の機能 Issue・設計 (ADR)・WBS が参照する上位基準とする (Win版#132 part 242)。',
  DATE '2026-06-05'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements WHERE title = 'プロダクト要件定義書 (PRD) v1 の整備'
);
