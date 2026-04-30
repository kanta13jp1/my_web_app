-- WBS 期限切迫 task 進捗 update + AI_FLEET_SYNERGY 軸関連 task 反映
--
-- Win版#132 part 98 / 2026-04-30 / User 要望「期限超過 / 期限せまっている task 進めて」
--
-- 本 migration の目的:
-- 1. AI 大学拡張系 task の進捗反映 (= part 93-97 で 5 段階 cascade 完了)
-- 2. AI_FLEET_SYNERGY 軸関連 task (= changelog watch / instance routing audit) の追加 + 進捗反映
-- 3. 期限超過 / 切迫 task の audit responsibility pattern 第 3 例 (= part 88 第 1 / part 89 第 2 / 本 第 3)

-- ==============================================
-- 1. AI 大学拡張 (= part 93-97 完了反映)
-- ==============================================

-- AI 大学関連 GitHub Issue (= 該当する Issue があれば更新 / 想定 issue_number)
-- 実 issue_number は GitHub 側で確認が必要 / 本 migration は scaffolding

-- ==============================================
-- 2. AI_FLEET_SYNERGY 軸 + Changelog Watch infrastructure (= 新規 task 追加)
-- ==============================================

-- 既存の wbs_tasks へ AI_FLEET_SYNERGY 関連 task を 1 件追加
-- (= 自動化 infrastructure として明示記録)
INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, milestone_code, description)
VALUES (
  '[AI_FLEET_SYNERGY #3] Claude Code + Codex CLI 月次 changelog watch cron',
  'CX',
  'codex',
  'codex',
  'high',
  'pending',
  10,
  'PHASE-1',
  'AI_FLEET_SYNERGY 12 番目軸 #3 dogfood. monthly cron で Claude Code + Codex CLI changelog を fetch / Claude API で要約 / Issue 自動起票 / 重要度 H なら cross-instance-pr 自動 draft. fleet 自身が fleet 自身を進化させる infrastructure. cross-instance-pr docs/cross-instance-prs/20260430_ai_tool_changelog_watch_codex2.md 起票済.'
)
ON CONFLICT DO NOTHING;

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, milestone_code, description)
VALUES (
  '[AI_FLEET_SYNERGY #1] インスタンス担当分担 monthly audit cron',
  'CX',
  'codex',
  'codex',
  'medium',
  'pending',
  0,
  'PHASE-1',
  'AI_FLEET_SYNERGY 原則 #1 dogfood. 過去 30 日の commit を instance 別に集計 / 想定役割 (CLAUDE.md routing matrix) と乖離があれば警告. monthly cron + GitHub Issue 化.'
)
ON CONFLICT DO NOTHING;

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, milestone_code, description)
VALUES (
  '[AI_FLEET_SYNERGY #4] CLAUDE.md / inject-rules.txt 行数 monthly 監視 cron',
  'CX',
  'codex',
  'codex',
  'medium',
  'pending',
  0,
  'PHASE-1',
  'AI_FLEET_SYNERGY 原則 #4 dogfood. CLAUDE.md / inject-rules.txt の行数を monthly 監視 (= 200 / 500 行超過で警告). pointer-based config 維持で fleet drift 防止.'
)
ON CONFLICT DO NOTHING;

-- ==============================================
-- 3. AI 大学 学部/学科 hierarchy (= part 93-97) 反映
-- ==============================================

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, milestone_code, description)
VALUES (
  'AI 大学 学部/学科 hierarchy 設計 + 10 学部 53 学科 seed (Phase 1 / Win territory)',
  'CX',
  'win',
  'win',
  'high',
  'completed',
  100,
  'PHASE-1',
  'part 93-97 で 10 学部 53 学科を 24h 5 段階 cascade で完成. ハードウェア(2)/OS(5)/AI(10)/モバイル(15)/クラウド(20)/開発ツール(30)/SWE(35)/データ(40)/資格(45)/学術(50) の 10 layer 順序教育設計.'
)
ON CONFLICT DO NOTHING;

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, milestone_code, description)
VALUES (
  'AI 大学 provider mapping + 学部別 seed (Phase 2-4.8 / PS#3 territory)',
  'CX',
  'ps3',
  'ps3',
  'high',
  'in_progress',
  10,
  'PHASE-1',
  'part 93-97 cross-instance-pr docs/cross-instance-prs/20260430_ai_university_faculty_department_seed_ps3.md で PS#3 へ phase 2-4.8 委譲済. 既存 380+ provider mapping + クラウド/SWE/OS/モバイル/ハードウェア/資格 各学部に provider seed = 累計 580-630+ provider.'
)
ON CONFLICT DO NOTHING;

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, milestone_code, description)
VALUES (
  'AI 大学 4 階層 drill-down UI (= 学部 → 学科 → provider → content / VSCode territory)',
  'CX',
  'vscode',
  'vscode',
  'high',
  'pending',
  0,
  'PHASE-1',
  'part 93 cross-instance-pr docs/cross-instance-prs/20260430_ai_university_faculty_ui_vscode.md で VSCode へ委譲済. 学部選択 + 学科選択 + breadcrumb + integration test (VIBE #5 dogfood).'
)
ON CONFLICT DO NOTHING;

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, milestone_code, description)
VALUES (
  'AI 大学 ai-hub に 学部/学科 4 actions 追加 (= Codex#2 territory)',
  'CX',
  'codex',
  'codex',
  'high',
  'pending',
  0,
  'PHASE-1',
  'part 93 cross-instance-pr docs/cross-instance-prs/20260430_ai_university_faculty_actions_codex2.md で Codex#2 へ委譲済. university.faculty_list / department_list / provider_by_department / content_by_faculty 4 actions. EF カウント影響なし.'
)
ON CONFLICT DO NOTHING;

-- ==============================================
-- 4. development_achievements 追加
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 98: AI_FLEET_SYNERGY 12 番目軸確立 + WBS audit 第 3 例',
  'NotebookLM `bc58b50b` (Codex vs Claude Code: Ultimate AI Development Synergy) 蒸留 → docs/AI_FLEET_SYNERGY_PLAYBOOK.md (7 原則) + Rule [SYNERGY-30] inject-rules.txt + CLAUDE.md table 追加. cross-instance-pr docs/cross-instance-prs/20260430_ai_tool_changelog_watch_codex2.md 起票 (= Codex#2 へ Claude Code + Codex CLI changelog watch cron 委譲). VIBE_CODING (個別責任) ↔ AI_FLEET_SYNERGY (集合運用) のメタ層ペア構造完成. WBS 期限切迫 task audit 第 3 例 (= part 88 第 1 / 89 第 2 / 本 第 3). 5 日累計 12 軸 89+ 原則 / 28 part 連続 dogfood.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
