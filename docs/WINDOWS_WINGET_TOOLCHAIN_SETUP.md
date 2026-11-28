# Windows 11 Winget ツールチェーン一括導入ガイド (#2805)

## 1. 概要

Windows 11 環境において `winget` を用いて `my_web_app` 開発に必要な基本 CLI ツールチェーンを一括導入し、プロキシ起因の通信エラー（`ENOTFOUND` 等）を回避するための標準オンボーディング手順を定める。

## 2. Winget 導入対象パッケージ（実機確認済み ID）

ローカル環境（`winget v1.29.380`）で `winget search --exact --id` により存在確認済みのパッケージ:

| ツール | Winget ID | 用途 |
|---|---|---|
| Git | `Git.Git` | バージョン管理・Worktree 運用 |
| GitHub CLI | `GitHub.cli` | PR 作成・CI 確認・Issue 同期 |
| Deno | `DenoLand.Deno` | Supabase Edge Functions / `_shared` テスト |
| Node.js (LTS) | `OpenJS.NodeJS.LTS` | Playwright E2E・`npx supabase` 実行基盤 |

> **未登録パッケージに関する注記**: `winget search` 上で公式 `Google.Flutter` / `Supabase.CLI` パッケージは既定ソースに存在しないため、`Flutter SDK` は公式 Windows ZIP（または FVM）で導入し、`Supabase CLI` は `OpenJS.NodeJS.LTS` 導入後に `npx supabase`（または Scoop `supabase`）を利用する。

## 3. プロキシ起因エラー（`ENOTFOUND`）の事前回避

企業・開発環境の古いプロキシ設定が残っていると `winget` / `npm` / `flutter` / `supabase` が `ENOTFOUND` で失敗する。実行前に以下を確認・解除する:

```powershell
Remove-Item Env:HTTP_PROXY, Env:HTTPS_PROXY, Env:ALL_PROXY -ErrorAction SilentlyContinue
```

## 4. 一括導入スクリプトと動作確認

```powershell
# 1. Dry-Run で実行コマンドを確認
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup_windows_toolchain.ps1 -DryRun

# 2. 本実行（ライセンス同意フラグ自動付与・プロキシ環境変数クリア付き）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup_windows_toolchain.ps1 -ClearProxyEnv
```

導入後のバージョン確認コマンド:

```powershell
git --version
gh --version
deno --version
node --version
flutter --version
supabase --version
```
