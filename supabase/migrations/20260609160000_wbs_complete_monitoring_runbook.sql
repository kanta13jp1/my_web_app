-- Win版#132 part 251 (2026-06-09 / Win Claude): Complete WBS 本番監視運用タスク
-- 「[運用] 本番監視・インシデント対応 runbook」
--  (task 2e8be6a7-6741-4e38-a910-e96267caa018 / category 運用 /
--   cs-check・ci-cd-audit・incident report を定常運用として WBS に接続 + escalation + health-check evidence).
--
-- 本タスクは owner_instance='codex' だったが、運用 SOP / monitoring runbook の「設計・文書化」は
-- L3 (Win Claude) の architect/ops-docs レーン ([DYNAMIC-CLAIM] = docs 引き取り可)。user の明示的
-- /loop 再起動による指示で本 session 3 件目。owner も 'win' へ是正。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/PRODUCTION_MONITORING_RUNBOOK.md … 本番監視の定常運用 (緑の道) SSOT。
--       監視サーフェス一覧 (実 GHA cron: health-monitor / infra-health-check / quota-monitor /
--       daily-report-freshness-monitor / config-size-monitor / mcp-audit-anomaly-cron /
--       wbs-staleness-audit / edge-function-audit / competitor-monitoring / cs-check + claude.ai
--       Routine の ci-cd-cost-audit + Sentry + deploy-prod 状態) を cadence/健全vs異常/出力先で整理。
--       定常運用 cadence (毎セッション/日次/定期/障害時/週次) を WBS/Issue 接続ルール付きで定義
--       (定常運用は cron / 異常・改善のみ Issue 化)。健全性の証跡 (version.json commit / health-check
--       EF / cron green / Sentry / wbs-staleness) + escalation (緑→赤は Sev 判定して ONCALL_INCIDENT_SOP
--       へ dispatch) + 役割 + Deferred (Sentry 深掘りは 120afbf8/Codex / synthetic は paying-100)。
--   ops 三部作: 本書 (監視) / ONCALL_INCIDENT_SOP.md (対応) / RELEASE_CHECKLIST_ROLLBACK.md (リリース)
--   を境界明示で非重複 (SOP の検知 source 表を運用 cadence 視点で展開し重複記述を回避)。
--
-- 完了の定義: 監視運用手順 + escalation の「設計・文書化」が成果物 (タスク = runbook 整備 + WBS 接続規律)。
-- 監視 workflow / Sentry 連携の実装変更は L2/Codex の別アクション (本 migration では完了扱いにしない)。
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
  ai_review_notes   = 'Win Claude (architect / ops docs lane / L3) self-authored deliverable. docs/PRODUCTION_MONITORING_RUNBOOK.md に本番監視の定常運用 (緑の道) SSOT を整備。実 GHA cron 群 (health-monitor / infra-health-check / quota-monitor / daily-report-freshness / config-size / mcp-audit-anomaly / wbs-staleness-audit / edge-function-audit / competitor-monitoring / cs-check) + claude.ai Routine (ci-cd-cost-audit) + Sentry + deploy-prod 状態を cadence/健全vs異常/出力先で整理。定常運用 cadence を WBS/Issue 接続規律付きで定義 (定常は cron / 異常・改善のみ Issue 化)。健全性証跡 + escalation (緑→赤は Sev 判定して ONCALL_INCIDENT_SOP へ dispatch) + 役割 + Deferred。ops 三部作 (監視/対応/リリース) を境界明示で非重複。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-09'),
  end_date          = DATE '2026-06-09',
  remaining_work    = 'Completed by Win Claude (part 251). 監視運用 SSOT = docs/PRODUCTION_MONITORING_RUNBOOK.md (監視サーフェス一覧 + 定常運用 cadence + 健全性証跡 + escalation + 役割)。残: 監視 workflow / Sentry 連携の実装は L2/Codex (WBS 120afbf8 エラー監視強化 / milestone v1)。synthetic 監視・SLA 数値化は paying-100 へ deferred。障害対応詳細は ONCALL_INCIDENT_SOP.md が正本。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-09: Production monitoring runbook established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-09 (Win Claude part 251): Production monitoring + routine-ops runbook established at docs/PRODUCTION_MONITORING_RUNBOOK.md as the SSOT for the "green path" (confirming health in steady state). Inventories the real monitoring surfaces (GHA crons health-monitor / infra-health-check / quota-monitor / daily-report-freshness-monitor / config-size-monitor / mcp-audit-anomaly-cron / wbs-staleness-audit / edge-function-audit / competitor-monitoring / cs-check, the claude.ai ci-cd-cost-audit routine, Sentry, and deploy-prod status) with cadence / healthy-vs-alarming / output sink. Defines the routine-ops cadence (per-session / daily / periodic / incident / weekly) with the WBS-Issue connection rule (routine ops run via cron; only anomalies and improvements become Issues, per the task ask to connect cs-check / ci-cd-audit / incident report to the WBS as standing operations). Adds health-check evidence (version.json commit, health-check EF, green crons, Sentry, wbs-staleness), an escalation path (green -> red: classify Sev then dispatch to ONCALL_INCIDENT_SOP), roles, and deferred scope. Forms the ops trilogy with ONCALL_INCIDENT_SOP.md (respond) and RELEASE_CHECKLIST_ROLLBACK.md (release), with explicit boundaries so it complements rather than duplicates (the SOP detection-source table is reframed from the operating-cadence angle). Docs-only; no code/schema change. 3rd task this session under explicit user /loop re-invocation. Task claimed codex -> win (ops docs is the L3 lane). Completion = authoring the monitoring runbook + WBS-connection discipline; monitoring-workflow / Sentry implementation remains L2/Codex.'
  END,
  updated_at        = now()
WHERE id = '2e8be6a7-6741-4e38-a910-e96267caa018';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '本番監視 & 定常運用 Runbook 整備 (ops 三部作 完成)',
  'docs/PRODUCTION_MONITORING_RUNBOOK.md を新設。本番監視の定常運用 (緑の道) SSOT として、実 GHA cron 群 + claude.ai Routine (ci-cd-cost-audit) + Sentry + deploy-prod 状態を cadence/健全vs異常/出力先で整理し、定常運用 cadence (毎セッション/日次/定期/障害時/週次) を WBS/Issue 接続規律付きで定義 (定常は cron / 異常・改善のみ Issue 化)。健全性証跡 + escalation (緑→赤は Sev 判定して ONCALL_INCIDENT_SOP へ dispatch) + 役割 + Deferred を整備。監視 (本書) / 対応 (ONCALL_INCIDENT_SOP) / リリース (RELEASE_CHECKLIST_ROLLBACK) の ops 三部作を境界明示で完成。MVP ローンチ準備設計シリーズ第 11 弾 (運用監視面)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '本番監視 & 定常運用 Runbook 整備 (ops 三部作 完成)'
);
