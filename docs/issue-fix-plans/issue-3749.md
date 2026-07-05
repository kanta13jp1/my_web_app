# Issue Fix Plan #3749

- Issue: [[追加要望][first-user] T5: Zenn/note 個人開発ストーリー記事（一人称ローンチ記事）](https://github.com/kanta13jp1/my_web_app/issues/3749)
- Labels: priority:high,追加要望,acquisition,launch,first-user
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28729723930

## Goal

[追加要望][first-user] T5: Zenn/note 個人開発ストーリー記事（一人称ローンチ記事）

## Current Context

```text
**P1 / owner=user（公開）+claude（下書き）**

自動生成コンテンツではなく、**一人称のストーリー記事**を Zenn または note に1本。「人生を『自分株式会社』として経営するアプリを1人で作った理由」— 個人開発の物語はそれ自体がコンテンツであり、X 投稿（T1）の 2 次拡散先になる。

### 構成案（claude が下書きを作成）
1. なぜ作ったか（自分の課題）
2. 「自分をCEOとして経営する」というコンセプト
3. 主要機能スクショ 3 枚（資産管理 / AIアシスタント / AI大学）
4. 技術スタック 1 段落（Flutter Web + Supabase + AI — Zenn 読者向けフック）
5. 無料で使えます + URL + フィードバック募集

### 受け入れ条件
- 記事公開（URL をコメント）
- 記事から landing への流入が growth attribution で観測できる

統括: #3744


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
