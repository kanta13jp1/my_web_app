-- Win版#132 part 243 (2026-06-06 / Win Claude): Complete WBS 企画タスク
-- 「[企画] 四半期ロードマップ策定」 (task be0354f6-10fb-4b77-a77a-52515e5b4fd7).
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/QUARTERLY_ROADMAP.md … v1 四半期ロードマップ baseline。
--       競合監視・ユーザー要望・WBS 進捗を反映し、次四半期 (Q3 2026 = MVP ローンチ) の
--       優先順位を SDLC 7 工程別に再配置。WBS フェーズバランスレビュー (実測 3,143 tasks /
--       未完了 932 / phase 未設定 879 = 94.3%) + リスクノートを内包。
--   - docs/DIRECTORY_STRUCTURE.md … docs/QUARTERLY_ROADMAP.md への pointer 追記
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
  ai_review_notes   = 'Win Claude (architect lane) self-authored deliverable. docs/QUARTERLY_ROADMAP.md に v1 四半期ロードマップを整備 (Q3 2026 を SDLC 7 工程別に再配置 / WBS フェーズバランスレビュー 実測 / リスクノート)。L1 Antigravity 探索で継続精緻化する living doc。コード/スキーマ変更なしの docs-only。',
  start_date        = COALESCE(start_date, DATE '2026-06-06'),
  end_date          = DATE '2026-06-06',
  remaining_work    = 'Completed by Win Claude (part 243). 四半期ロードマップは docs/QUARTERLY_ROADMAP.md。四半期ごと改訂・月次でフェーズバランスと進捗を見直す living doc 運用。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-06: Quarterly roadmap v1 established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-06 (Win Claude part 243): Quarterly roadmap v1 established at docs/QUARTERLY_ROADMAP.md. Re-prioritized next quarter (Q3 2026 = MVP launch) across the SDLC 7-phase taxonomy, reflecting competitor monitoring, user requests, and WBS progress. Includes a data-measured WBS phase-balance review (3,143 tasks total, 932 non-completed, 879 = 94.3% phase-untagged) and risk notes (cut low-confidence feature lanes before delivery tasks). Living doc to be refined with L1 Antigravity exploration. Docs-only; no code/schema change.'
  END,
  updated_at        = now()
WHERE id = 'be0354f6-10fb-4b77-a77a-52515e5b4fd7';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO development_achievements (title, description, completed_at)
SELECT
  '四半期ロードマップ v1 の策定',
  'docs/QUARTERLY_ROADMAP.md に四半期ロードマップ v1 を整備。競合監視・ユーザー要望・WBS 進捗を反映し、次四半期 (Q3 2026 = MVP ローンチ / 1,000 users) の優先順位を SDLC 7 工程 (企画/設計/実装/テスト/リリース/運用/保守) 別に再配置。WBS フェーズバランスレビュー (総 3,143 / 未完了 932 / phase 未設定 94.3% という所見) とリスクノートを内包し、PRD と WBS 実行の間を埋める四半期意思決定層とする (Win版#132 part 243)。',
  DATE '2026-06-06'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements WHERE title = '四半期ロードマップ v1 の策定'
);
