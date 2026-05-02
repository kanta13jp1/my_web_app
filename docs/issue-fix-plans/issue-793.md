# Issue Fix Plan #793

- Issue: [[追加要望] Claude Apps/MCPからmy_web_appを直接操作できる連携基盤](https://github.com/kanta13jp1/my_web_app/issues/793)
- Labels: enhancement,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25240588332

## Goal

[追加要望] Claude Apps/MCPからmy_web_appを直接操作できる連携基盤

## Current Context

```text
## 背景
NotebookLM ノート `e89d2ca7-1dc9-41a1-8fe2-bad5103a757b` では、Anthropic が Claude を単なるチャットから業務ツールを横断して操作する AI OS 的な方向へ進化させており、MCP / Claude Apps による外部アプリ連携が重要テーマとして示されています。

## 目的
ユーザーが Claude などのAIチャット画面から my_web_app のデータ参照・タスク登録・WBS確認・追加要望登録などを直接実行できるようにし、画面切り替えと手作業を減らします。

## 主要要件
- my_web_app の主要機能を MCP サーバーとして公開できる設計を検討する
- WBS、GitHub Issues、ユーザータスク、AIシェア、地方選KPIなどの読み取り系操作を MCP tool として提供する
- 更新系操作は確認ステップを必須にし、誤操作を防ぐ
- Claude Apps 風の埋め込みUIで、WBSやユーザータスクを確認・実行できる導線を検討する

## 受け入れ条件
- MCP クライアントから my_web_app の代表的なデータを取得できる
- 少なくとも WBS タスク一覧取得、追加要望作成、ユーザータスク確認の3操作が設計またはプロトタイプ化されている
- 更新系操作にはユーザー確認のガードレールが入っている

## 参考
https://notebooklm.google.com/notebook/e89d2ca7-1dc9-41a1-8fe2-bad5103a757b

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
