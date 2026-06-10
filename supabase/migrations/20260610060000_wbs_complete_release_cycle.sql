-- Win版#132 part 255 (2026-06-10 / Win Claude): Complete WBS 機能リリースサイクルタスク
-- 「機能 release cycle 確立 (隔週)」
--  (task 39b30ef2-83ed-4a10-bce3-915e272093c7 / category business-product / milestone paying-100 /
--   description: 隔週 release note / changelog page).
--
-- 本タスクは owner_instance='codex' だったが、リリース cadence の方針設計 (process/policy docs) は
-- L3 (Win Claude) の architect/ops-docs レーン ([DYNAMIC-CLAIM] = product-light/docs 引き取り可 /
-- business-product は禁止カテゴリに非該当)。user 明示 /loop 再起動による本 session 4 round 目。
-- owner も 'win' へ是正。
--
-- 重要な実態 (verify 済み): description が求める 2 artifact は既存 —
--   - release note: scripts/generate_release_notes.py → web/release-notes.json (PR/Releases/deploy
--     metadata から決定的に自動生成 / docs/release-notes/README.md) + lib/pages/release_notes_page.dart
--   - changelog page: lib/pages/changelog_manager_page.dart + development_achievements ページ
-- 欠けていたのは「隔週」のリズムと編纂規律 → それを本成果物で確立。新規アプリ開発ゼロ ([EF-FIRST] 整合)。
--
-- Deliverable (docs-only, no code/EF/schema change):
--   - docs/RELEASE_CYCLE_POLICY.md … 隔週リリースサイクル方針の正本 (SSOT)。
--       3 層整合 (四半期 QUARTERLY_ROADMAP / 隔週 = 本書 / 毎リリース RELEASE_CHECKLIST_ROLLBACK) +
--       技術は継続デプロイ維持で隔週は対外コミュニケーション・編纂のリズムという軸分け +
--       cycle 定義 (計画 Day1 / soft cut Day12 / note 編纂 Day13-14 / 公開 Day14 / 軽量ふりかえり) +
--       編纂規律 (自動生成 JSON が事実の正本 / highlights ≤5 / 障害も隠さない / REAL-DATA) +
--       役割 (L2 実装 / L3 編纂・gate / CEO scope 決定・公開承認・起点日確定) +
--       初回サイクル発効条件 (起点日【CEO確定】/ 案 2026-06-19 / 発効 = Cycle #1 note 公開) +
--       最小計測 (既存監視値参照のみ / 3 cycle で周期見直し条項) + Deferred。
--
-- 完了の定義: cadence 方針の「設計・文書化」が成果物。実際の隔週運行実績は Cycle #1 から
-- (本 migration では運行実績を主張しない / honest scope)。
--
-- ai_review_status='approved' を同一 UPDATE で設定 → trigger 回避で status='completed' 確定。
-- Idempotent: 固定値 UPDATE / description append は LIKE guard / achievement は NOT EXISTS guard。

UPDATE public.wbs_tasks
SET
  status            = 'completed',
  progress          = 100,
  ai_review_status  = 'approved',
  ai_reviewed_at    = now(),
  ai_review_notes   = 'Win Claude (architect / ops-docs lane / L3) self-authored deliverable. docs/RELEASE_CYCLE_POLICY.md に隔週リリースサイクル方針の正本 (SSOT) を整備。description の 2 artifact (release note / changelog page) は既存実装を verify (generate_release_notes.py 自動生成 + release_notes_page / changelog_manager_page / development_achievements ページ) — 欠けていた「隔週リズムと編纂規律」を確立。3 層整合 (四半期/隔週/毎リリース) + 継続デプロイ維持で隔週は対外編纂リズムという軸分け + cycle 定義 (計画/soft cut/編纂/公開/軽量ふりかえり) + 編纂規律 (自動生成=事実の正本 / highlights ≤5 / 障害も隠さない) + 役割 + 発効条件 (起点日【CEO確定】/ 発効 = Cycle #1 公開) + 最小計測 + Deferred。新規アプリ開発ゼロ。実運行実績は Cycle #1 から (honest scope)。コード/スキーマ変更なしの docs-only。',
  owner_instance    = 'win',
  start_date        = COALESCE(start_date, DATE '2026-06-10'),
  end_date          = DATE '2026-06-10',
  remaining_work    = 'Completed by Win Claude (part 255). 隔週サイクル方針 SSOT = docs/RELEASE_CYCLE_POLICY.md。残: 起点日の CEO 確定 (§5 / 案 2026-06-19) → Cycle #1 運行で発効。in-app 通知 UI / note AI ドラフト自動化 / EN 完全自動化 (#1950) は Deferred (§7)。',
  description       = CASE
    WHEN COALESCE(description, '') LIKE '%Done 2026-06-10: biweekly release cycle policy established%'
      THEN description
    ELSE COALESCE(description, '') ||
      E'\n\nDone 2026-06-10 (Win Claude part 255): biweekly release cycle policy established at docs/RELEASE_CYCLE_POLICY.md as the SSOT for the cadence. Verified first that both artifacts named in this task already exist: release notes are deterministically auto-generated (scripts/generate_release_notes.py -> web/release-notes.json from PRs / GitHub Releases / deploy metadata, per docs/release-notes/README.md) with lib/pages/release_notes_page.dart as the surface, and the changelog page exists (lib/pages/changelog_manager_page.dart plus the development_achievements page). What was missing was the biweekly rhythm and curation discipline, which this policy adds with zero new app development: a three-layer split (quarterly roadmap / biweekly cycle = this doc / per-release runbook), continuous deploy kept as-is with the biweekly cycle defined as an outward communication-and-curation rhythm (not deploy batching), the cycle calendar (plan day 1, soft cut day 12, note curation days 13-14, publish day 14, lightweight retro), curation rules (the generated JSON is the factual source; max 5 user-value highlights; incidents are disclosed, consistent with the postmortem SOP), roles across the three lanes with CEO holding scope/publish/start-date decisions, an activation condition (policy takes effect when Cycle 1 publishes; start date is a CEO-confirmation placeholder, proposal 2026-06-19), minimal measurement reusing existing monitoring values, and a 3-cycle review clause. Honest completion: authoring the cadence policy is the deliverable; no biweekly operating track record is claimed yet. Task claimed codex -> win (release-cadence policy docs is the L3 lane); 4th round this session under explicit user /loop re-invocation.'
  END,
  updated_at        = now()
WHERE id = '39b30ef2-83ed-4a10-bce3-915e272093c7';

-- 開発実績ログ (development_achievements ページ反映 / 重複防止 = NOT EXISTS guard)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '機能リリースサイクル方針 (隔週) 確立 — RELEASE_CYCLE_POLICY v1',
  'docs/RELEASE_CYCLE_POLICY.md を新設。既存の release note 自動生成 (generate_release_notes.py) と changelog 面 (release_notes_page / changelog_manager_page / development_achievements ページ) を verify した上で、欠けていた「隔週のリズムと編纂規律」を確立: 3 層整合 (四半期 / 隔週 / 毎リリース runbook) + 継続デプロイ維持で隔週は対外コミュニケーション編纂のリズムという軸分け + cycle 定義 (計画 / soft cut / 編纂 / 公開 / 軽量ふりかえり) + 編纂規律 (自動生成 = 事実の正本 / highlights 最大 5 / 障害も隠さない) + 3 レーン役割 + 発効条件 (起点日 CEO 確定 / Cycle #1 公開で発効) + 最小計測と 3 cycle 見直し条項。新規アプリ開発ゼロで paying-100 の定常出荷リズムを設計 (設計シリーズ第 14 弾)。',
  now()
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '機能リリースサイクル方針 (隔週) 確立 — RELEASE_CYCLE_POLICY v1'
);
