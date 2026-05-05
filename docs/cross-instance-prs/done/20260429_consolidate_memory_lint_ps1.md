# Cross-Instance PR: consolidate-memory skill に --lint flag 追加

**作成**: Win版#132 part 69 / 2026-04-29
**FROM**: Win版 (SECOND_BRAIN 軸起案者 / docs territory)
**TO**: PS版#1 (consolidate-memory skill 専任 / Rule17 WF health territory)
**優先度**: HIGH (MEMORY.md 32.4KB 警告解消の鍵 = 即着手すべき)
**期限**: 2026-05-06 (1 週間)
**親軸**: docs/SECOND_BRAIN_PRINCIPLES.md 原則 #4 (定期 Lint + 孤児統合)

---

## 背景

Win版#132 part 68 で `docs/SECOND_BRAIN_PRINCIPLES.md` (10 番目軸 / PKM 設計) を確立.
Part 69 で原則 #3 (Daily Log) を Win territory で実装 (= `~/.claude/projects/.../memory/log.md` 新規作成).

残り急務 = 原則 #4 (定期 Lint + 孤児統合). 既存 PS#1 専任 `consolidate-memory` skill を **拡張** することで実装可能 = WORKDIR-ISOLATION 整合.

**MEMORY.md 32.4KB 警告** (limit 24.4KB) が顕在化しており、本 lint 機能が **MEMORY.md inflation 解消の鍵**.

## Win版 routing 判断 (5 質問 + WORKDIR-ISOLATION)

