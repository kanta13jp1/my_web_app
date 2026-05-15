# Issue Fix Plan #925

- Issue: [[追加要望] サブスクリプション支出とAI APIコストを統合して最適化提案する](https://github.com/kanta13jp1/my_web_app/issues/925)
- Labels: enhancement,priority:medium,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25894934105

## Goal

[追加要望] サブスクリプション支出とAI APIコストを統合して最適化提案する

## Current Context

```text
## 背景
NotebookLM `jibun-master-brain` では、AIプロバイダー拡張、クォータ監視、資産管理・サブスクリプション管理が個別に進んでいます。AI API利用と通常サブスク支出が分断されると、無駄な固定費や高コストモデル利用が見えづらくなります。

## 要望
サブスクリプション支出とAI API利用実績を横断分析し、解約候補・プラン見直し・デフォルトAIモデル切替を提案する「財務改善サジェスト」を追加したいです。

## 期待する挙動
- サブスク、AI API利用量、プロバイダー別コスト、利用頻度を統合して表示する
- 利用頻度が低いサービスや高コストモデルを検出する
- 代替モデルや低コストルーティングをAIが提案する
- ユーザー承認後にWBSタスク化、または設定更新候補として保存できる

## 受け入れ条件
- `subscriptions` とAIクォータ・利用ログを横断する分析アクションがある
- 家計/資産管理またはAI運用ダッシュボードに改善提案が表示される
- 提案には削減見込み、根拠データ、影響範囲が含まれる
- ユーザーが「採用」「保留」「却下」を選べ、選択結果が記録される

## 優先度
Medium

## NotebookLM根拠
- Notebook: `jibun-master-brain` / `ea6cff25-574d-4b8b-ad72-ab47cf1ed01f`
- AIプロバイダー拡張、クォータ監視、資産管理機能の統合余地に基づく追加要望

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
