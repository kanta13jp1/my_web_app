# Antigravity 向け MCP サーバー接続ガイド (自分株式会社 / `my_web_app`)

このドキュメントは、Antigravity（App / CLI / IDE）から `my_web_app`（自分株式会社）を **Streamable HTTP MCP サーバー** として直接操作するための構成・認証・運用手順です。

## 1. アーキテクチャ概要

- **エンドポイント（Streamable HTTP / Stateless）**:
  `https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub/mcp`
- **基盤**: 既存の `tools-hub` Edge Function（`[EF-CAP-50]` 枠内・新規 Edge Function 増設なし）に MCP Streamable HTTP ライフサイクル（`initialize` / `notifications/initialized` / `ping` / `tools/list` / `tools/call`）および RFC 9728 メタデータ正規化を統合。
- **2 系統の Bearer 認証**:
  1. **個人向け最短ルート（推奨）**: `/jibun-api` で発行した `jibun_sk_...` API キー（SHA-256 ハッシュ保管・スコープ最小化・レート制限・監査ログ付き）。
  2. **OAuth 2.1 + PKCE ルート**: WorkOS AuthKit + DCR（`mcp_oauth_clients` / `mcp_audit_log`）。

## 2. Antigravity 接続手順（`jibun_sk_` キー利用）

1. 本番サイト [自分API 管理ページ](https://my-web-app-b67f4.web.app/jibun-api) を開き、利用したい最小スコープのみを選択して API キー（`jibun_sk_...`）を発行します。
   - 例: ノートの閲覧と作成を行う場合は `notes.read` と `notes.write` を選択。
   - **注意**: 発行直後に 1 回だけ表示される平文キーを安全に保管してください。リポジトリや Git 管理下の設定ファイルへ直接書き込まないでください。
2. マシンローカルの `~/.gemini/config/mcp_config.json`（UTF-8 BOM なし）の `mcpServers` に以下を追加します。

```json
{
  "mcpServers": {
    "jibun-inc": {
      "serverUrl": "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub/mcp",
      "headers": {
        "Authorization": "Bearer <YOUR_JIBUN_API_KEY>"
      }
    }
  }
}
```

3. Antigravity を再読み込みします。
   - **Antigravity App**: サイドバー **Customizations > Installed > MCP Servers** から再起動・接続状態を確認。
   - **Antigravity CLI**: プロンプトで `/mcp` を実行して `jibun-inc` がアクティブであることを確認。

## 3. 提供ツール一覧（12 ツール）

| ツール名 | 用途 | 必須 `jibun_sk_` スコープ | WorkOS スコープ | 書込確認 (`confirm: true` + `confirmation_phrase`) |
| --- | --- | --- | --- | --- |
| `account.me` | 認証ユーザー・キー情報の確認 | `*`（有効キーのみ） | `read` | 不要 (`readOnlyHint`) |
| `notes.list` | ユーザーノート検索・一覧 | `notes.read` | `read` | 不要 (`readOnlyHint`) |
| `notes.create` | ノート新規作成 | `notes.write` | `create` | `create_note` |
| `notes.update` | 既存ノートの更新 | `notes.write` | `create` | `update_note` |
| `notes.delete` | 既存ノートの削除 | `notes.write` | `create` | `delete_note` (`destructiveHint`) |
| `wbs.tasks.list` | WBS タスク一覧 | `tasks.read` | `read` | 不要 (`readOnlyHint`) |
| `user_tasks.list` | ユーザー担当 WBS タスク一覧 | `tasks.read` | `read` | 不要 (`readOnlyHint`) |
| `achievements.list` | 開発実績一覧 | `achievements.read` | `read` | 不要 (`readOnlyHint`) |
| `workers.list` | 登録済み Agent Worker 一覧 | `workers.invoke` | `read` | 不要 (`readOnlyHint`) |
| `workers.invoke` | 登録済み Agent Worker 実行 | `workers.invoke` | `create` | `invoke_worker` |
| `public_businesses.reference_list` | 公開施設リファレンス参照 | `*`（有効キーのみ） | `read` | 不要 (`readOnlyHint`) |
| `feature_request.create` | WBS 追加要望の登録 | 不可（WorkOS のみ） | `create` | `create_feature_request` |

## 4. セキュリティ不変制約（`MCP_AUTH_SECURITY_PRINCIPLES.md` 準拠）

- **Deny-by-Default**: `tools/call` はすべて有効な Bearer トークン必須（未認証時は `401` + `WWW-Authenticate`）。
- **最小権限マッピング**: `jibun_sk_` キーは `jibunApiScopesToMcpPermissions` により許可スコープ対応ツールのみへ変換され、`all` / `*` / `feature_request.create` は絶対に付与されません。
- **Sampling 非申告**: `initialize` の `capabilities` に `sampling` を含めず、Sampling-Based Injection 経路を排除しています。
- **二重保護（書込確認＋レート制限＋監査ログ）**:
  - すべての作成・更新・削除・Worker 実行ツールは `confirm: true` とツール固有の `confirmation_phrase` を要求します（不足時は `409 confirmation_required`）。
  - `jibun_sk_` キーには 60 回/分・2,000 回/日・Worker 実行 10 回/分（`api.*` と `mcp.*` 合算）のレート制限が適用されます。
  - 全呼び出しは `mcp_audit_log` および `user_api_audit_log` の双方へ記録されます。
- **SSRF / Prompt Injection 防御**: `workers.invoke` は呼び出し毎に HTTPS・プライベート IP/DNS rebinding 検証、HMAC-SHA256 署名（`X-Jibun-Signature`）、応答サイズ上限（64 KiB）、および `scanMcpPayloadForSecuritySignals` による出力スキャン（検知時は `422` で遮断）を実施します。

## 5. 動作検証・トラブルシューティング

- **スモークテスト実行**:
  ```powershell
  .\scripts\tools_hub_mcp_smoke.ps1 `
    -BaseUrl "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/tools-hub" `
    -SkipRegistration
  ```
- **`401 Unauthorized` が返る場合**: `Authorization: Bearer jibun_sk_...` のヘッダー書式とキーの失効・有効期限を `/jibun-api` で確認してください。
- **`403 mcp_scope_denied` が返る場合**: エラー本文の `required_jibun_api_scope` を含む API キーを `/jibun-api` で再発行してください。
- **`409 confirmation_required` が返る場合**: モデルの誤操作防止ガードが正常に作動しています。引数の `confirm: true` と `confirmation_phrase` を確認のうえ実行してください。
