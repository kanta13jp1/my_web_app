# Issue Fix Plan #1962

- Issue: [[追加要望][P1][VSCode版] 開発環境同時不具合 — Flutter engine version + Deno LSP EPIPE + 1K phantom problems](https://github.com/kanta13jp1/my_web_app/issues/1962)
- Labels: bug,workflow-failure,priority:high,vscode-instance
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25587405284

## Goal

[追加要望][P1][VSCode版] 開発環境同時不具合 — Flutter engine version + Deno LSP EPIPE + 1K phantom problems

## Current Context

```text
User screenshot 2026-05-04 / VS Code window で 3 系統同時発生:

### 1. Flutter Initialization 失敗
`'System.Net.ServicePointManager' (CP932 garbled bytes...) Error: Unable to determine engine version... exit code 1`
- 文字化け = Windows CP932 出力 encoding 問題
- Flutter SDK / FVM が engine version 取得失敗

### 2. Deno Language Server EPIPE crash
`Connection to server got closed. Server will not be restarted. write EPIPE Shutting down server`
- Deno 2.7.12 / 自動再起動も無効化
- EF (.ts) の language support 完全停止

### 3. SCOREBOARD_2026-04-28.md で 1K problems
- 109 行の valid markdown で 1000+ phantom errors
- LSP cascade 障害由来と推測

## 関連

- branch: `codex/codex1-blog-news-complete` / PR #1949
- 既存類似: #1626 (Codex #5 Windows Dart/Flutter プロセス分離)

## 推奨対応

### A. Deno LSP 再起動
1. Cmd Palette → `Deno: Restart Language Server`
2. NG → VS Code 再起動 → extension reinstall
3. 根本: Deno extension version pin / downgrade (2.7.12 EPIPE バグ可能性)

### B. Flutter 環境
1. `flutter doctor -v` で engine version 確認
2. 文字化け → `chcp 65001` (UTF-8) を VS Code terminal
3. 永続化: PS profile に `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
4. `flutter clean && flutter pub get` で再構築

### C. 1K problems
- A + B 解消後 phantom 消える可能性大
- 残れば `markdownlint` で実 lint 確認

## 担当
- **VSCode版** (= 自環境)

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
