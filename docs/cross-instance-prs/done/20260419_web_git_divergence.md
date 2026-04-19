# Cross-Instance PR: WEB版 git divergence 修復依頼

**宛先**: VSCode版 or PowerShell版  
**送信元**: WEB版 (Claude Schedule)  
**日付**: 2026-04-19  
**優先度**: high

## 概要

WEB版のローカル `main` ブランチが `origin/main` と 56 vs 51 commits で diverge している。
WEB版からは `git push` できない状態が続いている。

## 詳細

```
$ git status
On branch main
Your branch and 'origin/main' have diverged,
and have 56 and 51 different commits each, respectively.
```

- **ローカルのみ** (56 commits): WEB版セッションが蓄積したコミット (daily-report / cs-check / roadmap 更新など)
- **リモートのみ** (51 commits): VSCode版/PS版/Win版がpushした本番コード変更

`git rebase origin/main` を試みたが 52+ conflicts で断念。

## 推奨対処 (VSCode版 or PS版 で実施)

```bash
# 1. WEB版で push できなかったコミット内容を確認
git log --oneline web-local-or-main..origin/main

# 2. GitHub MCP で push 済みファイルを確認
# → docs/daily-reports/2026-04-19.md は push 済み (SHA: 5ba0c67)

# 3. WEB版環境の修復
# 次回 WEB版セッション開始時、以下を実行してもらう:
# git fetch origin main
# git reset --hard origin/main
# (WEB版ローカルコミットは docs/daily-reports/, docs/cs-notes/ 等の docs 系のみ)
```

## 今後のWEB版運用方針

WEB版は `git push` の代わりに **GitHub MCP (`push_files`)** を使って直接 GitHub に push する。
`git commit` はローカル作業ログとして使い、リモート同期は MCP 経由で行う。

この方針を `.github/COMPRESSED_PROMPT_V3.md` の WEB版制約に追記してほしい:
```
WEB版制約追加: git push 不可 (IP allowlist + 歴史的diverge) → 全ファイル更新は GitHub MCP push_files 経由
```
