# Flutter Web × Supabase マルチルートワークスペース セットアップガイド (#2695)

フロントエンド（Flutter Web: `lib/`, `test/`）とバックエンド（Supabase: `supabase/migrations/`, `supabase/functions/`）および CI 自動化（`scripts/`, `.github/`）を 1 セッションで安全に横断編集するためのマルチルートワークスペース構成と AI エージェント指示手順を定義します。

## 1. セットアップと生成

単一仕様定義 [`config/multiroot_workspace_spec.json`](../config/multiroot_workspace_spec.json) からワークスペース設定・除外ルール・横断開発ルールを生成・検証できます。

```bash
# 仕様とリポジトリ構成・AI Review Gate 許可リスト整合性の検証
python3 -B scripts/multiroot_workspace_manager.py --check-spec

# ワークスペース設定ファイル一式の生成（Cursor / VS Code 用）
python3 -B scripts/multiroot_workspace_manager.py --write
```

生成後は Cursor または VS Code で `File -> Open Workspace from File... -> my_web_app.code-workspace` を開いてください。

## 2. ルート構成と境界保護 (`.cursorignore`)

| ルート名 | パス | 主な対象 |
| --- | --- | --- |
| `my_web_app (Root)` | `.` | ドキュメント・共通設定・ルート設定 |
| `Flutter Web UI (lib)` | `lib` | Domain / Repository / Application / Presentation / DI |
| `Flutter Tests (test)` | `test` | Widget テスト・Repository モック検証 |
| `Supabase Backend (supabase)` | `supabase` | SQL マイグレーション・RLS・Edge Functions (`_shared` 含む) |
| `Automation & CI (scripts)` | `scripts` | Python 品質ゲート・CI/CD 補助ツール |

- `.cursorignore` により `.env*`、各種認証 JSON (`credentials*.json` / `client_secret*.json`)、秘密鍵 (`*.pem`, `*.key`)、個人財務・添付資料ディレクトリ、`build/`、`.dart_tool/`、`.ci-logs/` への不用意なアクセス・コンテキスト混入を防ぎます。

## 3. AI エージェントへの横断実装プロンプト例

1 回の指示で Supabase と Flutter Web を整合させて変更する場合、以下のように変更範囲と契約境界を明示します。

```text
config/multiroot_workspace_spec.json の構成および .cursor/rules/flutter_supabase_cross_stack.mdc に従い、
次の順で Flutter Web と Supabase の変更を同期実装してください:
1. supabase/migrations/: テーブル・RLS・トリガー (`revoke all on function ... from public, anon, authenticated;`, `pg_temp` 末尾) を定義
2. supabase/functions/: Edge Function と単体テストを更新し、`Access-Control-Allow-Headers` に `traceparent, tracestate, baggage, sentry-trace` を含める
3. lib/ & test/: モデル・Repository・Container・View・テスト (`const` リストの防御的コピーと `ensureVisible` を徹底) を同期更新
4. 検証: `dart format --language-version=3.6` 確認、Python CI ゲート、`.dart_tool/` 未残留確認
```
