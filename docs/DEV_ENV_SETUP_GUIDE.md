# Dev Environment Setup Guide — Win11 + プロキシ対策 (#1356 / part 145)

> **status**: 設計 spec / Win版#132 part 145 / 2026-05-05
> **issue**: [#1356](https://github.com/kanta13jp1/my_web_app/issues/1356) [追加要望] 開発環境自動セットアップとプロキシ対策ガイドの整備
> **scope**: 設計 + 手順書 (Win Claude territory / docs) / 実装 script は Win Codex (= scripts/setup-dev-env.ps1) ハンドオフ
> **NotebookLM source**: `55a65bf0` Winget Local Environment Configuration for Windows 11

## 1. 思想

新規参画メンバーが proxy / ENOTFOUND ループで初日を浪費 = 機会損失. **「git clone → 1 script → 動く」**
を Win11 + 社内 proxy 環境で実現 = INDIE-29 #1 (shipping 速度) を team 入口で守る.

## 2. 適用範囲

| 場面 | 対応 |
|---|---|
| 新規メンバー Win11 環境構築 | ✅ §3 setup script |
| proxy エラー (ENOTFOUND / EAI_AGAIN) 発生時 | ✅ §4 troubleshooting |
| CI 環境 (= GitHub Actions Windows runner) | △ 別 setup (= GHA 専用 / 本 guide 対象外) |
| WSL 内 Linux 環境 | △ 別 guide 推奨 (= part 146+ candidate) |

## 3. 一括 setup script 設計 (受入 #1)

### 3.1 file 配置

```
scripts/
  setup-dev-env.ps1                   # 主 entry (= PowerShell)
  _setup_steps/
    10_winget_tools.ps1               # OpenJDK / Git / Node.js / AWS CLI 等
    20_vscode_extensions.ps1          # VS Code 拡張一括
    30_npm_global.ps1                 # corepack / yarn / pnpm
    40_supabase_cli.ps1               # Supabase CLI (= scoop or curl)
    50_flutter_dart.ps1               # Flutter SDK + Dart SDK
    99_verify.ps1                     # 全 tool version dump
```

### 3.2 必須 install 項目

| tool | source | 用途 |
|---|---|---|
| Git | winget Microsoft.Git | repo |
| OpenJDK 21 | winget Microsoft.OpenJDK.21 | Android build |
| Node.js LTS | winget OpenJS.NodeJS.LTS | npm scripts |
| AWS CLI v2 | winget Amazon.AWSCLI | (= 任意 / cloud 連携時) |
| Python 3.12 | winget Python.Python.3.12 | scripts/*.py |
| GitHub CLI | winget GitHub.cli | gh issue/pr |
| VS Code | winget Microsoft.VisualStudioCode | エディタ |
| PowerShell 7 | winget Microsoft.PowerShell | Win Codex 利用 |
| Flutter SDK | winget Google.Flutter (= 暫定) | Flutter Web |
| Supabase CLI | scoop install supabase | EF deploy |

### 3.3 VS Code 拡張一括

```powershell
# scripts/_setup_steps/20_vscode_extensions.ps1
$extensions = @(
  'Dart-Code.flutter',
  'Dart-Code.dart-code',
  'denoland.vscode-deno',
  'ms-azuretools.vscode-docker',
  'github.vscode-pull-request-github',
  'github.copilot',
  'anthropic.claude-code',                     # Claude Code 拡張
  'eamodio.gitlens',
  'esbenp.prettier-vscode',
  'editorconfig.editorconfig',
  'redhat.vscode-yaml',
  'ms-vscode-remote.remote-wsl'
)
foreach ($ext in $extensions) {
  Write-Host "[ext] $ext ..." -ForegroundColor Cyan
  code --install-extension $ext --force
}
```

### 3.4 進捗出力 pattern (= 実装メモ反映)

```powershell
function Step($num, $msg, $action) {
  $tag = "[STEP $num/$($script:total)]"
  Write-Host "`n$tag $msg" -ForegroundColor Yellow
  $start = Get-Date
  try {
    & $action
    $elapsed = (Get-Date) - $start
    Write-Host "$tag ✓ ($([int]$elapsed.TotalSeconds)s)" -ForegroundColor Green
  } catch {
    Write-Host "$tag ✗ FAILED: $_" -ForegroundColor Red
    if (-not $env:CI) {
      $cont = Read-Host "Continue with next step? [y/N]"
      if ($cont -ne 'y') { throw }
    }
  }
}
```

= 各 step 開始 / 完了 / 失敗時の 3 line を必ず出力 + interactive 失敗継続選択 (CI では auto-skip).

### 3.5 idempotent 性

各 winget install は `--accept-source-agreements --accept-package-agreements --silent`.
既 install は winget 自身が skip → 多重実行可.

## 4. Proxy トラブルシューティング (受入 #2)

### 4.1 症状別対応 matrix

| 症状 | 場所 | 対応 |
|---|---|---|
| `ENOTFOUND registry.npmjs.org` | npm install | §4.2 npm proxy 解除 |
| `EAI_AGAIN api.github.com` | gh auth login | §4.3 環境変数解除 |
| `winget connection failed` | winget install | §4.4 winget 設定 |
| `git: unable to access` | git clone/fetch | §4.5 git config 解除 |
| `Could not resolve host` (= 一般) | 全般 | §4.6 PowerShell session 確認 |

### 4.2 npm proxy 解除

```powershell
# 確認
npm config get proxy
npm config get https-proxy

# 解除
npm config delete proxy
npm config delete https-proxy

# .npmrc 編集 (= ユーザー全体)
notepad $env:USERPROFILE\.npmrc
# 'proxy=' / 'https-proxy=' 行を削除して保存
```

### 4.3 環境変数解除 (= 一時 / セッション内)

```powershell
# 確認
$env:HTTP_PROXY
$env:HTTPS_PROXY
$env:NO_PROXY

# 一時解除 (= 当該 PS session のみ)
Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue

# 永続解除 (= ユーザー環境変数)
[Environment]::SetEnvironmentVariable('HTTP_PROXY', $null, 'User')
[Environment]::SetEnvironmentVariable('HTTPS_PROXY', $null, 'User')
```

### 4.4 winget 設定 reset

```powershell
# winget settings.json を確認
notepad (winget settings --info | Select-String 'User Settings').Line.Split(':')[-1].Trim()

# settings.json 内 'network.downloader' を auto に
# 例:
# { "network": { "downloader": "auto" } }
```

### 4.5 git proxy 解除

```powershell
git config --global --get http.proxy
git config --global --get https.proxy

git config --global --unset http.proxy
git config --global --unset https.proxy
```

### 4.6 PS session の現状 dump (= 切り分け support)

```powershell
# scripts/_setup_steps/99_verify.ps1 の一部
@{
  HTTP_PROXY = $env:HTTP_PROXY
  HTTPS_PROXY = $env:HTTPS_PROXY
  NO_PROXY = $env:NO_PROXY
  NPM_PROXY = (npm config get proxy)
  NPM_HTTPS_PROXY = (npm config get https-proxy)
  GIT_HTTP_PROXY = (git config --global --get http.proxy)
} | Format-Table -AutoSize
```

= 切り分け時 1 コマンドで現状把握.

### 4.7 「proxy 残骸」よくある原因 (= INDIE-29 学習資産)

| 原因 | 検出方法 |
|---|---|
| 過去の社内 PC 移行で `.npmrc` に proxy URL 残存 | `cat $env:USERPROFILE\.npmrc` |
| Windows credential manager に古い proxy auth | `cmdkey /list \| Select-String proxy` |
| VS Code `http.proxy` 設定残存 | settings.json 内 `"http.proxy"` |
| corepack / yarn cache に proxy URL | `yarn config get proxy` |

## 5. README 参照導線 (受入 #3)

### 5.1 README.md 追記提案 (= Win Codex hand off)

```markdown
## 開発環境セットアップ

新規参画時:
\`\`\`powershell
git clone https://github.com/kanta13jp1/my_web_app.git
cd my_web_app
.\scripts\setup-dev-env.ps1
\`\`\`

通信エラー (`ENOTFOUND` / `EAI_AGAIN`) が出た場合:
👉 [docs/DEV_ENV_SETUP_GUIDE.md §4 Proxy トラブルシューティング](docs/DEV_ENV_SETUP_GUIDE.md#4-proxy-トラブルシューティング受入-2)
```

### 5.2 docs/INDEX.md (= Karpathy Wiki 経由)

`scripts/wiki_compile.py` 次回実行時に本 guide を `docs/concepts/dev-env-setup.md` として
自動取り込み (= part 132 機構).

## 6. Win Codex hand off scope

- [ ] `scripts/setup-dev-env.ps1` (= §3.1 entry)
- [ ] `scripts/_setup_steps/10_winget_tools.ps1` (= §3.2)
- [ ] `scripts/_setup_steps/20_vscode_extensions.ps1` (= §3.3)
- [ ] `scripts/_setup_steps/30_npm_global.ps1`
- [ ] `scripts/_setup_steps/40_supabase_cli.ps1`
- [ ] `scripts/_setup_steps/50_flutter_dart.ps1`
- [ ] `scripts/_setup_steps/99_verify.ps1` (= §4.6)
- [ ] `README.md` 追記 (= §5.1)

EF 数 +0 (= ローカル script のみ / [EF-CAP-50] 完全遵守).
推定工数: 5h (= main script 1.5h + 6 step files 2.5h + verify 0.5h + README 0.5h).

## 7. PHILOSOPHY-22 / INDIE-29 alignment

### PHILOSOPHY-22

- ✅ #2 ミッション — team velocity 守備
- ✅ #6 時間最適化 — proxy ループで失う 1-2 day 削減
- ✅ #7 資産負債 — script + guide = 永続資産

### INDIE-29

- ✅ #1 shipping 速度 — 環境構築即日化
- ✅ #2 自動化 — 1 script 完結
- ✅ #5 共有可能 — README 1 行で導線
- ✅ #7 学習資産 — proxy 罠を docs 化 = 二度遭遇しない

## 8. 受け入れ条件 mapping

| 受入条件 | 対応 section |
|---|---|
| #1 一括 install script | §3 (PowerShell + 6 step files) |
| #2 proxy 解除手順 docs | §4 (npm + env + winget + git + dump) |
| #3 README 参照導線 | §5 (README.md 追記 + INDEX.md auto-取込) |
