-- WBS task: 給料日サイクル可処分残高 + AI アクション指示 (Issue #3007)
-- 2026-05-25 Win Claude #1 part 236
--
-- 背景: 給料日に「次の給料日まで実際に使える額」を AI 算出 + 必要 user action を
-- 具体的に指示する未来視点 widget。既存「前回給料の使いみち」(過去視点) と対をなす。
--
-- スコープ (3 layer):
--   L1. データソース統合 — payslips (#3003) + 新規 recurring_expenses + debts table
--   L2. 計算ロジック — EF `compute-disposable-balance` (給料日サイクル境界 + breakdown)
--   L3. AI アクション指示 — Gemini 2.5 Pro structured output で
--       「給与明細をアップロード / ○○の債務残高を入力 / サブスク解約候補」等を mentor tone で生成
--
-- 依存: Issue #3003 (payslip ingestion) — L1 の入金 source。
-- 関連: Issue #3006 (使いみち AI 連携) — 同一 widget 内に統合可。
--
-- 振分 (CODEX_WORKFLOW §6):
--   - schema (recurring_expenses / debts) + AI prompt + tone 監修: Win Claude
--   - EF compute-disposable-balance + Flutter widget 拡張: Win Codex
--
-- スケジュール: #3006 (2026-09-03 終了) の翌週 2026-09-04〜09-17。
--   3 layer + 新規 table 2 + 新規 EF + AI prompt 設計のため 2 週間枠。

INSERT INTO public.wbs_tasks
  (category, category_icon, category_order, title, description, instance, status, progress,
   start_date, end_date, milestone_code, priority, ai_review_status, stale_threshold_hours,
   github_issue_number)
VALUES
  ('business-product', '🚀', 300,
   '資産管理 給料日サイクル可処分残高 + AI アクション指示 (Issue #3007)',
   '給料日に「次の給料日まで使える額」を AI 算出。L1=payslips (#3003) + 新規 recurring_expenses + debts table / L2=EF compute-disposable-balance / L3=Gemini Pro で具体的 user action (給与明細UP/債務残高入力/サブスク解約) を mentor tone 提案。設計+prompt=Win Claude / 実装=Win Codex。詳細は Issue #3007。',
   'codex', 'pending', 0,
   '2026-09-04', '2026-09-17', 'mvp-launch', 'medium', 'pending', 72,
   3007)
ON CONFLICT DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win Claude #1: WBS task 給料日サイクル可処分残高 AI (Issue #3007)',
  'Win Claude #1 part 236 で給料日サイクルの可処分残高 + AI アクション指示機能の WBS task を登録。Issue #3003 (payslip) を入金 source、Issue #3006 と同一 widget 統合可能な未来視点機能。category=business-product / instance=codex / 計画期間 2026-09-04〜09-17 / 8/9 Philosophy alignment (CEO感 / mentor / 6部署 / 商品=価値 / 資産負債 / KPI / IPO + ミッション弱関連)。',
  '2026-05-25'
)
ON CONFLICT DO NOTHING;
