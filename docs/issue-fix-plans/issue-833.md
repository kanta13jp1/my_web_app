# Issue Fix Plan #833

- Issue: [[追加要望] AI実装向けコア/リーフ境界マップ](https://github.com/kanta13jp1/my_web_app/issues/833)
- Labels: 
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25978233169

## Goal

[追加要望] AI実装向けコア/リーフ境界マップ

## Current Context

```text
## 背景

NotebookLM `ddde5a4b-ce1a-405d-8291-a334a9371454`（Vibe Coding: Responsible Engineering in the Era of AI Agents）では、AIエージェントに任せる範囲を依存関係の少ないリーフノードへ寄せ、認証・DB・課金・外部投稿などのコア領域は人間レビューを厚くする考え方が示されている。

本プロジェクトはFlutter/Supabase/Edge Functions/AI役員/WBS/外部配信を横断しており、AI実装の速度が上がるほど「触ってよい場所」と「慎重に扱う場所」の境界を明示する価値が高い。

## 追加要望

AI実装時に参照できる「コア/リーフ境界マップ」を追加し、機能追加・修正Issueごとに影響範囲とレビュー強度を判定できるようにする。

## 実装スコープ案

- `docs/AI_DEV_PRINCIPLES.md` または専用ドキュメントにコア/リーフ分類表を追加
- 例: 認証/RLS/課金/外部投稿/Secrets/本番DBはコア、独立UIカード/表示整形/テスト補助/静的コンテンツはリーフ
- GitHub IssueテンプレートまたはWBS生成時に `core/leaf/mixed` を記録する欄を追加
- ホームまたはAI開発原則ページから境界マップへ到達できる導線を検討

## 受け入れ条件

- [ ] 主要ディレクトリ/機能が `core` / `leaf` / `mixed` に分類されている
- [ ] `core` 変更時に必要なレビュー観点（認証、DB、課金、外部投稿、Secrets、rollback）が明記されている
- [ ] IssueまたはWBSタスクに境界分類を記録できる
- [ ] 既存のAI開発原則ページまたはドキュメントから参照できる
- [ ] 少なくとも1つのテストまたは静的検証で分類データの欠落を検出できる

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
