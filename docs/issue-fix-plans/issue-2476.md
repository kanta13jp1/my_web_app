# Issue Fix Plan #2476

- Issue: [[追加要望][P2][資産管理][第2弾D] 異常検知DB (anomaly_detections table)](https://github.com/kanta13jp1/my_web_app/issues/2476)
- Labels: enhancement,priority:medium,supabase,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/29716716842

## Goal

[追加要望][P2][資産管理][第2弾D] 異常検知DB (anomaly_detections table)

## Current Context

```text
## 概要
資産/負債ボードを継続運用できる資金繰り管理へ進めるための追加要望です (= 第2弾 D: AI 異常検知).

## スコープ
- anomaly_detections table (id, user_id, detected_at, category, expected, actual, delta, severity[low/medium/high], ai_explanation, dismissed_at)
- index: (user_id, detected_at desc)

## 受け入れ条件
- [ ] 既存資産管理機能を壊さない (= #2446-#2456 整合)
- [ ] テスト緑 (= analyze 0 / unit/integration pass)
- [ ] feature flag が必要な場合は OFF default + 段階的 rollout 対応

## WBS見積り
- 見積り工数: 1日
- WBS予定開始: 2026-07-08
- WBS予定完了: 2026-07-08
- 同日作業ルール: 1日あたりCodex実装容量を概ね2 effort pointまでとして扱い、同日に詰め込みすぎない

## 親EPIC / 関連
- 第1弾 (= #2446-#2456) の延長として位置付け
- 部 218 user 直接 ask (= 2026-05-16 早朝 JST / Win Claude#132)
- WBS reschedule_realistic (= 部 218 fire / 497 task / 5-month timeline)

## 注意
- 金額計算・同期判断はアプリ/Repository/Service層で deterministic に行い、AIは要約・説明補助に留めます。
- Supabase RLS / production write は段階的有効化 (= 第1弾 #2449 規約準拠).
- PII guardrail (= 必要に応じて) は OFF default + ユーザー明示 ON のみ.


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
