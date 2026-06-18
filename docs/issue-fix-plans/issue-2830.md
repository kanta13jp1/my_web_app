# Issue Fix Plan #2830

- Issue: [[追加要望][P2][NotebookLM] 1837f569:2 構造化JSON出力を活用したWBSタスクの自動分割と起票](https://github.com/kanta13jp1/my_web_app/issues/2830)
- Labels: enhancement,priority:medium,automation,追加要望,wbs,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/26924588847

## Goal

[追加要望][P2][NotebookLM] 1837f569:2 構造化JSON出力を活用したWBSタスクの自動分割と起票

## Current Context

```text
<!-- notebooklm-requirement:1837f569-33bc-4b76-9b93-d12055bcb3a9:2 -->
<!-- notebooklm-requirement-hash:69f178a6b6aeadf4 -->

## Source Notebook

- Notebook ID: `1837f569-33bc-4b76-9b93-d12055bcb3a9`
- Notebook title: Building Headless Automation with Claude Code SDK
- Ownership: Owner
- Created: `2026-05-19T00:08:05`
- Requirement slot: `2/3`
- Suggested priority: `P2`
- Extracted at: `2026-05-18T15:23:38Z`

## Additional Request

構造化JSON出力を活用したWBSタスクの自動分割と起票

## Rationale

NotebookLMの取り込み（intake）データや大まかな要件指示から、Claude Code SDKのJSON出力モードを利用してプログラムで解析可能な形式のタスクリストを生成し、 WBSへの反映を完全自動化するため。

## Acceptance Criteria

- [ ] Claude Code SDK実行時に「--output-format JSON」オプションが付与され、AIの出力が完全なJSON形式で取得できること。
- [ ] 取得したJSONデータをパースし、親タスクから複数の具体的な子タスク（Flutte rのUI実装、SupabaseのDB設計など）へと分割できること。
- [ ] 分割されたタスク群がGitHub Issues上のWBSとして自動的に起票・連携されること。

## Implementation Notes

バックエンドまたはGitHub Actions上で動作するタスク管理連携スクリプトを作成する。JSONスキーマをシステムプ ロンプトで厳密に指定し、パースエラーが発生した場合のリトライ機構（AI tool monitoringの一環）を実装する。

## Verification / Routing

- [ ] NotebookLM 抽出結果と既存 repo 文脈の整合性を確認する
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
