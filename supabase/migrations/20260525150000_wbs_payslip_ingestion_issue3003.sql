-- WBS task: 給与明細 PDF を AI parse して財務情報 DB 取込 (Issue #3003)
-- 2026-05-25 Win Claude #1 part 236
--
-- 背景: ユーザーが MightyLINK の月次給与明細 PDF を手動転記している状態を解消し、
-- 「財務 = 商品の対価」(PHILOSOPHY 原則 6) を自動可視化する pipeline を新規追加する。
--
-- スコープ (MVP / Issue #3003 参照):
--   1. Supabase Storage bucket `payslips/` + RLS (auth.uid() = owner)
--   2. migration: `payslips` table (gross / net / deductions jsonb / earnings jsonb / attendance jsonb)
--   3. Edge Function `parse-payslip` (Deno) — PDF text 抽出 → LLM structured extraction
--      → Vision fallback (scan PDF) / PII mask (氏名・従業員番号) 必須
--   4. Flutter Web: 既存 asset/finance hub に「給与明細アップロード」action 追加 (EF-FIRST)
--   5. 月次推移チャート + 控除内訳 UI
--
-- 振分判定 (CODEX_WORKFLOW §6):
--   - schema/migration 設計 + PII mask セキュリティレビュー: Win Claude (architect)
--   - EF Deno 実装 + Flutter UI: Win Codex (impl)
--
-- スケジュール: Codex backlog が Issue #2508 (2026-08-11) まで埋まっているため
--   2026-08-13 開始の planned slot に追加。priority=medium で配置し、user の要望次第で
--   優先度を rebalance できるよう ai_review_status='pending' で起こす。

INSERT INTO public.wbs_tasks
  (category, category_icon, category_order, title, description, instance, status, progress,
   start_date, end_date, milestone_code, priority, ai_review_status, stale_threshold_hours,
   github_issue_number)
VALUES
  ('business-product', '🚀', 300,
   '給与明細 PDF AI parse → 財務 DB 取込 (Issue #3003)',
   'MightyLINK 等の月次給与明細 PDF をアップロードすると LLM 経由で構造化し、payslips テーブルに保存。資産/財務 hub の月次推移チャートで可視化。PII mask + RLS 必須。schema/security = Win Claude, EF/UI = Win Codex。詳細は Issue #3003。',
   'codex', 'pending', 0,
   '2026-08-13', '2026-08-20', 'mvp-launch', 'medium', 'pending', 72,
   3003)
ON CONFLICT DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win Claude #1: WBS task 給与明細 PDF AI 取込 (Issue #3003)',
  'Win Claude #1 part 236 で給与明細 PDF を AI parse して財務 DB に取り込む新規機能の WBS task を登録。category=business-product / instance=codex / milestone=mvp-launch / 計画期間 2026-08-13〜08-20 / 7+/9 Philosophy alignment (CEO感 / 商品=価値 / 資産負債 / KPI)。',
  '2026-05-25'
)
ON CONFLICT DO NOTHING;
