# Windows development setup and proxy troubleshooting

This guide is the onboarding path for a fresh Windows 11 machine working on
`my_web_app`. It covers the baseline installer script and the proxy cleanup
steps for common `ENOTFOUND`, `ECONNRESET`, `407 Proxy Authentication Required`,
and package registry failures.

## Quick start

Run PowerShell as your normal user from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1
```

Preview without installing anything:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1 -DryRun
```

Clear stale proxy settings before installing:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1 -ClearProxy
```

## What the script installs

The script uses `winget` for machine tools and the `code` CLI for VS Code
extensions. It prints each step before running it, skips already installed
winget packages, and prints a version summary at the end.

| Area | Items |
| --- | --- |
| Core CLI | Git, GitHub CLI, Node.js LTS, Python 3.12, Deno |
| App tooling | Visual Studio Code, OpenJDK 17, AWS CLI |
| VS Code | Dart, Flutter, Deno, PowerShell, GitHub Actions, Copilot, Docker, Prettier, ESLint |

After the script finishes, open a new terminal and run:

```powershell
git --version
node --version
npm --version
python --version
deno --version
gh --version
java --version
```

Flutter itself is intentionally not installed by the script because teams often
pin the SDK through FVM, a local SDK cache, or a managed corporate image. Use
the repository's current Flutter setup notes before adding a global SDK.

## Proxy troubleshooting

If install commands fail with DNS or proxy errors, first inspect the current
settings:

```powershell
Get-ChildItem Env:*proxy*
npm config get proxy
npm config get https-proxy
git config --global --get http.proxy
git config --global --get https.proxy
```

Clear user and process proxy variables:

```powershell
$names = @(
  'HTTP_PROXY',
  'HTTPS_PROXY',
  'ALL_PROXY',
  'NO_PROXY',
  'http_proxy',
  'https_proxy',
  'all_proxy',
  'no_proxy'
)

foreach ($name in $names) {
  [Environment]::SetEnvironmentVariable($name, $null, 'User')
  [Environment]::SetEnvironmentVariable($name, $null, 'Process')
  Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue
}
```

Clear npm and Git proxy config:

```powershell
npm config delete proxy
npm config delete https-proxy
git config --global --unset http.proxy
git config --global --unset https.proxy
```

Reset winget sources when package discovery is broken:

```powershell
winget source reset --force
winget source update
winget search Git.Git
```

Then retry the setup script:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1
```

## VS Code extension issues

If `code --install-extension` fails:

1. Open VS Code once.
2. Press `Ctrl+Shift+P`.
3. Run `Shell Command: Install 'code' command in PATH` if available.
4. Close and reopen PowerShell.
5. Retry with winget skipped:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1 -SkipWinget
```

If the extension gallery itself is blocked by a corporate proxy, clear proxy
settings as above and confirm VS Code has no stale `http.proxy` value in user
settings.

## Recovery checklist

- Run `scripts/setup_windows_dev.ps1 -DryRun` to confirm the planned steps.
- Run `scripts/setup_windows_dev.ps1 -ClearProxy -SkipVSCodeExtensions` if
  winget or npm fails before VS Code is available.
- Open a new terminal after installation so PATH changes are loaded.
- Run `gh auth login` before GitHub issue, PR, or Actions work.
- Run `flutter doctor` only after confirming the repository's Flutter SDK path.
