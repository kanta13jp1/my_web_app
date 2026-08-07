# Issue Fix Plan #4130

- Issue: [[追加要望][P2][NotebookLM] b366e23e:1 AI機能の投資対効果（ROI）測定ダッシュボードの実装](https://github.com/kanta13jp1/my_web_app/issues/4130)
- Labels: enhancement,priority:medium,automation,追加要望,wbs,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/31144522326

## Goal

[追加要望][P2][NotebookLM] b366e23e:1 AI機能の投資対効果（ROI）測定ダッシュボードの実装

## Current Context

```text
<!-- notebooklm-requirement:b366e23e-b168-455c-b082-d9f351c47db6:1 -->
<!-- notebooklm-requirement-hash:b2cdb147ff80963f -->

## Source Notebook

- Notebook ID: `b366e23e-b168-455c-b082-d9f351c47db6`
- Notebook title: Return on Investment Analysis and Strategic Business Performance
- Ownership: Owner
- Created: `2026-07-18T11:04:32`
- Requirement slot: `1/3`
- Suggested priority: `P2`
- Extracted at: `2026-07-18T11:12:05Z`

## Additional Request

AI機能の投資対効果（ROI）測定ダッシュボードの実装

## Rationale

経営層やステークホルダーへAIの価値を証明するため、DX投資の3階層モデル（直接的コ スト削減、機会損失の回避、付加価値の創出）に基づき、単純なAPIコストだけでなく総 合的なROIを可視化する仕組みが必要である。

## Acceptance Criteria

- [ ] Supabase上でAI機能の利用回数とAPIコストを集計するビューが作成されているこ と
- [ ] 各AI機能による推定業務削減時間や付加価値をパラメータとして設定し、ROIを自 動計算できること
- [ ] Flutter Webの管理画面でROIの推移を視覚的なダッシュボードとして確認できること

## Implementation Notes

SupabaseのEdge FunctionsでAPI呼び出しログを取得し、定期バッチで集計する。ROI算出ロジックは財務 ・外部指標に基づくため、自社のビジネスモデルに合わせた係数調整機能を設ける。

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
