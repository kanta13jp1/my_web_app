# Docker & Supabase CLI ローカルエミュレータ開発ガイド (#2803)

## 1. 方針

本番 Supabase プロジェクトを汚染せずに開発・検証を行うため、ホストマシンへ PostgreSQL 本体を直接インストールする代わりに **Docker Desktop + Supabase CLI (`supabase start`)** を用いたローカルエミュレータ環境を使用する。

## 2. ポート構成 (`supabase/config.toml`)

- API Gateway: `http://127.0.0.1:54321` (`[api].port = 54321`)
- PostgreSQL 17: `127.0.0.1:54322` (`[db].port = 54322`, `shadow_port = 54320`)
- Supabase Studio: `http://127.0.0.1:54323` (`[studio].port = 54323`)
- Inbucket (メール検証 UI): `http://127.0.0.1:54324` (`[inbucket].port = 54324`)

## 3. 起動・マイグレーション・シード手順

1. **Docker Desktop の起動確認**:
   ```powershell
   docker info
   ```
2. **ローカル Supabase スタック起動**:
   ```powershell
   supabase start
   ```
3. **マイグレーションおよびシード投入のリセット実行**:
   ```powershell
   supabase db reset
   ```
4. **ローカル接続情報の確認**:
   ```powershell
   supabase status
   ```

## 4. Flutter Web / Edge Functions のローカル接続切り替え

1. `.env.example` を `.env.local` へコピーし、`supabase status` で表示されたローカル `API URL`（`http://127.0.0.1:54321`）とローカル anon key を設定する（`.env.local` や実シークレットは絶対に Git コミットしないこと）。
2. **事前検証ヘルパーの実行**:
   ```powershell
   python -B scripts/supabase_local_env_helper.py --env-file .env.local --require-local --json
   ```
3. **Edge Functions のローカル起動**:
   ```powershell
   supabase functions serve --env-file .env.local
   ```
4. **Flutter Web のローカル起動**:
   ```powershell
   flutter run -d chrome --dart-define-from-file=.env.local
   ```
