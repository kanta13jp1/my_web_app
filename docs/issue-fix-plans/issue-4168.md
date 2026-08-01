# Issue Fix Plan #4168

- Issue: [[追加要望][P2][NotebookLM] 8623f260:3 新規プロジェクト開始時のテンプレートシート複製ワークフロー導入](https://github.com/kanta13jp1/my_web_app/issues/4168)
- Labels: enhancement,priority:medium,automation,追加要望,wbs,notebooklm
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/30683111421

## Goal

[追加要望][P2][NotebookLM] 8623f260:3 新規プロジェクト開始時のテンプレートシート複製ワークフロー導入

## Current Context

```text
<!-- notebooklm-requirement:8623f260-e937-4b1b-a073-8de96da7893e:3 -->
<!-- notebooklm-requirement-hash:ef5e078680acb6c3 -->

## Source Notebook

- Notebook ID: `8623f260-e937-4b1b-a073-8de96da7893e`
- Notebook title: Google Sheets API v4 Reference Guide
- Ownership: Owner
- Created: `2026-05-20T10:23:56`
- Requirement slot: `3/3`
- Suggested priority: `P2`
- Extracted at: `2026-07-18T11:12:05Z`

## Additional Request

新規プロジェクト開始時のテンプレートシート複製ワークフロー導入

## Rationale

アプリ内で新規プロジェクトが立ち上がった際、標準化された業務プロセスを即座に提 供するため、`spreadsheets.sheets.copyTo`メソッドを用いてマスターテンプレートを自 動複製する機能を追加するため。

## Acceptance Criteria

- [ ] Flutterアプリから新規プロジェクト作成フローを完了した際、バックグラウンド で指定されたテンプレートシートの複製処理が実行されること。
- [ ] 複製された新しいシートのIDとアクセスURLが、Supabaseデータベース上の対象プ ロジェクトレコードに正しく保存されること。
- [ ] 万が一`copyTo`のAPIリクエストが失敗した場合、アプリ側で適切なリトライ処理 が行われるか、ユーザーにエラー状態が明示されること。

## Implementation Notes

シートの権限管理（サービスアカウントの利用やGoogle Drive APIとの併用）についての設計が必要です。コピー元のスプレッドシートIDは環境変数と して管理し、ハードコードを避けてください。

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
