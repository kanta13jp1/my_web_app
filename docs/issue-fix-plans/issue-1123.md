# Issue Fix Plan #1123

- Issue: [[追加要望] LRM自己修正プランナーでAI役員タスクをGoal-Plan-Action化する](https://github.com/kanta13jp1/my_web_app/issues/1123)
- Labels: enhancement,priority:high,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25411090656

## Goal

[追加要望] LRM自己修正プランナーでAI役員タスクをGoal-Plan-Action化する

## Current Context

```text
## 背景

NotebookLM `DEV Community Newsletter: AI Evolution and Developer Wins` から、LLM/LRMの創発的能力、推論時探索、自己修正、Function Callingを使ったエージェント型AIの実用化が重要テーマとして抽出された。

参照: https://notebooklm.google.com/notebook/27730002-fe8c-40ff-b2c3-431ab8f40a9a

自分株式会社では、CEOの依頼をAI役員が処理する構造がすでにあるため、次の差別化として「回答するAI」から「計画し、自己点検し、実行単位へ落とすAI」に進化させたい。

## 追加したいもの

CEOの依頼を受けたAI役員が、以下の3段階でタスクを扱う `LRM自己修正プランナー` を追加する。

1. Goal: 依頼の成功条件、制約、完了判定を明文化する
2. Plan: サブタスク、必要データ、担当AI役員、ツール実行候補を分解する
3. Action: 実行可能なWBS/GitHub Issue/アプリ内タスクに変換する

さらに、最終回答前に「自己修正チェック」を走らせ、計画漏れ、制約違反、過剰スコープ、危険な外部操作を検出する。

## 想定スコープ

- `agent_org` / `ai_secretary` / `emergency_meeting` 周辺にGPA形式の計画生成モードを追加
- Supabase側に `agent_plans` または既存タスクテーブルへの保存口を検討
- `core-hub` または既存AI Edge Functionに `agent.plan_task` 系actionを追加
- UIでは、Goal/Plan/Action/自己修正結果を折りたたみ表示する
- WBS/GitHub Issue化は初期版ではドラフト生成まででよい

## 受け入れ条件

- CEOが自然文で依頼すると、Goal/Plan/Actionが構造化JSONとして生成される
- 生成結果に完了条件、リスク、次アクションが含まれる
- 自己修正チェックで、過剰スコープ・不足情報・安全確認が明示される
- 既存のAI役員チャット体験を壊さず、任意でGPA計画モードを起動できる
- `flutter analyze` が通る

## 関連・重複回避

- #795 はAI自律タスクのコスト制御が主眼。本Issueは計画品質と自己修正が主眼。
- #846 は権限スコープと承認ゲートが主眼。本Issueは承認前の計画生成と自己点検が主眼。
- #843 は重大決断のレッドチーム検証が主眼。本Issueは日常タスクのGoal-Plan-Action化が主眼。

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
