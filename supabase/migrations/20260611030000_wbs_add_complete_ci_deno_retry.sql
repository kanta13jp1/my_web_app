-- Win版#132 part 266 (2026-06-11 / Win Claude): Add + Complete WBS 保守タスク
-- 「CI Setup Deno の deno.land 一時503耐性化 (retry+backoff)」
--
-- 背景 (= workflow-failure Issue #3215 / 2026-06-11 02:30 JST 検出):
--   main への push (part 265 merge commit 407cdc9e4) で deploy-prod が fail。
--   workflow-failure-handler の分類は「deno-lint」だったが誤分類で、実ログ
--   (run 27293741687 / job 80620889988) の確証は
--     curl: (22) The requested URL returned error: 503
--   = ci.yml「Setup Deno」step の `curl -fsSL https://deno.land/install.sh | sh`
--   が deno.land の一時 503 で fail → reusable ci.yml の Lint, Format, and Test
--   ごと fail → deploy job skip。lint エラーは一切発生していない。
--   副作用: deploy job skip により part 265 の WBS migration (20260611021500) が
--   本番 DB 未適用のまま滞留 (失敗 run の rerun で回復)。
--
-- 対応 (2 段):
--   1. 即時復旧 = `gh run rerun 27293741687 --failed` (同 commit / 一時障害仮説の検証込み)。
--      green 化で handler の recovery rule により Issue #3215 は自動 close。
--   2. 恒久対応 = ci.yml Setup Deno へ retry+backoff (3 attempts / 20s,40s) を追加。
--      deploy-prod.yml の deploy_function と同じ repo 既存 idiom。installer は
--      一時ファイル経由に変更 (stdout パイプ直結だと curl --retry が rewind 不能で、
--      切断時に truncated script が sh へ流れるハザードがあるため)。
--
-- 代替案 (検討の上 defer): denoland/setup-deno@v2 公式 action への移行。
--   action.yml (main) で runs.using = node24 を verify 済 (2026-06-11 / Node20
--   廃止問題なし) + deno-version pin / cache / tool-cache retry 内蔵。ただし
--   インストール機構の置換は deploy lane への新規依存追加であり、今回の真因
--   (一時 503) には retry が strict superset の最小修正のため defer。月 2 回以上
--   再発するなら L2 で移行を検討 (remaining_work に正本化)。
--
-- WBS 取り扱い: user 標準指示「企画〜保守の全工程で不足タスクをゼロに (不足があれば追加)」
--   に基づき、保守工程の恒久対応タスクとして追加し、同一セッション内で完了 (part 264 型
--   第 3 例)。症状チケット #3215 は workflow-failure handler 管理 (recovery rule で
--   自動 close) のため本 migration では WBS 化しない (part 265 の Issue close 委譲準拠)。
--
-- Idempotent: INSERT は NOT EXISTS (title) guard / achievement も NOT EXISTS guard。

INSERT INTO public.wbs_tasks
  (category, category_icon, category_order, title, description, instance, owner_instance,
   status, progress, start_date, end_date, milestone_code, priority,
   ai_review_status, ai_review_notes, ai_reviewed_at, remaining_work, stale_threshold_hours)
SELECT
  'インフラ・CI/CD', '⚙️', 1,
  '[保守] CI Setup Deno の deno.land 一時503耐性化 (retry+backoff)',
  'ci.yml「Setup Deno」が deno.land インストーラを素の curl|sh で取得しており、deno.land の一時 503 で main の deploy-prod ごと fail した (2026-06-10 17:30 UTC run 27293741687 / Issue #3215 / 実ログ確証 = curl: (22) The requested URL returned error: 503)。handler の deno-lint 分類は誤分類で lint エラーは不在。恒久対応として retry+backoff (3 attempts / 20s,40s / curl --retry 併用 / 一時ファイル経由で truncated-script ハザードも解消) を追加 — deploy-prod.yml の deploy_function と同じ repo 既存 idiom。即時復旧は failed jobs rerun (同 commit) で実施し、green 化により part 265 migration の本番適用も回復。Done 2026-06-11 (Win Claude part 266): SDLC 保守工程の不足タスクとして追加し、同一セッションで完了。',
  'win', 'win',
  'completed', 100, DATE '2026-06-11', DATE '2026-06-11', 'alpha', 'high',
  'approved',
  'Win Claude (L3 / part 266) self-authored maintenance. 根拠 = job 80620889988 log の curl exit 22 (HTTP 503) 全文 + deploy-prod run 履歴 (直前 da667bc5d は success = コード起因でない)。denoland/setup-deno@v2 代替は action.yml で node24 確認の上、最小修正原則 (deploy lane へ新規依存を足さない) で defer。',
  now(),
  'Completed by Win Claude (part 266). ci.yml retry 追加済 + run 27293741687 rerun 実施。followup: deno.land 起因の Setup Deno fail が月 2 回以上再発する場合は denoland/setup-deno@v2 (node24 / deno-version 2.x pin / cache 内蔵) への移行を L2 lane で検討。',
  24
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[保守] CI Setup Deno の deno.land 一時503耐性化 (retry+backoff)'
);

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'CI Setup Deno の deno.land 一時503耐性化 (retry+backoff)',
  'main push の deploy-prod が deno.land の一時 503 (curl exit 22) で fail し本番デプロイ + migration 適用が滞留する問題 (2026-06-10 run 27293741687 / Issue #3215) を恒久解消。workflow-failure handler の「deno-lint」誤分類を実ログで是正し、ci.yml Setup Deno へ deploy_function と同一 idiom の retry+backoff を追加 (一時ファイル経由化で curl|sh の truncated-script ハザードも解消)。SDLC 保守工程の不足タスクを WBS へ追加→同一セッション完了の第 3 例。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'CI Setup Deno の deno.land 一時503耐性化 (retry+backoff)'
);
