# Issue Fix Plan #773

- Issue: [[追加要望] 全AI機能共通のガードレール・PII監査レイヤー](https://github.com/kanta13jp1/my_web_app/issues/773)
- Labels: 追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25772961546

## Goal

[追加要望] 全AI機能共通のガードレール・PII監査レイヤー

## Current Context

```text
NotebookLM ノートブック `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec`（Writer AI Studio Comprehensive Development and Management Guide）に基づく追加要望です。

## 背景
Writer AI Studio は、企業向けAI運用において Guardrails、PII保護、Toxic check、監査ログ、Observability を重視しています。本プロジェクトも AI大学、WBS、追加要望フォーム、チャットボット、X投稿生成、ライフマネジメント、資産管理などAI出力箇所が増えており、機能ごとに安全対策がばらけると品質と運用のリスクが高まります。

## 要望
すべてのAI生成・AI解析機能の前後に共通で適用できる「AIガードレール・監査レイヤー」を追加したいです。

## 期待する成果
- 個人情報、機密情報、危険な内容、不適切表現をAI出力前後で検知できる
- AI機能ごとのログ、モデル、プロンプト、出力、ガードレール判定を追跡できる
- 問題が起きたときに「どの機能のどのAI出力か」を後から監査できる
- X投稿生成や外部公開ページの安全性が上がる

## 実装メモ
- `ai_audit_logs` / `ai_guardrail_results` のような共通テーブルを追加
- `ai-hub` など既存Edge Functionの共通ラッパーとして実装
- 判定カテゴリ: `pii`, `toxicity`, `medical/legal/financial_risk`, `public_post_risk`, `hallucination_risk`
- 高リスク時は自動投稿・自動Issueクローズなどの破壊的操作を止める
- 既存のプロアクティブ診断ダッシュボード構想とも接続可能

## 受け入れ条件
- [ ] AI呼び出しごとに監査ログが保存される
- [ ] PII/不適切表現/公開投稿リスクのいずれかを検知できる
- [ ] 高リスク判定時にユーザー確認または処理停止ができる
- [ ] 管理画面または診断画面で直近のAI監査結果を確認できる

## 分類
- カテゴリ: 機能追加
- 優先度: high
- 情報源: NotebookLM `54b6f2f2-6831-4376-b2dd-99a1a4bf90ec`

## WBS連携
このIssueは追加要望としてWBSのユーザー要望タスクにも反映対象です。

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