| Q | 答え | 補足 |
| --- | --- | --- |
| Q1 設計判断 / trade-off? | YES | lint 検出ルールの設計 (孤児定義 / 重複閾値 / 矛盾検出ヒューリスティック) |
| Q2 cross-instance 調整? | NO | PS#1 単方向 |
| Q3 軸 docs 更新? | △ | 完了時 docs/SECOND_BRAIN_PRINCIPLES.md 実装履歴に行追加 (#4 → 3.5/7) |
| Q4 docs に残す判断? | △ | lint ルール設計の根拠は記録価値あり |
| Q5 NotebookLM 連携? | NO |

→ Q1 YES + WORKDIR-ISOLATION (consolidate-memory skill = PS#1 territory) = **PS#1 territory 確定**.

## 期待する実装

### 1. `consolidate-memory --lint` flag 新規

既存 skill `~/.claude/skills/consolidate-memory/SKILL.md` を拡張. `--lint` を渡すと **merge は実行せず** lint レポートのみ生成.

### 2. Lint 検出ルール (3 種)

#### A) 孤児ノート (Orphan Notes)

定義: ``file_name`` 形式で **他 file から参照ゼロ** の memory file.

```bash
# pseudo
for file in memory/*.md:
    if grep -lr "\\[\\[$(basename $file .md)\\]\\]" memory/ | wc -l == 0:
        report_orphan(file)
```

**例外**: `MEMORY.md`, `log.md`, `feedback_correction_*.md` (= 索引 / append-only / 警告)

#### B) 重複候補 (Duplicate Candidates)

定義: 同 prefix + 90 日以内 + 内容類似度 > 0.7 (= simple shingling).

```bash
# pseudo
group_by_prefix = {}  # e.g. "project_20260428_win132_part" → [part58, part59, part60]
for prefix, files in group_by_prefix:
    if len(files) > 5 and within_90_days(files):
        compute_pairwise_similarity(files)
        if any(sim > 0.7):
            report_duplicate(files)
```

**目的**: 同主題で別 part として保存された file 群を統合候補としてサジェスト.

#### C) 矛盾検出 (Contradiction Detection)

定義: 同概念 (= 同 keyword multiple files) で対立する記述.

```bash
# pseudo (LLM 必要)
keywords = extract_top_keywords(memory/*.md)
for kw in keywords:
    files = grep -l $kw memory/
    if len(files) >= 3:
        ask_llm("以下 3 file に矛盾がないか判定: ...")
```

**例**: `project_*part51.md` と `feedback_correction_*concurrency*.md` で「cancel-in-progress: false の挙動」記述が異なる場合 → 矛盾候補.

### 3. レポート出力

`~/.claude/projects/.../memory/lint_report_YYYY_MM.md` 新規:

```markdown
# memory/ Lint Report YYYY-MM (PS#1 consolidate-memory --lint)

## 集計
- Total files: 105
- Orphan: 12 (= 11.4%)
- Duplicate candidates: 3 group / 14 files
- Contradictions: 2 candidates

## 孤児ノート (12 件)
- `file1` → 関連既存 file 候補: ...
- `file2` → 関連既存 file 候補: ...

## 重複候補 (3 group)
- group A: [[a]], [[b]], [[c]] (similarity 0.82) → 統合提案
- ...

## 矛盾候補 (2 件)
- 概念 X: `file_p` と `file_q` で対立 → 検証推奨
```

### 4. GitHub Issue 自動作成 (オプション)

`--lint --issue` flag で違反を Issue 化:
- 孤児 12+ なら Issue: 「memory/ 孤児ノート 12 件 (consolidate-memory --lint レポート)」
- 重複 group 3+ なら Issue: 「memory/ 重複候補 14 file (統合候補あり)」
- COLLAB_AI Verifier-Generator + OPS-28 改善トリガー連携.

### 5. 月次自動実行

PS#1 既存月次 routine に統合: 月初 1 日に `--lint --issue` 実行 → Issue 化 → Win版が翌日確認.

## 完了条件

- [ ] `~/.claude/skills/consolidate-memory/SKILL.md` に `--lint` flag 仕様追記
- [ ] lint ロジック実装 (orphan + duplicate + contradiction の 3 検出器)
- [ ] `lint_report_YYYY_MM.md` 自動生成 (1 回テスト実行で確認)
- [ ] `--issue` flag で GitHub Issue 自動作成 (任意)
- [ ] `docs/SECOND_BRAIN_PRINCIPLES.md` 実装履歴に行追加 (#4 完成 → baseline 2.5 → 3.5/7)
- [ ] 本 cross-instance-pr を `done/` 移動

## 備考

### memory/ の物理的場所

memory/ は git repo 内ではなく `~/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/` (= per-Windows-user local). PS#1 が同 Windows user で起動している前提なら同じディレクトリを参照可.

異 Windows user で起動している場合は **PS#1 instance は自分の memory/ を lint** (= 機能制限) → 月次 lint レポートを git commit して共有する追加実装が必要.

### #1 階層型分離との整合

lint で発見された孤児/重複/矛盾は **Layer 2 (evolving Wiki)** の問題. Layer 1 (immutable source = session_summary) と Layer 3 (schema = CLAUDE.md+inject-rules) は lint 対象外.

## OPS-28 charter §6 受領 lane 履歴 (2026-04-29 1 件目)

| part | from | to | 内容 | 性質 |
| --- | --- | --- | --- | --- |
| 47 | Win → PS#1 | PS#1 | Migration timestamp collision detector | 改善トリガー |
| 51 | Win → PS#1 | PS#1 | deploy-prod concurrency truth | 改善トリガー |
| 56 | Win → PS#1 | PS#1 | migration time-relative CHECK detector | 改善トリガー |
| **69 (本)** | **Win → PS#1** | **PS#1** | **consolidate-memory --lint** | **SECOND_BRAIN dogfood (= 軸起案者が同日中に PS lane に渡す)** |

= 本 PR は SECOND_BRAIN 軸を「**起案 → 自分で #3 実装 → PS#1 に #4 委譲**」の co-implementation pattern 第 2 例.
(第 1 例 = AI_VIDEO #5 / Win → VSCode UI バッジ / part 65)

---

*Win版#132 part 69 / 2026-04-29 起票 / SECOND_BRAIN 原則 #4 (定期 Lint + 孤児統合) PS#1 territory 委譲 / MEMORY.md 32.4KB 警告解消の鍵 / co-implementation pattern 第 2 例*
