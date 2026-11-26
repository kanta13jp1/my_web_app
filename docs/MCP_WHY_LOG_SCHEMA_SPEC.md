# マルチMCP環境向け「推論プロセス（Why）」ログスキーマ仕様 (#2814)

## 1. 概要

複数の MCP サーバーが並行稼働する環境において、単なるツール呼び出し履歴だけでなく「なぜそのサーバーとツールを選択したか（Why）」を再現可能に記録・検証するため、`reasoning_context` JSON スキーマおよびバリデータを定義する。

## 2. 必須フィールド (`docs/schemas/mcp_reasoning_context.schema.json`)

- `availableTools`: 利用可能だったツール名一覧（1件以上）
- `selectedTool`: 実際に選択したツール名（`availableTools` に含まれること）
- `reasoningWhy`: 選択理由のテキスト
- `promptHash` または `promptSummary`: 入力プロンプトの識別ハッシュまたは要約（少なくとも一方必須）
- `serverName`: 呼び出し対象 MCP サーバー名
- `timestamp`: ISO-8601 日時文字列

## 3. バリデーションと CI 統合

- **Edge Function バリデータ**: `supabase/functions/_shared/mcp_why_log_validator.ts` (`validateReasoningContext`)
- **CI 決定論的チェッカー**: `scripts/check_mcp_why_log_schema.py` および `scripts/test_mcp_why_log_schema.py`
