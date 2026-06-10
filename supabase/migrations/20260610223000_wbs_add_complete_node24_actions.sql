-- Win版#132 part 264 (2026-06-10 / Win Claude): Add + Complete WBS 保守タスク
-- 「GitHub Actions Node.js 20 廃止対応 — actions/cache v4→v5」
--
-- 背景 (= GitHub 公式発表 / 2026-06-10 の deploy-prod run 27277677955 annotation で検出):
--   GitHub Actions は 2026-06-16 から Node.js 20 action を Node.js 24 で強制実行し、
--   2026-09-16 に Node 20 をランナーから削除する。本リポジトリで Node 20 のまま残っていた
--   action は .github/actions/setup-flutter-sdk/action.yml の actions/cache@v4 の 1 箇所のみ
--   (全 workflow inventory 実施済: third-party action ゼロ方針 / 他は checkout@v6,
--   setup-python@v6, setup-node@v6, setup-java@v5, upload-artifact@v7/v8,
--   download-artifact@v7/v8, github-script@v9, cache@v5(ci.yml) と全て Node 24 系 major)。
--
-- 対応: actions/cache@v4 → @v5 (公式 releases で v5 = Node.js 24 runtime / runner >= 2.327.1
--   要件を確認済。GitHub-hosted runner は常時最新で充足。with: パラメータ (path/key) は不変。
--   同一リポジトリ ci.yml の cache@v5 が既に green 稼働中 = in-repo 実証あり)。
--
-- WBS 取り扱い: user 標準指示「企画〜保守の全工程で不足タスクをゼロに (不足があれば追加)」に
--   基づき、保守工程の deadline 付き不足タスクとして追加し、同一セッション内で実対応まで完了。
--   追加と完了が同時なのは、期限 (6/16) まで 6 日と短く分割の意味がないため (honest 記録)。
--
-- Idempotent: INSERT は NOT EXISTS (title) guard / achievement も NOT EXISTS guard。

INSERT INTO public.wbs_tasks
  (category, category_icon, category_order, title, description, instance, owner_instance,
   status, progress, start_date, end_date, milestone_code, priority,
   ai_review_status, ai_review_notes, ai_reviewed_at, remaining_work, stale_threshold_hours)
SELECT
  'インフラ・CI/CD', '⚙️', 1,
  '[保守] GitHub Actions Node.js 20 廃止対応 (actions/cache v4→v5)',
  'GitHub Actions の Node.js 20 deprecation (2026-06-16 強制 Node 24 切替 / 2026-09-16 ランナー削除) への保守対応。deploy-prod run annotation で検出 → 全 .github/ inventory で Node 20 残存は .github/actions/setup-flutter-sdk/action.yml の actions/cache@v4 の 1 箇所のみと確定 (third-party action ゼロ方針 / 他 action は全て Node 24 系最新 major)。公式 releases で v5 = Node 24 runtime + runner >= 2.327.1 要件を確認の上 @v5 へ bump。ci.yml の cache@v5 は既に green 稼働中 (in-repo 実証)。Done 2026-06-10 (Win Claude part 264): SDLC 保守工程の不足タスクとして user 標準指示に基づき追加し、同一セッションで完了 (期限 6 日前 / PR part 264)。',
  'win', 'win',
  'completed', 100, DATE '2026-06-10', DATE '2026-06-10', 'alpha', 'high',
  'approved',
  'Win Claude (L3 / part 264) self-authored maintenance. 検出 = deploy-prod annotation (run 27277677955)。inventory = .github 全域 grep で actions/cache@v4 1 件のみ Node 20 残存と確定。修正 = @v5 bump (公式 releases で Node 24 runtime 確認 / API 不変 / ci.yml で v5 green 実績)。期限 2026-06-16 (GitHub 強制切替) より 6 日前に main 反映。',
  now(),
  'Completed by Win Claude (part 264). actions/cache@v4 → @v5 bump 済 (リポジトリ内 Node 20 action 残存ゼロ)。次の同種保守は GitHub の次期 deprecation 発表時に annotation 検出 → 即対応 (本タスクの description が手順の参照例)。',
  24
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[保守] GitHub Actions Node.js 20 廃止対応 (actions/cache v4→v5)'
);

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'GitHub Actions Node.js 20 廃止対応完了 (actions/cache v5 化)',
  'GitHub Actions の Node.js 20 deprecation (2026-06-16 強制切替) に対する保守対応。リポジトリ全 .github/ を inventory し、Node 20 残存が composite action (setup-flutter-sdk) 内の actions/cache@v4 の 1 箇所のみであることを確定 (third-party action ゼロ方針が奏功 / 他は全て Node 24 系最新 major)。GitHub 公式 releases で v5 = Node 24 runtime を確認の上 bump し、期限 6 日前に main 反映。SDLC 保守工程の不足タスクを WBS へ追加→同一セッション完了の第 1 例。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'GitHub Actions Node.js 20 廃止対応完了 (actions/cache v5 化)'
);
