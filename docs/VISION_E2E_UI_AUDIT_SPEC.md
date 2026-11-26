# 高解像度ビジョン E2E・UI 自動監査仕様 (#2790)

## 1. 概要

既存の Playwright 視覚検証フロー（`package.json` の `e2e:visual` および `.github/workflows/e2e-smoke.yml`）と連携し、フル解像度スクリーンショットのメタデータ検証・Task Budget 上限監視・GitHub Issues 起票用 Markdown レポート生成（ドライラン対応）を行う。

## 2. 機能構成 (`scripts/vision_ui_e2e_audit.py`)

1. **高解像度スクリーンショット検証 (`ScreenshotCaptureMetadata`)**:
   - `downscaled == False`（強制リサイズなし）および長辺 `<= 2576` px を検査する。
   - `28 x 28` px パッチ単位の概算入力トークン数（`ceil(width / 28) * ceil(height / 28)`）を算出する。
2. **Task Budget ガード (`TaskBudgetConfig` / `TaskBudgetTracker`)**:
   - 1 監査ランあたりの消費上限（既定 `64000` トークン、`task_budget` 設定および `task-budgets-2026-03-13` ベータヘッダ相当）を管理し、超過時は終了コード `1` で通知する。
3. **異常レポート出力 (`render_github_issue_markdown`)**:
   - 検知されたレイアウト崩れ・表示異常を JSON および GitHub Issue 用の構造化 Markdown として出力する（ユニットテストおよびドライランではライブの `gh issue create` を実行しない）。

## 3. 一次情報と未確認事項の切り分け

- **確認済み一次情報**:
  - Anthropic Vision ドキュメント（長辺 2,576 px の高解像度対応および `28x28` パッチに基づくトークン計算）: <https://platform.claude.com/docs/en/build-with-claude/vision>
  - Anthropic Task Budgets ドキュメント（`task_budget` パラメータによるエージェントループ全体の消費上限管理）: <https://platform.claude.com/docs/en/build-with-claude/task-budgets>
- **未確認事項（Issue 起票元 NotebookLM メモ由来）**:
  - 視覚敏捷性ベンチマーク「`98.5%`」およびトークンコスト「従来の約 `3 倍`」という数値は、上記一次ドキュメント上で直接確認できていないため **未確認** として扱う。
