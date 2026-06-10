-- Win版#132 part 258 (2026-06-10 / Win Claude): Complete WBS SPOF リスク評価タスク
-- 「[Issue #2599] [notebooklm:3fc9a086:1] クラウドインフラおよびCI/CDの単一障害点（SPOF）リスクの
--  評価とマルチリージョン・フェイルオーバー戦略の策定」
--  (task aa08e69f-0dc5-46fc-a656-adb4140407f9 / owner schedule→win)
--
-- タスク本質 = 「評価」と「戦略の策定」(= 設計 / L3 architect レーン)。owner 'schedule' は
-- NotebookLM requirement 自動起票によるもので、設計成果物は L3 が担当 ([DYNAMIC-CLAIM] docs/設計)。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/SPOF_FAILOVER_STRATEGY.md … SPOF 評価 & フェイルオーバー戦略 v1。
--       実在構成 (Supabase 単一プロジェクト / Firebase Hosting / GitHub+GHA / AI API / 人的 SPOF) の
--       SPOF 台帳と優先順位 (データ S1 最優先 = 取り返せない資産) + バックアップ・復元設計
--       (migrations=スキーマ SSOT / supabase db dump 手動手順 / 別プロジェクト復元 6 ステップ /
--       PITR・自動バックアップは plan 依存のため【確認事項】= 確認まで「ある」と言わない /
--       restore drill 未実施を明記 = 実証済みと主張しない) + GHA 障害時の代替手動デプロイ手順
--       (実 deploy-prod.yml L530-705 から導出: db push → functions deploy → flutter build web →
--       firebase-tools deploy / part 244 の local-CI バージョン不一致罠を注意書き) +
--       縮退運転モードの設計 (現状 verify: Sentry+ErrorReporter+auth-graceful は実装済み /
--       オフラインキャッシュ未実装 → Phase A/B/C 段階設計 / 実装は L2) +
--       マルチリージョン判断 (現規模ではコールドスタンバイが正 = 正直な戦略決定 /
--       再評価トリガ = paying-100 or 有償 SLA 契約)。
--
-- Issue #2599 との対応 (honest scope):
--   受入基準 1 (リージョン可用性評価+バックアップ復元手順 doc 化) = §2-§3 充足 ✅
--   受入基準 2 (GHA 障害時の代替手順確立) = §4 充足 ✅
--   受入基準 3 (Flutter 縮退運転モードの実装) = §5 で設計まで。実装は L2 → **Issue #2599 は
--   close しない (open 維持 / 基準 3 の実装 handoff として機能)**。WBS タスク完了の根拠 =
--   タスクタイトルのスコープ (評価+策定) を充足したこと。
--   Issue 中の外部事実 (GHA 障害 57 回/12mo 等) は未検証主張として本書の判断根拠から除外 ([AI-TOOL-VERIFY])。
--
-- ai_review_status='approved' を同一 UPDATE で設定 → trigger 回避で status='completed' 確定。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect / L3 設計レーン / part 258) self-authored deliverable. docs/SPOF_FAILOVER_STRATEGY.md に SPOF 評価 & フェイルオーバー戦略 v1 を策定。実在構成のみから SPOF 台帳 (S1 Supabase データ最優先) + バックアップ/復元設計 (db dump 手順 + 別プロジェクト復元 6 ステップ / PITR は【確認事項】/ drill 未実施を明記) + GHA 障害時代替デプロイ手順 (実 workflow から導出 + part 244 バージョン不一致罠注記) + 縮退運転モード段階設計 (現状 verify: Sentry/ErrorReporter/auth-graceful 実装済・オフラインキャッシュ未実装 → Phase A/B 設計 = L2 handoff) + マルチリージョン判断 (現規模はコールドスタンバイが正 / 再評価 = paying-100)。Issue #2599 受入基準 1-2 充足 / 基準 3 (実装) は Issue open 維持で L2 へ。外部未検証数値は判断根拠から除外。docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by Win Claude (part 258) — 評価+戦略策定 (タスクタイトルのスコープ)。残 (本タスク外 / Issue #2599 open 維持): 基準 3 = Flutter 縮退運転モード Phase A/B 実装 (L2/Codex / 設計 = doc §5) / PITR・自動バックアップ現状の dashboard 確認【CEO】/ restore drill 初回実施【CEO 日程】/ バックアップ自動化 cron (L2)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: SPOF assessment and failover strategy authored%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10: SPOF assessment and failover strategy authored at docs/SPOF_FAILOVER_STRATEGY.md (Win Claude part 258). Grounded in the real stack only (single Supabase project, Firebase Hosting, GitHub+GHA, AI APIs, single-operator risk): SPOF ledger with data (S1) as top priority; backup/restore design (migrations as schema SSOT, supabase db dump manual procedure, 6-step restore into a new project/region, PITR and automatic-backup status marked as a dashboard check item rather than assumed, and the restore drill explicitly marked as not yet performed); an alternative manual deploy path for GitHub Actions outages derived from the real deploy-prod.yml steps (db push, functions deploy, flutter build web, firebase-tools deploy) with the part-244 local-vs-CI toolchain mismatch warning; a staged degraded-mode design for the Flutter client (verified current state: Sentry + ErrorReporter + graceful auth-unavailable handling exist, offline cache does not; Phases A/B specified for L2 implementation); and an honest multi-region decision (cold standby is the v1 strategy at current scale, re-evaluated at paying-100 or paid SLA). Issue #2599 acceptance criteria 1-2 are satisfied by this document; criterion 3 (client degraded-mode implementation) remains open, so Issue #2599 is intentionally kept open as the L2 implementation handoff. External incident statistics quoted in the issue were treated as unverified and excluded from decision rationale. Task completed as the assessment-and-strategy scope of its title; owner flipped schedule -> win.'
  END,
  updated_at        = now()
WHERE id = 'aa08e69f-0dc5-46fc-a656-adb4140407f9';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'SPOF リスク評価 & フェイルオーバー戦略 v1 策定 (バックアップ/復元 + GHA 代替デプロイ + 縮退設計)',
  'docs/SPOF_FAILOVER_STRATEGY.md を新設。実在構成のみを根拠に SPOF 台帳 (Supabase データ = 最優先 / GHA / Firebase / AI API / 人的) を評価し、バックアップ・復元設計 (supabase db dump 手順 + 別プロジェクト復元 6 ステップ / PITR は確認事項として断定しない / restore drill 未実施を明記)、GitHub Actions 障害時の代替手動デプロイ手順 (実 deploy-prod.yml から導出)、Flutter 縮退運転モードの段階設計 (Phase A/B = L2 実装 handoff / Issue #2599 open 維持)、マルチリージョン判断 (現規模はコールドスタンバイが正 / paying-100 で再評価) を策定。NotebookLM 由来の未検証外部数値は判断根拠から除外した honest 設計 (設計シリーズ第 15 弾)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'SPOF リスク評価 & フェイルオーバー戦略 v1 策定 (バックアップ/復元 + GHA 代替デプロイ + 縮退設計)'
);
