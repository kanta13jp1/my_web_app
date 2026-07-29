# Issue Fix Plan #4151

- Issue: [[追加要望][P2][NotebookLM] a90096c5:1 ユーザーアップロードドキュメントの自動リスク評価および非標準条項フラグ機能の実 装](https://github.com/kanta13jp1/my_web_app/issues/4151)
- Labels: enhancement,priority:medium,automation,追加要望,wbs,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/30420626339

## Goal

[追加要望][P2][NotebookLM] a90096c5:1 ユーザーアップロードドキュメントの自動リスク評価および非標準条項フラグ機能の実 装

## Current Context

```text
<!-- notebooklm-requirement:a90096c5-3e07-46eb-8253-8cdb684bc6d4:1 -->
<!-- notebooklm-requirement-hash:af6a0d1a3d96b248 -->

## Source Notebook

- Notebook ID: `a90096c5-3e07-46eb-8253-8cdb684bc6d4`
- Notebook title: Building the Finance Team of the Future at OpenAI
- Ownership: Owner
- Created: `2026-06-10T17:30:25`
- Requirement slot: `1/3`
- Suggested priority: `P2`
- Extracted at: `2026-07-18T11:12:05Z`

## Additional Request

ユーザーアップロードドキュメントの自動リスク評価および非標準条項フラグ機能の実 装

## Rationale

OpenAIの契約レビューおよびベンダーリスクエージェントの運用事例に基づき、Supabas eのEdge Functionsを活用してアップロードされたファイルや入力データを自動解析し、業務効率 とリスク管理を向上させるため。

## Acceptance Criteria

- [ ] Supabase Storageにドキュメントがアップロードされた際、解析用のEdge Functionが正常にトリガーされること。
- [ ] LLMによる解析が行われ、非標準な内容やリスクスコアがJSON形式でSupabaseの指 定テーブルに保存されること。
- [ ] Flutterで構築されたWebの管理ダッシュボード上で、抽出されたリスクスコアと 該当フラグメントが視覚的に確認できること。

## Implementation Notes

Supabase Edge Functionsと外部LLM APIを連携させて実装する。非標準条項やリスクの定義は法的な基準に依存する可能性が あるため、システム上の判定結果は中立的な参考情報として扱い、最終的な確認は人間の 運用者が行う設計とする。

## Verification / Routing

- [ ] NotebookLM 由来の外部事実は、実装前に公式または一次情報で確認する
- [ ] 既存 GitHub Issues / WBS と重複しないことを確認する
- [ ] Claude Code #1 + Codex #1 の top-level 2インスタンス制に沿って担当を決める
- [ ] 完了時は GitHub Issues WBS Sync または `wbs-progress-update.yml` で進捗を同期する

---


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
