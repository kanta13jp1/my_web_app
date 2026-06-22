# Issue Fix Plan #2447

- Issue: [[追加要望][P1][資産管理] Supabase同期のステージング検証ログと監査表示](https://github.com/kanta13jp1/my_web_app/issues/2447)
- Labels: enhancement,priority:high,supabase,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25948900849

## Goal

[追加要望][P1][資産管理] Supabase同期のステージング検証ログと監査表示

## Current Context

```text
## 概要
資産/負債ボードを継続運用できる資金繰り管理へ進めるための追加要望です。

## スコープ
- 同期プレビュー/手動同期の対象件数と結果を監査ログとして確認できるようにする
- ローカル有無、Supabase有無、アップロード/ダウンロード/競合候補を表示する
- production writeはまだ既定OFFを維持する

## 受け入れ条件
- [ ] Supabase未設定環境で既存テストが落ちない
- [ ] 同期結果が成功/失敗/競合として追跡できる
- [ ] UIからSupabaseを直接呼ばない

## WBS見積り
- 見積り工数: 2日
- WBS予定開始: 2026-05-20
- WBS予定完了: 2026-05-21
- 同日作業ルール: 1日あたりCodex実装容量を概ね2 effort pointまでとして扱い、同日に詰め込みすぎない

## 注意
金額計算・同期判断はアプリ/Repository/Service層で deterministic に行い、AIは要約・説明補助に留めます。

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
