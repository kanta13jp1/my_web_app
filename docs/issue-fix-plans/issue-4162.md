# Issue Fix Plan #4162

- Issue: [[追加要望][P2][NotebookLM] f9a8ee17:3 Flutter Webルーティング最適化のためのカスタム404ページの導入](https://github.com/kanta13jp1/my_web_app/issues/4162)
- Labels: enhancement,priority:medium,automation,追加要望,wbs,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/30187252261

## Goal

[追加要望][P2][NotebookLM] f9a8ee17:3 Flutter Webルーティング最適化のためのカスタム404ページの導入

## Current Context

```text
<!-- notebooklm-requirement:f9a8ee17-940b-4c7e-8e86-7df70da59e76:3 -->
<!-- notebooklm-requirement-hash:2273af10c6cecc2a -->

## Source Notebook

- Notebook ID: `f9a8ee17-940b-4c7e-8e86-7df70da59e76`
- Notebook title: The Comprehensive Guide to GitHub Pages Documentation
- Ownership: Owner
- Created: `2026-05-26T11:32:26`
- Requirement slot: `3/3`
- Suggested priority: `P2`
- Extracted at: `2026-07-18T11:12:05Z`

## Additional Request

Flutter Webルーティング最適化のためのカスタム404ページの導入

## Rationale

SPA（シングルページアプリケーション）であるFlutter Web特有のルーティング問題を解決するため。下層ページへの直接アクセスやリロード時 に発生する404エラーを捕捉し、ユーザーの離脱を防ぐ。

## Acceptance Criteria

- [ ] プロジェクトの公開ルートディレクトリに、専用の `404.html` ファイルが配置されていること
- [ ] 存在しないURLパスやアプリの内部パスに直接アクセスした際、カスタム404ペー ジが正しくレンダリングされること
- [ ] カスタム404ページからFlutterのメインアプリケーション（index.html）へ適切 にパスを保持したままリダイレクトされること

## Implementation Notes

Flutterのビルドスクリプトを拡張し、ビルド完了時に `build/web` フォルダ内へ `404.html` を自動生成するステップを追加する。内部でJavaScriptによるURLクエリ変換を実装する とルーティング復元が容易になる。

## Verification / Routing

- [ ] NotebookLM 抽出結果と既存 repo 文脈の整合性を確認する
- [ ] 既存 GitHub Issues / WBS と重複しないことを確認する
- [ ] Claude Code #1 + Codex #1 の top-level 2インスタンス制に沿って担当を決める
- [ ] 完了時は GitHub Issues WBS Sync または `wbs-progress-update.yml` で進捗を同期する

---


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
