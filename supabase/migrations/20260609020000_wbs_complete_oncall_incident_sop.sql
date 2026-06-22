-- Win版#132 part 245 (2026-06-09 / Win Claude): Complete WBS 運用タスク
-- 「On-call / インシデント対応 SOP」 (task 8830188a-db00-44bc-b8c6-2adc51af6b68 / milestone mvp-launch).
--
-- 本タスクは owner_instance='codex' だったが、運用設計/SOP/docs は L3 (Win Claude) のレーン
-- であり ([DYNAMIC-CLAIM] = primary no-op 時の docs/product-light 引き取り)、運用設計成果物として
-- Win Claude が完了する。owner_instance も 'win' へ是正 (part 244 MVP scope と同パターン)。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/ONCALL_INCIDENT_SOP.md … MVP ローンチ版 umbrella 障害対応 SOP v1。
--       Sev 分類 (SEV1-3) / solo founder + AI fleet on-call モデル / 検知 source 表 (既存 GHA cron
--       + Sentry) / 6 ステップ一次対応フロー (Detect→Classify→Contain→Communicate→Recover→
--       Postmortem) / 既存 domain runbook への dispatch 表 (front door) / 通信プロトコル
--       (GitHub Issue 恒久 + Slack 時限 + mobile push) / blameless postmortem テンプレ。
--       成熟版 (RACI / PagerDuty 実席 / SLA) は paying-100 task 3cb3aa46 へ意図的に deferred。
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
  ai_review_notes   = 'Win Claude (architect lane / L3) self-authored deliverable. docs/ONCALL_INCIDENT_SOP.md に MVP ローンチ版 umbrella 障害対応 SOP v1 を整備 (Sev 分類 + solo founder/AI fleet on-call モデル + 既存検知 cron/Sentry 表 + 6 ステップフロー + 既存 runbook dispatch 表 + 通信プロトコル + blameless postmortem テンプレ)。成熟版は paying-100 task 3cb3aa46 へ deferred。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-09'),
  end_date          = DATE '2026-06-09',
  remaining_work    = 'Completed by Win Claude (part 245). On-call/incident SOP は docs/ONCALL_INCIDENT_SOP.md。MVP ローンチ運用即応性の baseline。成熟版 (RACI / PagerDuty 実席 / SLA / MTTR 集計) は paying-100 task 3cb3aa46 が上積みする。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-09: On-call/incident SOP v1 established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-09 (Win Claude part 245): On-call/incident SOP v1 established at docs/ONCALL_INCIDENT_SOP.md. Umbrella front-door SOP for MVP launch: severity classification (SEV1-3), solo-founder + AI-fleet on-call model (GHA cron + Sentry detection -> Slack webhook / GitHub Issue -> mobile push escalation; respects the SCHEDULE-WAKEUP night-zone), real detection-source table, 6-step response flow (Detect/Classify -> Contain -> Communicate -> Recover -> Postmortem mirroring mcp-auth-incident-runbook), dispatch table routing each incident class to existing domain runbooks (MCP auth / AI fallback / disk / asset QA / blog-news), communication protocol (GitHub Issue durable + Slack time-bound + mobile push, no secrets), and a blameless postmortem template stored under docs/incident-reports/. Mature version (RACI / PagerDuty seat / SLA / MTTR) is intentionally deferred to paying-100 task 3cb3aa46. Docs-only; no code/schema change. Task claimed codex -> win (operational design is the L3 lane).'
  END,
  updated_at        = now()
WHERE id = '8830188a-db00-44bc-b8c6-2adc51af6b68';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'On-call / インシデント対応 SOP v1 確立 (MVP ローンチ版)',
  'docs/ONCALL_INCIDENT_SOP.md を新設。本番障害の front-door SOP として Sev 分類 (SEV1-3) / solo founder + AI fleet の on-call モデル / 既存 GHA cron + Sentry を束ねた検知 source 表 / 6 ステップ一次対応フロー / 既存 domain runbook (MCP auth・AI fallback・disk・asset QA・blog-news) への dispatch 表 / 通信プロトコル / blameless postmortem テンプレを確立。ADR→PRD→四半期ロードマップ→MVP スコープに続く運用設計シリーズ第 5 弾。成熟版は paying-100 task へ deferred。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'On-call / インシデント対応 SOP v1 確立 (MVP ローンチ版)'
);
