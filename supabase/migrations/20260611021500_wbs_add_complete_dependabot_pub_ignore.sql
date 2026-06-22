-- Win版#132 part 265 (2026-06-11 / Win Claude): Add + Complete WBS 保守タスク
-- 「dependabot pub group 週次CI失敗の恒久解消 (flutter_native_splash >=2.4.8 ignore)」
--
-- 背景 (= workflow-failure Issue #3209 / #3211 / 2026-06-10 検出):
--   dependabot の pub ecosystem grouped update (flutter-dependencies) が
--   flutter_native_splash 2.4.7→2.4.8 bump を含むたびに `flutter pub get` で
--   version solving fail する:
--     flutter_native_splash 2.4.8 は meta ^1.18.0 を要求
--     vs CI の Flutter stable (3.38.10) の flutter_test は meta 1.17.0 を pin
--   (PR #3208 の CI job 80577000469 log で確証)。group は 1 メンバー衝突で全体
--   install fail するため、supabase / supabase_flutter / test の正常 bump 3 件も
--   道連れになる。さらに同じ pub get 失敗が CI Auto-Fix workflow にも伝播し
--   (run 27281548713)、毎週 workflow-failure Issue + WBS タスクのノイズを再生産
--   (2026-06-02 の #3057 でも同一根本原因を診断済 = 週次再発の 2 回目)。
--
-- 対応: GitHub 公式 docs (dependabot options reference / comment commands) を
--   verify-first で確認の上、.github/dependabot.yml の pub ecosystem に
--   ignore { dependency-name: flutter_native_splash, versions: [">=2.4.8"] } を追加
--   (config file が auditable な正攻法 / @dependabot close は同 update の再作成まで
--   block する副作用があるため不採用)。解除条件 (CI Flutter stable が meta >=1.18.0
--   同梱) を YAML コメントに明記。merge 後に PR #3208 へ @dependabot recreate を
--   コメントし、ignore 適用後の group PR (正常 3 bump のみ) に再生成させる。
--
-- WBS 取り扱い: user 標準指示「企画〜保守の全工程で不足タスクをゼロに (不足があれば追加)」
--   に基づき、保守工程の恒久対応タスクとして追加し、同一セッション内で完了 (part 264 型
--   第 2 例)。症状チケット側の WBS 2 件 (9339a406 = Issue #3209 / 3b5fec8d = Issue #3211)
--   は gha-owned issue-linked のため本 migration では触らず、Issue close → GitHub Issues
--   WBS Sync cron の自然 lifecycle で completed 化させる (part 260 の sync 上書き挙動準拠)。
--
-- Idempotent: INSERT は NOT EXISTS (title) guard / achievement も NOT EXISTS guard。

INSERT INTO public.wbs_tasks
  (category, category_icon, category_order, title, description, instance, owner_instance,
   status, progress, start_date, end_date, milestone_code, priority,
   ai_review_status, ai_review_notes, ai_reviewed_at, remaining_work, stale_threshold_hours)
SELECT
  'インフラ・CI/CD', '⚙️', 1,
  '[保守] dependabot pub group 週次CI失敗の恒久解消 (flutter_native_splash ignore)',
  'dependabot flutter-dependencies grouped update が flutter_native_splash 2.4.8 (meta ^1.18.0 要求) を含むたびに、CI Flutter stable (3.38.x / flutter_test が meta 1.17.0 を pin) と衝突して group 全体の pub get が fail する週次再発 (2026-06-02 #3057 → 2026-06-10 #3209/#3211) への恒久対応。GitHub 公式 docs (options reference / comment commands) を確認の上、.github/dependabot.yml の pub ecosystem へ ignore (flutter_native_splash >=2.4.8) を追加し、解除条件 (CI Flutter stable が meta >=1.18.0 同梱) を YAML コメントへ明記。merge 後 PR #3208 に @dependabot recreate で正常 3 bump (supabase/supabase_flutter/test) のみの group PR を再生成。Done 2026-06-11 (Win Claude part 265): SDLC 保守工程の不足タスクとして追加し、同一セッションで完了 (症状 Issue #3209/#3211 close 込み)。',
  'win', 'win',
  'completed', 100, DATE '2026-06-11', DATE '2026-06-11', 'alpha', 'high',
  'approved',
  'Win Claude (L3 / part 265) self-authored maintenance. 根拠 = PR #3208 CI log (job 80577000469) の version solving fail 全文 + CI Auto-Fix run 27281548713 への伝播確認。修正 = dependabot.yml ignore 追加 (GitHub 公式 docs で ignore×groups の挙動 = ignored dependency は group PR から除外、を確認済)。@dependabot close 不採用の理由 = 同 update 再作成 block の副作用 (公式 docs 明記)。',
  now(),
  'Completed by Win Claude (part 265). dependabot.yml ignore 追加済 + Issue #3209/#3211 close 済。解除 followup: CI の Flutter stable が meta >=1.18.0 を同梱した時点で ignore 2 行を削除し flutter_native_splash の更新を再開する (dependabot.yml 内コメントが解除条件の正本)。',
  24
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[保守] dependabot pub group 週次CI失敗の恒久解消 (flutter_native_splash ignore)'
);

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'dependabot pub group 週次CI失敗の恒久解消 (flutter_native_splash ignore)',
  'dependabot の flutter-dependencies grouped update が flutter_native_splash 2.4.8 の meta ^1.18.0 要求と CI Flutter stable (flutter_test = meta 1.17.0 pin) の衝突で週次 fail し、正常な supabase 系 bump まで道連れ + CI Auto-Fix / workflow-failure Issue のノイズを再生産していた問題 (2026-06-02 #3057 → 2026-06-10 #3209/#3211) を恒久解消。GitHub 公式 docs を verify-first で確認し、dependabot.yml へ auditable な ignore rule (>=2.4.8 / 解除条件コメント付き) を追加。SDLC 保守工程の不足タスクを WBS へ追加→同一セッション完了の第 2 例。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'dependabot pub group 週次CI失敗の恒久解消 (flutter_native_splash ignore)'
);
