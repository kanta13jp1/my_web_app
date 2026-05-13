# Issue Fix Plan #1564

- Issue: [[追加要望][P1] Claude Code PreCompact/StatusLine/SessionStart/Setupによる10インスタンス記憶保全](https://github.com/kanta13jp1/my_web_app/issues/1564)
- Labels: enhancement,priority:high,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25772174158

## Goal

[追加要望][P1] Claude Code PreCompact/StatusLine/SessionStart/Setupによる10インスタンス記憶保全

## Current Context

```text
## 背景
NotebookLM方針では複数Codex/Claude Codeインスタンスの役割分担と引き継ぎ品質が重要。長時間セッションやcontext compact後に、担当・branch・dirty state・未完了WBSが失われるリスクがある。

## 追加要望
- Claude Code PreCompact Hook相当で、branch/worktree/担当タスク/未完了チェック/次アクションを自動保存する。
- StatusLine相当で、現在の担当インスタンス、対象Issue、ブランチ、未push変更、次の品質ゲートを常時表示できるようにする。
- Setup / SessionStart Hook相当で、セッション開始時に `codex_session_check.py`、WBS優先順位、AI Tool Watch結果、前回の未完了テストを自動復元する。
- `--init` / `--maintenance` 相当のSetup Hook運用で、新規参画時の初期環境構築、定期保守、依存チェック、ローカル設定修復を標準化する。
- `scripts/codex_session_check.py` の出力と連動し、セッション開始時に復元しやすい形式へ整える。

## 受け入れ条件
- context compact後も、担当・WBS優先順位・変更範囲・未実行テストが1分以内に復元できる。
- 10インスタンス並行時に branch/worktree の取り違えを検知できる。
- セッション開始時に壊れた前回状態、behind/ahead、dirty path、未push、未完了品質ゲートを検出できる。
- 新規セットアップと定期メンテナンスで実行すべき決定論的コマンドが分離されている。
- 保存先と秘匿情報の取り扱いが明文化されている。

## 担当案
- Claude Code: Hook/StatusLine/Setup設計
- Codex #2: 自動保存ワークフロー
- Codex #3: PowerShell環境での検証とAGENTS反映

NotebookLM list反映: `Claude Code Masterclass` / `Codex vs Claude Code` の SessionStart・Setup・StatusLine・PreCompact 運用を追記。

Created by Codex #3 on 2026-05-02 JST.

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
