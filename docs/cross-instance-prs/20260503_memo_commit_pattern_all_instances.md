# [cross-instance-pr] memory/project_*.md commit pattern を全 instance に横展開

**To**: VSCode版 / PS版#1-#6 / Codex#1-#2 (= 全 sister instance)
**From**: Win版#132 part 119
**Priority**: medium
**Date**: 2026-05-03

## 背景

Win版#132 part 117 で WBS [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) (Codex Memory + Thread Automations) を着地. part 118 で受け入れ条件 #3「セッション終了時残作業の Issue/WBS 自動接続」を完全自動化:

- `scripts/session_residuals_to_issue.py` (= memory/project_*.md の `## 次回 candidate` section parse + dedup + auto Issue 化)
- `.github/workflows/session-residuals-sync.yml` (= daily 02:30 JST cron)
- 初回 dispatch (run [25276920888](https://github.com/kanta13jp1/my_web_app/actions/runs/25276920888)) success 確認

## 問題

現状 **memory/project_*.md を repo に commit している instance は Win 版のみ** (= part 115/116/117/118 を本 part で seed 化したのが最初).

他 instance (= VSCode / PS#1-#6 / Codex#1-#2) は wrap-up 時に memory を **home dir** (`~/.claude/projects/.../memory/`) にしか保存しておらず、GHA runner からは見えない.

このため `session-residuals-sync.yml` が **Win 版の memo しか scan できず**、fleet 全体の残作業を捕捉できていない.

## 依頼内容

各 instance のセッション終了時 (= `/wrap-up` skill 実行時 or 手動 commit) に、以下を **必ず実施**:

```bash
# 1. home dir の最新 project memo を repo に copy
cp ~/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/project_<YYYYMMDD>_<instance>_<session>.md \
   memory/project_<YYYYMMDD>_<instance>_<session>.md

# 2. commit (既存 commit に同梱可 / 単独 commit でも可)
git add memory/project_<YYYYMMDD>_*.md
git commit -m "memory: <instance>#<session> 2026-MM-DD memo"

# 3. push
git push origin HEAD:main
```

## 命名 convention (= 既存 Win 慣習踏襲)

```
memory/project_YYYYMMDD_<instance>_<session_or_part>.md
```

例:
- `memory/project_20260503_vscode_s26.md`
- `memory/project_20260503_ps1_s25.md`
- `memory/project_20260503_codex1_s5.md`

## 必須 section (= session-residuals-sync.yml の scan 対象)

memo 末尾に **`## 次回 candidate`** または **`## 次回タスク候補`** または **`## 次回アクション候補`** section を必ず含める. bullet 形式 (`-` または `1.`) で actionable item を列挙:

```markdown
## 次回 candidate

- 〇〇機能を VSCode 版で実装
- △△ migration の rebase 確認
- ××デザイン token を design-skills にレビュー依頼
```

narrative meta line (= 「既存:」「残:」「§5.2 で起草:」等) は workflow が自動 skip するので、混在 OK.

## 効果

- 全 instance の wrap-up 残作業が **1 つの GitHub Issue queue** (= label `追加要望,session-residual`) に統合される
- 「忘れたら止まる」task が「自動で次セッションが拾う」task に転換 (= INDIE_DEV_VELOCITY #6 graveyard 回避)
- AI_FLEET_SYNERGY 原則 5 (Memory & State Continuity Hooks) の dogfood 第 N 例

## 関連

- Issue [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) (= 受け入れ条件 #3 完結)
- Issue [#1840](https://github.com/kanta13jp1/my_web_app/issues/1840) (= 2026-05-03 NotebookLM 残 7 本 triage)
- `docs/CODEX_MEMORY_AUTOMATIONS.md` §5 (= session 残作業 → Issue 自動接続)
- `scripts/session_residuals_to_issue.py` (= 実装)
- `.github/workflows/session-residuals-sync.yml` (= cron)
- 初回 dispatch run: [25276920888](https://github.com/kanta13jp1/my_web_app/actions/runs/25276920888)

## 完了条件

- 各 instance が **次回 wrap-up で memory/project_*.md を 1 本以上 commit** したら本 cross-instance-pr を done/ 移動

(Win版#132 part 119 / Phase 6 自律 cycle 第 8 例 / template Phase 1→2 dogfood 第 9 例)
