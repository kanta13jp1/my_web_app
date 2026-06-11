# Issue Fix Plan #1830

- Issue: [[追加要望][P1][Codex#1] meal_logs テーブル Migration (#1665)](https://github.com/kanta13jp1/my_web_app/issues/1830)
- Labels: enhancement,追加要望,wbs
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26612413031

## Goal

[追加要望][P1][Codex#1] meal_logs テーブル Migration (#1665)

## Current Context

```text
## 背景
VSCode版 S26 で MealLogPage UI 実装完了。lifestyle-hub EF が meal_logs テーブルを必要とする。

## 依頼内容 (Codex#1担当)
supabase/migrations/YYYYMMDD_create_meal_logs.sql 新規作成:
- meal_logs テーブル (user_id / food_name / meal_type / calories / protein_g / carbs_g / fat_g / logged_at)
- RLS: auth.uid() = user_id
- Index: user_id + logged_at DESC

詳細: docs/cross-instance-prs/20260503_meal_log_ef_codex1_codex2.md

## 担当
Codex#1 (migration専任)

## 優先度
P1 (MealLogPage 稼働に必須)

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
