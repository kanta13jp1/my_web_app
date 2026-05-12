# Commit Message Convention — 12 fleet 共通

> このドキュメントは、自分株式会社 12 fleet (= 10 Claude Code + 2 Codex CLI) が **commit message に instance 識別子を含める** convention を定義する.
>
> **背景**: Win版#132 part 99-101 で `instance_role_audit.py` を導入. 過去 30 日 4526 commits のうち **3074 (= 67.9%)** が `unknown` (= instance 識別不能) と判定された. CLAUDE.md routing matrix の audit 精度が大幅低下する.
>
> **目的**: convention 強化で **unknown を 67.9% → 20% 以下** に削減し、fleet 自進化 loop の audit 精度を向上.

---

## convention

### Format

```
<type>(<scope>): <instance> <Sxx>: <subject>

<body>
```

### 必須要素

1. **`<instance>`**: 識別子 (= 後述 11 種から選択)
2. **`<Sxx>`**: session 番号 (= 例: `S145`, `part 102`)
3. **`<subject>`**: 簡潔な変更サマリ

### Instance 識別子 (= 11 種)

| 識別子 | 対応 instance | 例 |
| --- | --- | --- |
| `Win版#NNN part NN` または `Win#NNN` | Windowsアプリ | `Win版#132 part 102` |
| `VSCode版 SNN` または `VSCode SNN` | VSCode版 | `VSCode S22` |
| `PS#1 SNN` 〜 `PS#6 SNN` | PowerShell #1-6 | `PS#1 S22` / `PS#6 S145` |
| `Codex#1` または `codex/codex1-` | Codex#1 | `Codex#1: ...` / branch `codex/codex1-foo` |
| `Codex#2` または `codex/codex2-` | Codex#2 | `Codex#2: ...` / branch `codex/codex2-deploy-fix` |

### 例 ✅

```
chore(seed): PS#1 S22 CI triage 5件クローズ
feat(competitors): PS#4 S666 競合9社追加 1816→1825社
fix(deploy): Win版#132 part 102 milestone FK fix
feat(automation): VSCode S22 theme selector page 実装
fix: Codex#2 deploy-prod WBS milestone fix (PR #1462)
```

### 例 ❌ (= unknown 扱いされる)

```
fix bug
update docs
WIP
auto: ticket-cache 更新     ← bot は除外対象 / 別 convention 適用
Merge pull request #1234    ← Merge commit は親 commit の identifier 継承
```

---

## bot commit (= 例外)

GitHub Actions / 自動 cron / consolidate-memory 等の bot commit は **`bot[<name>]`** を prefix に付ける:

```
bot[ai-tool-changelog-watch]: monthly fetch 2026-04
bot[instance-role-audit]: monthly audit 2026-04
bot[cs-check]: ticket-cache 更新 2026-04-30-22:00
```

= audit script で `bot[*]` を `unknown` から除外して **真の人手 commit only** 集計可能に.

---

## auto-correction (= 違反検出時の動作)

### Phase 1 (= 警告のみ / 本 part 102 introduce):

`scripts/instance_role_audit.py` 拡張: monthly audit で `unknown` 比率 > 30% の場合に GitHub Issue 自動起票 (label: `commit-convention-warning`).

### Phase 2 (= 将来 / pre-commit hook):

`.claude/hooks/pre-commit-instance-check.sh`:
- commit message を pattern check
- 違反時 warning 表示 + 確認 prompt
- 強制ではない (= 緊急 hotfix の阻害を回避)

### Phase 3 (= 将来 / GHA enforce):

CI で commit message convention check.
- main branch に push される PR で convention 違反があれば warning コメント
- 強制 block ではなく fleet 教育を優先

---

## migration path

既存 commit (= 過去 1 年分) は再書き換えしない. 本 doc 公開以降の commit から徐々に convention 浸透.

期待:
- 1 ヶ月後: unknown 比率 67.9% → 50% 以下
- 3 ヶ月後: 30% 以下
- 6 ヶ月後: 20% 以下 (= 目標 = bot commit と Merge commit のみ)

---

## inject-rules.txt 追加候補

```
[COMMIT-31] (Win版#132 part 102 · 2026-04-30 追加) commit message に instance 識別子必須
  format: <type>(<scope>): <instance> <Sxx>: <subject>
  instance 識別子 11 種 (= Win版#NNN / VSCode SNN / PS#N SNN / Codex#N)
  bot commit は bot[<name>] prefix で除外
  audit: scripts/instance_role_audit.py monthly cron で unknown 比率監視
  詳細: docs/COMMIT_MESSAGE_CONVENTION.md
```

---

## なぜこれが大事か

### AI_FLEET_SYNERGY #1 (Strict Instance Routing) dogfood

12 fleet を 1 organism として運用するためには **「誰が何をやったか」の追跡可能性** が前提.
unknown が 67.9% では fleet drift を audit できず、CLAUDE.md routing matrix の改善 cycle が成立しない.

### INDIE_DEV_VELOCITY #2 (Instruction Quality Audit) dogfood

commit message = AI に対する **「過去判断の説明書」**. instance 識別子なし = 過去の commit を AI が読んだ時に「誰がどの context でやったか」が不明 → 同じ判断を再現できない.

### SECOND_BRAIN #3 (Master Index + Daily Notes) dogfood

memory/log.md でセッション横断の動きを追跡している. commit log もその一部. instance 識別子は **Daily Notes 検索の primary key** に該当.

---

*Win版#132 part 102 / 2026-04-30 / commit message convention 文書化 / unknown 67.9% 削減目標 / 12 fleet 共通*
