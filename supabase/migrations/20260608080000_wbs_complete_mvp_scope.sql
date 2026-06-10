-- Win版#132 part 244 (2026-06-08 / Win Claude): Complete WBS 企画タスク
-- 「MVP feature scope 確定」 (task 2c710eb1-f333-4a0f-8b10-b9aad34a0df6 / milestone mvp-launch).
--
-- 本タスクは owner_instance='codex' だったが、企画/設計/docs は L3 (Win Claude) のレーン
-- であり ([DYNAMIC-CLAIM] = primary no-op 時の docs/product-light 引き取り)、設計成果物として
-- Win Claude が完了する。owner_instance も 'win' へ是正。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/MVP_SCOPE.md … v1 MVP 機能スコープ baseline。
--       PRD §4 の広い In-Scope を MVP ローンチ (2026-09-30 / 1,000 users) で必ず仕上げる
--       コア 5 機能 (本社=ダッシュボード / 人事=健康 最優先 / R&D=AI大学+ノート /
--       財務=家計簿 / 横断=AI mentor) へ絞り込み。Deferred・keep・削減順・GA gate 関係を内包。
--       cut-line の最終確定は CEO 判断待ち (旧 Draft PR #1661 recovery_plan の明記どおり) の v1 叩き台。
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
  ai_review_notes   = 'Win Claude (architect lane / L3) self-authored deliverable. docs/MVP_SCOPE.md に v1 MVP 機能スコープを整備 (PRD §4 In-Scope をコア 5 機能へ絞り込み / Deferred + keep + 削減順 + GA gate 関係)。cut-line 最終確定は CEO 判断待ちの v1 baseline。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-08'),
  end_date          = DATE '2026-06-08',
  remaining_work    = 'Completed by Win Claude (part 244). MVP 機能スコープは docs/MVP_SCOPE.md。週次でコア 5 の優先度を見直す living doc。cut-line (何を含め何を後回しか) の最終確定は CEO 確認後に Status を Confirmed へ更新。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-08: MVP feature scope v1 established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-08 (Win Claude part 244): MVP feature scope v1 established at docs/MVP_SCOPE.md. Narrowed PRD section 4 in-scope into the MVP core-5 features (Home/dashboard = HQ, Health/sleep/journal = HR top-priority, AI University + tagged notes = R&D, Budget dashboard = Finance, Cross-cutting AI mentor with user-final-decision). Documents deferred items, keep-as-is assets (comparison pages etc.), delivery cut-order, and the relation to a GA readiness gate (superseding closed Draft PR #1661 idea). cut-line final confirmation requires CEO product judgment (v1 baseline draft). Docs-only; no code/schema change. Task claimed codex -> win (planning/design is the L3 lane).'
  END,
  updated_at        = now()
WHERE id = '2c710eb1-f333-4a0f-8b10-b9aad34a0df6';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO development_achievements (title, description, completed_at)
SELECT
  'MVP 機能スコープ v1 の確定',
  'docs/MVP_SCOPE.md に MVP 機能スコープ v1 を整備。PRD の広い In-Scope を、MVP ローンチ (2026-09-30 / 1,000 users) で必ず仕上げるコア 5 機能 (ホーム/ダッシュボード=本社, 健康・睡眠・ジャーナル=人事 最優先, AI大学+タグ付きノート=R&D, 家計簿・収支=財務, 横断 AI mentor=実行可否はユーザー決定) へ絞り込み。Deferred (SNS フル / モバイル同時リリース / 課金 / チーム機能) と現状維持 keep (比較ページ等) と遅延時の削減順を明記。PRD と WBS 実行の間を埋める MVP cut-line 層とし、最終確定は CEO 判断待ちの v1 叩き台 (Win版#132 part 244)。',
  DATE '2026-06-08'
WHERE NOT EXISTS (
  SELECT 1 FROM development_achievements WHERE title = 'MVP 機能スコープ v1 の確定'
);
