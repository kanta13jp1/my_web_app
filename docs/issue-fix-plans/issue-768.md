# Issue Fix Plan #768

- Issue: [[追加要望] Gemini整理術を応用したAI生活リセットプランナー](https://github.com/kanta13jp1/my_web_app/issues/768)
- Labels: 追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/24972577390

## Goal

[追加要望] Gemini整理術を応用したAI生活リセットプランナー

## Current Context

```text
NotebookLM ノートブック `579bd686-f17e-414a-894f-822f29b5c11e`（8 Gemini Tips for Organizing Your Space and Life）に基づく追加要望です。

## 背景
Gemini の整理整頓活用例では、ユーザーの生活スタイルや状況に合わせて、掃除・片付け・生活改善のステップを個別生成することが示されています。本プロジェクトのライフマネジメントでは、時間・お金・健康・体力・知能・集中力の浪費を減らすことが中心課題なので、生活改善を「低ハードルな一手」まで分解する機能と相性が高いです。

## 要望
生活・仕事・学習・家計・健康の現状を入力または既存データから読み取り、AI が「今日から始める生活リセット計画」を自動生成する機能を追加したいです。

## 期待する成果
- ユーザーが大きな目標に圧倒されず、最初の1タスクから着手できる
- 継続系タスクを一度に増やさず、習慣化まで低ハードルタスクを優先できる
- KGI/CSF/KPI と日次タスクが自然につながる

## 実装メモ
- 既存のライフマネジメント / 資産管理 / 習慣化機能と統合
- AI が「今週の片付け対象」「最初の15分タスク」「やらないこと」を提案
- タスクは WBS または日次タスクに登録できるようにする
- 将来的には写真アップロードやカレンダー情報も考慮

## 受け入れ条件
- [ ] ユーザーの現状からAIが生活リセット計画を生成できる
- [ ] 生成結果に KGI / CSF / KPI / 今日の最小タスク が含まれる
- [ ] 継続系タスクは1つずつ習慣化する設計になっている
- [ ] 生成タスクをWBSまたは日次タスクに登録できる

## 分類
- カテゴリ: 機能追加
- 優先度: medium
- 情報源: NotebookLM `579bd686-f17e-414a-894f-822f29b5c11e`

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
