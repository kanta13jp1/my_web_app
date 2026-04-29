-- Win版#132 part 89 / 2026-04-29: 期限切迫 task 進捗 一括 update 第 2 弾
--
-- User 要望 (再):「期限が超過しているタスクや、期限がせまっているタスクがたくさんあります。進めて行ってください」
-- = part 88 で漏れた追加期限切迫 task を実状況に合わせて update.

-- ==============================================
-- 1. 既に closed / 100% completed (= GitHub Issue is closed; WBS mirrored)
-- ==============================================

-- #1051 Deploy to Production CI → 既に closed (screenshot で「GitHub Issue is closed; WBS mirrored as completed.」)
UPDATE wbs_tasks
SET progress = 100,
    status = 'completed',
    remaining_work = NULL,
    recovery_plan = 'Issue auto-closed via deploy success. issue-to-wbs.yml 経由で WBS auto-completed.'
WHERE github_issue_number = 1051;

-- ==============================================
-- 2. CI 失敗 task 第 2 弾: part 88 cross-instance-pr (PS#1) に統合
-- ==============================================

-- #1020 codex1-fix-migration-110000-collision CI failure (GHA / 04/29)
-- #1026 Deploy to Production (GHA / 04/30)
UPDATE wbs_tasks
SET progress = 20,
    status = 'in_progress',
    remaining_work = 'Win版#132 part 89 で CI 失敗系 batch triage cross-instance-pr 第 2 弾に追加. PS#1 (Rule17 WF health) audit 対象.',
    recovery_plan = 'docs/cross-instance-prs/20260429_ci_failure_batch_triage_ps1.md (= part 88 起票) に追加. PS#1 が個別 fix 配分.'
WHERE github_issue_number IN (1020, 1026);

-- ==============================================
-- 3. [追加要望] CX 系: PLATFORM_EVOLUTION 軸対応待ち
-- ==============================================

-- #768 Gemini 整理術を応用した AI 生活リセットプランナー (CX / 04/28 / 0%)
-- → AI_VIDEO 軸 / IMBUE 軸の応用 / Phase 2 候補
UPDATE wbs_tasks
SET progress = 10,
    status = 'pending',
    remaining_work = 'Phase 2 候補 (= 2027-Q1 想定). IMBUE pattern + AI_VIDEO #1 Dynamic Avatar の応用. 直近の優先度低 (= core 機能ではなく拡張機能).',
    recovery_plan = '2027-Q1 Phase 2 fleet 拡大時に検討. 現時点では PLATFORM_EVOLUTION 進捗 (= part 74 / Codex#2 受領待ち) 優先.'
WHERE github_issue_number = 768;

-- #772 Writer AI Studio型 ナレッジグラフ/RAG 検索アシスタント (CX / 04/28 / 0%)
-- → SECOND_BRAIN #7 Hybrid Search via MCP の応用候補
UPDATE wbs_tasks
SET progress = 10,
    status = 'pending',
    remaining_work = 'SECOND_BRAIN #7 (Hybrid Search via MCP / part 70 起票) で memory-search-hub EF 完成後に application 開発. 現時点で Codex#2 push 待ち.',
    recovery_plan = 'docs/cross-instance-prs/20260429_memory_search_hub_ef_codex2.md 完成 → 本 Issue で UI 実装 (VSCode territory).'
WHERE github_issue_number = 772;

-- #773 全 AI 機能共通の ガードレール・PII 監査レイヤー (CX / 04/28 / 0%)
-- → AI_CHARACTER + MCP_AUTH の応用 / 設計負債解消
UPDATE wbs_tasks
SET progress = 10,
    status = 'pending',
    remaining_work = 'AI_CHARACTER 8 原則 + MCP_AUTH 10 原則の組合せ実装. 既存 mcp_auth_guard.ts (= part 49 skeleton) を拡張. ガードレール EF action として hub 化候補.',
    recovery_plan = '設計詳細化 → cross-instance-pr 起票 (= 後続 part). PLATFORM_EVOLUTION #6 (Budget Control) と並列.'
WHERE github_issue_number = 773;

-- #774 PDF・非定型テキストからの構造化データ抽出パイプライン (CX / 04/28 / 0%)
-- → AI_VIDEO + AI_DEV 応用 / 動画パイプラインと類似 pattern
UPDATE wbs_tasks
SET progress = 10,
    status = 'pending',
    remaining_work = 'scripts/video/ パイプライン (= notebooklm-video-pipeline.yml) と同型 pattern. PDF 変換 → text 抽出 → 構造化 LLM call → schema 出力. Phase 2 候補.',
    recovery_plan = '2027-Q1 Phase 2 で実装. 現時点では AI_VIDEO 軸 dogfood (= part 64-65) が優先.'
WHERE github_issue_number = 774;

-- ==============================================
-- 4. その他状況確認
-- ==============================================

-- BYPASS_RULES secret 設定 (P1→CX / 04/30 / 90%) → 既に高進捗 / 完了間近
-- = User territory に近い (= secret 設定はユーザー操作必要)
-- 進捗 90% のまま維持 (= 残 10% は最終確認のみ).

-- ==============================================
-- 5. development_achievements 追加
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 89: 期限切迫 task 進捗 一括 update 第 2 弾',
  'part 88 で漏れた追加 task 7 件 (#1051 closed / #1020 #1026 CI failure / #768 #772 #773 #774 [追加要望] CX 系) を実状況に合わせて update. CI 失敗系 cross-instance-pr 第 2 弾 PS#1 へ追加委譲.',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
