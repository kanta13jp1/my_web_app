-- WBS task: 資産管理「前回給料の使いみち」入力ゼロ化 + AI 連携 (Issue #3006)
-- 2026-05-25 Win Claude #1 part 236
--
-- 背景: 本番資産管理ページの「前回給料の使いみち」widget が完全手動入力依存で
-- 全項目「未記録」状態。CEO ペルソナの経営判断 mentor 体験を提供できていない。
--
-- スコープ (3 連動 source):
--   A. 給料収入 + 給料日 auto-fill (= Issue #3003 連動 / payslips.pay_date → salaryDay)
--   B. 期間支出 AI category 自動分類 (EF `classify-expense` + Gemini 2.5 Flash + confidence gate)
--   C. AI コーチング card (weekly cron + Gemini 2.5 Pro + CEO mentor tone)
--
-- 依存: Issue #3003 (payslip ingestion) — A の前提。#3003 完了後着手。
--
-- 振分 (CODEX_WORKFLOW §6):
--   - A sync logic + UI/UX 設計: Win Claude
--   - B EF + DB schema + Flutter 連動: Win Codex
--   - C cron 設計 + tone 監修: Win Claude / 実装: Win Codex
--
-- スケジュール: #3003 (2026-08-20 終了) の翌週 2026-08-21〜09-03。
--   effort 大 (3 sub-scope + cron + LLM tuning) のため 2 週間枠。

INSERT INTO public.wbs_tasks
  (category, category_icon, category_order, title, description, instance, status, progress,
   start_date, end_date, milestone_code, priority, ai_review_status, stale_threshold_hours,
   github_issue_number)
VALUES
  ('business-product', '🚀', 300,
   '資産管理 前回給料の使いみち AI 連携 (Issue #3006)',
   '「前回給料の使いみち」widget を入力ゼロ化。A=payslip 連動 (#3003) / B=支出 AI 分類 (Gemini Flash + confidence gate) / C=weekly AI コーチング card (Gemini Pro + CEO mentor tone)。設計=Win Claude / 実装=Win Codex。詳細は Issue #3006。',
   'codex', 'pending', 0,
   '2026-08-21', '2026-09-03', 'mvp-launch', 'medium', 'pending', 72,
   3006)
ON CONFLICT DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win Claude #1: WBS task 前回給料の使いみち AI 連携 (Issue #3006)',
  'Win Claude #1 part 236 で資産管理 widget「前回給料の使いみち」の入力ゼロ化 + AI 連携 (3 連動 source A/B/C) の WBS task を登録。Issue #3003 (payslip ingestion) を前提とする後続タスク。category=business-product / instance=codex / 計画期間 2026-08-21〜09-03 / 7+/9 Philosophy alignment (CEO感 / mentor / 6 部署 / 商品=価値 / 資産負債 / KPI / IPO)。',
  '2026-05-25'
)
ON CONFLICT DO NOTHING;
