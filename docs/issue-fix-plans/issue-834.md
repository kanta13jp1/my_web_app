# Issue Fix Plan #834

- Issue: [[追加要望] AI生成機能の最小E2E品質ゲート](https://github.com/kanta13jp1/my_web_app/issues/834)
- Labels: 
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26009197096

## Goal

[追加要望] AI生成機能の最小E2E品質ゲート

## Current Context

```text
## 背景

NotebookLM `ddde5a4b-ce1a-405d-8291-a334a9371454` の要点では、AIが書いた実装詳細をすべて人間が追い続けるのではなく、入出力・ユーザー体験・失敗時挙動を検証する抽象化されたテスト層を整えることが重要とされている。

本プロジェクトには `playwright.config.ts`、Flutter widget/service tests、Supabase Edge Functions があり、AI生成機能の増加に対して「最低限ここを通せば壊れていない」と言えるゲートが必要。

## 追加要望

AIが実装・修正した機能に対して、正常系とエラー系を最小限確認するE2E/統合品質ゲートを追加する。

## 実装スコープ案

- 重要導線を3〜5本に絞ったスモークE2Eセットを定義
- 対象候補: ホーム表示、ノート作成/検索、AIアシスタント入口、WBS/user task報告、公開メモまたはAI大学表示
- AI実装Issueに `E2E対象/対象外理由` を書けるテンプレートを追加
- GitHub Actions上で軽量に走る構成を優先し、重いケースは手動ジョブに逃がす

## 受け入れ条件

- [ ] AI生成機能向けの最小E2E対象リストがドキュメント化されている
- [ ] 主要導線の正常系と代表的なエラー系が少なくとも1本ずつ自動検証される
- [ ] GitHub Actionsまたはローカルコマンドで実行手順が明確になっている
- [ ] Issue/WBSにE2E対象有無を記録できる
- [ ] 失敗時に確認すべきログ/スクリーンショット/rollback方針が記載されている

## 参照

- NotebookLM: https://notebooklm.google.com/notebook/ddde5a4b-ce1a-405d-8291-a334a9371454
- Source: `Vibe coding in prod | Code w/ Claude`

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
