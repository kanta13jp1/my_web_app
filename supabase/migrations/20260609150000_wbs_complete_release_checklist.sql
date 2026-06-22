-- Win版#132 part 250 (2026-06-09 / Win Claude): Complete WBS リリース工程タスク
-- 「[リリース] リリースチェックリストとロールバック整備」
--  (task e601b30f-f86a-4374-9133-0f11c8ec77a2 / category リリース / deploy-prod gate + canary 確認 +
--   rollback runbook を 1 リリース工程として管理する).
--
-- 本タスクは owner_instance='codex' だったが、release SOP / rollback runbook の「設計・文書化」は
-- L3 (Win Claude) の architect/ops-docs レーン ([DYNAMIC-CLAIM] = docs 引き取り可)。user の明示的
-- /loop 再起動による指示で本 session 2 件目。owner も 'win' へ是正。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/RELEASE_CHECKLIST_ROLLBACK.md … 毎回の本番リリースを安全に回す反復手順の SSOT。
--       実 deploy-prod.yml を正確に記述 (ci→deploy→notify / 自動採番 / supabase db push +
--       migration repair / EF 22 本 hub デプロイ / Flutter build / Firebase Hosting 原子入替 /
--       version.json commit 反映検証 / 並行 cancel-in-progress:false)。
--       リリース前チェックリスト + リリース後スモーク (canary 基盤が無い現状を正直に明記し
--       staging+スモーク+高速ロールバックで代替) + rollback runbook (Firebase 復帰 / git revert
--       前進専用 / migration 前進専用 fix / reset --hard + force-push は禁止 = 旧 archived
--       DEPLOYMENT_GUIDE の危険手順を置換) + バージョン検証 + gotchas + 役割。
--   既存ドキュメントと非重複: GA_LAUNCH_READINESS_GATE_SPEC.md (一度きりの GA 可否) /
--   ONCALL_INCIDENT_SOP.md (障害発生後の対応) とは境界を明示し相互参照。
--
-- 完了の定義: リリース手順 + ロールバック runbook の「設計・文書化」が成果物 (タスク = 整備)。
-- deploy-prod.yml 等の実装変更は L2/Codex の別アクション (本 migration では完了扱いにしない)。
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
  ai_review_notes   = 'Win Claude (architect / release・ops docs lane / L3) self-authored deliverable. docs/RELEASE_CHECKLIST_ROLLBACK.md に毎回の本番リリースを安全に回す反復手順 SSOT を整備。実 deploy-prod.yml を正確に記述 (ci→deploy→notify / supabase db push + migration repair / EF hub デプロイ / Firebase Hosting 原子入替 / version.json commit 反映検証 / cancel-in-progress:false)。リリース前チェックリスト + リリース後スモーク (canary 基盤不在を正直に明記し staging+スモーク+高速ロールバックで代替) + rollback runbook (Firebase 復帰 / git revert 前進専用 / migration 前進専用 fix / reset --hard+force-push 禁止 = 旧 archived DEPLOYMENT_GUIDE の危険手順を置換) + バージョン検証 + gotchas + 役割。GA gate (GA_LAUNCH_READINESS_GATE_SPEC.md) / 障害対応 (ONCALL_INCIDENT_SOP.md) とは境界明示で非重複。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-09'),
  end_date          = DATE '2026-06-09',
  remaining_work    = 'Completed by Win Claude (part 250). リリース工程 SSOT = docs/RELEASE_CHECKLIST_ROLLBACK.md (リリース前チェック + 実行 + リリース後スモーク + rollback runbook + バージョン検証)。残: deploy-prod.yml 等の実装変更・プログレッシブ canary 基盤の構築は L2/Codex の別タスク (本書は手順正本)。障害対応詳細は ONCALL_INCIDENT_SOP.md / 一度きりの GA 可否は GA_LAUNCH_READINESS_GATE_SPEC.md が正本。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-09: Release checklist + rollback runbook established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-09 (Win Claude part 250): Release checklist + rollback runbook established at docs/RELEASE_CHECKLIST_ROLLBACK.md as the SSOT for the repeatable production-release process. Accurately documents the real deploy-prod.yml pipeline (ci -> deploy -> notify; auto version bump; supabase db push with idempotent migration repair; 22-function hub Edge Function deploy under the EF<=50 cap; Flutter web build; atomic Firebase Hosting swap; version.json commit-reflection verification; concurrency cancel-in-progress:false sequential deploys). Adds a pre-release checklist, post-deploy smoke verification (honestly notes there is no progressive canary infra and substitutes staging + smoke + fast rollback), and a rollback runbook (Firebase Hosting revert as fastest first move; git revert forward-only; Supabase forward-only fix migrations with no down-migrations; explicitly forbids the archived DEPLOYMENT_GUIDE git reset --hard + force-push), plus version verification, gotchas, and roles. Boundaries with GA_LAUNCH_READINESS_GATE_SPEC.md (one-time GA go/no-go) and ONCALL_INCIDENT_SOP.md (post-incident response) are made explicit, so it complements rather than duplicates. Docs-only; no code/schema change. 2nd task this session under explicit user /loop re-invocation. Task claimed codex -> win (release/ops docs is the L3 lane). Completion = authoring the process doc + runbook; deploy-prod.yml implementation changes remain L2/Codex actions.'
  END,
  updated_at        = now()
WHERE id = 'e601b30f-f86a-4374-9133-0f11c8ec77a2';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'リリースチェックリスト & ロールバック Runbook 整備',
  'docs/RELEASE_CHECKLIST_ROLLBACK.md を新設。毎回の本番リリースを安全に回す反復手順の SSOT として、実 deploy-prod.yml パイプライン (ci→deploy→notify / 自動採番 / supabase db push + migration repair / EF hub デプロイ / Firebase Hosting 原子入替 / version.json commit 反映検証 / 並行 cancel-in-progress:false) を正確に記述。リリース前チェックリスト + リリース後スモーク (canary 基盤不在を正直に明記し staging+スモーク+高速ロールバックで代替) + ロールバック runbook (Firebase 復帰 / git revert・migration 前進専用 / reset --hard+force-push 禁止 = 旧 archived DEPLOYMENT_GUIDE 置換) + バージョン検証 + gotchas + 役割を整備。GA gate / 障害対応 SOP とは境界明示で非重複。MVP ローンチ準備設計シリーズ第 10 弾 (リリース運用面)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'リリースチェックリスト & ロールバック Runbook 整備'
);
