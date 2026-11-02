# VS Code Terminal Troubleshooting Guide

Status: repo-managed wiki page for Issues #1294, #2856, and #2857.

This guide standardizes first-response checks when the VS Code integrated
terminal fails to start, exits immediately, or returns a shell exit code before
development can begin.

## Scope

Use this guide for local developer machines only.

- Windows 11 + PowerShell / cmd / Git Bash terminals
- VS Code integrated terminal startup failures
- Shell exit codes, profile errors, proxy remnants, and extension conflicts

Do not paste secrets, tokens, or full `.env` values into logs, GitHub Issues, or
Slack. Redact environment variables before sharing evidence.

## 1. Direct Shell Test Outside VS Code

First prove whether the shell itself works without VS Code.

### PowerShell

Open Windows Terminal or `pwsh.exe` directly and run:

```powershell
$PSVersionTable.PSVersion
Write-Output "shell-ok"
exit $LASTEXITCODE
```

Then test a clean profile-free launch:

```powershell
pwsh -NoLogo -NoProfile -Command "$PSVersionTable.PSVersion; 'profile-free-ok'"
```

If `-NoProfile` works but a normal shell fails, inspect the profile files:

```powershell
$PROFILE | Format-List * -Force
Test-Path $PROFILE
notepad $PROFILE
```

Temporarily move risky profile customizations out of the way and retry VS Code.

### cmd

```cmd
cmd /d /c echo shell-ok
cmd /d /c ver
```

`/d` disables AutoRun commands. If `/d` works and normal `cmd` fails, inspect
the `Command Processor` AutoRun registry values.

### Git Bash

```powershell
where.exe bash
bash --noprofile --norc -lc "echo shell-ok"
```

If profile-free Git Bash works, inspect `.bashrc`, `.bash_profile`, and any
toolchain initialization scripts added by Git, Node, Python, Flutter, or
Supabase tooling.

## 2. Enable VS Code Trace Logging

When the external shell works, collect VS Code evidence.

1. Open the Command Palette.
2. Run `Developer: Set Log Level...`.
3. Choose `Trace`.
4. Open `Terminal: Create New Terminal`.
5. Run `Developer: Open Logs Folder`.
6. Inspect the latest `window.log`, `exthost.log`, and terminal-related logs.

Look for:

- the shell executable path VS Code selected
- command-line arguments such as `-NoProfile`, `--login`, or `-l`
- extension activation errors before terminal startup
- proxy, permission, or path lookup errors
- an exit code reported immediately after shell launch

Reset the log level to `Info` after collecting evidence so local logs do not
grow unnecessarily.

## 3. Check VS Code Terminal Settings

Inspect workspace and user settings for terminal overrides:

```powershell
code --user-data-dir "$env:TEMP\vscode-terminal-check" --disable-extensions .
```

If a clean VS Code profile works, compare these settings in the normal profile:

- `terminal.integrated.defaultProfile.windows`
- `terminal.integrated.profiles.windows`
- `terminal.integrated.automationProfile.windows`
- `terminal.integrated.env.windows`
- `terminal.integrated.shellIntegration.enabled`
- `http.proxy`
- `npm.proxy` / `npm.https-proxy` in `.npmrc`

Also try the normal profile with extensions disabled:

```powershell
code --disable-extensions .
```

If this works, re-enable extensions in small batches. Terminal, shell
integration, environment, Docker, remote development, and AI coding extensions
are the first suspects.

### Repository split-terminal standard

This repository pins the following workspace behavior in
`.vscode/settings.json`:

```json
{
  "terminal.integrated.cwd": "${workspaceFolder}",
  "terminal.integrated.splitCwd": "workspaceRoot"
}
```

`workspaceRoot` is intentional. A split made from a terminal that has moved
into `supabase/`, `web/`, or another subdirectory starts at the repository
root, so Flutter and Supabase commands do not silently run against different
project roots. In a multi-root workspace VS Code asks which root to use.

Do not add `terminal.integrated.inheritEnv` to the workspace file. Current VS
Code defines it as an application-scoped user setting with a default of
`true`; it cannot be standardized per workspace, and it has no effect on
Windows. On macOS and Linux, developers who changed the user setting to
`false` should restore it to `true` unless they intentionally need a stripped
shell environment.

The behavior above follows the current VS Code
[split-terminal documentation](https://code.visualstudio.com/docs/terminal/basics#_groups-split-panes)
and the official
[`inheritEnv` configuration schema](https://github.com/microsoft/vscode/blob/main/src/vs/platform/terminal/common/terminalPlatformConfiguration.ts).

After changing either the user setting or the workspace settings, close the
old terminals, open a new terminal, split it, and compare both panes:

```powershell
# Windows PowerShell (run in both panes)
(Get-Location).Path
$env:Path
$env:PYTHONUTF8
Get-Command flutter
Get-Command supabase
```

```bash
# macOS/Linux (run in both panes)
pwd
printf '%s\n' "$PATH" "$PYTHONUTF8"
command -v flutter
command -v supabase
```

Both panes must start at the repository root. `PATH`, `PYTHONUTF8`, and command
resolution must agree. If they do not, compare the VS Code user setting,
login-shell profile, and `terminal.integrated.env.{platform}` before changing
the repository settings.

### Recommended Flutter + Supabase layout

Use one terminal group split into three panes. Keep each pane at the workspace
root and let each CLI discover its own project files.

| Pane | Long-running owner | Typical commands |
| --- | --- | --- |
| Left | Supabase local stack / functions | `supabase start`, `supabase status`, `supabase functions serve` |
| Top right | Flutter daemon | `flutter run -d chrome` |
| Bottom right | Short checks and logs | `flutter test <target>`, `supabase functions logs <name>` |

Do not place tokens or `.env` values in `.vscode/settings.json`. Load secrets
through the existing local environment or approved secret workflow instead.

## 4. Endpoint Security and Least-Privilege Policy

The normal operating state is **VS Code and every integrated shell running as a
standard user**. Do not run the editor, Git, Flutter, Supabase, development
servers, or repository tests as administrator. Use elevation only for a bounded
operating-system task such as an approved installer, driver, or centrally
managed security policy change; close that elevated process immediately after
the task.

If a terminal executable is configured to always elevate, open its Properties,
clear **Run this program as administrator**, and retry from a non-elevated VS
Code window. If workspace or tool directories require administrator access,
ask IT to repair their ownership/ACLs instead of permanently elevating the
editor. This follows Microsoft's UAC model: routine applications run with a
standard-user token and request elevation only for the specific operation that
needs it.

Confirm the current PowerShell is not elevated:

```powershell
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
```

The expected result for normal development is `False`.

### Antivirus or EDR exception approval

An antivirus exception is a protection gap, not a routine setup step. A
developer must not add one speculatively or disable Microsoft Defender,
real-time protection, network protection, Attack Surface Reduction, or the
organization's EDR agent.

Use this approval sequence only after sections 1–3 have ruled out shell,
profile, setting, and extension causes:

1. Reproduce the native terminal exception on a fully updated OS and VS Code,
   with extensions disabled, and retain a redacted Trace log.
2. Confirm the matching block in Windows Security **Protection history** or the
   managed EDR console. A timing correlation without a product detection event
   is not sufficient.
3. Resolve the actual VS Code install path. For each detected component, record
   its full path, SHA-256 hash, Authenticode signer, VS Code version, device,
   ticket, approver, reason, creation time, expiry time, and rollback owner:

   ```powershell
   Get-AuthenticodeSignature -LiteralPath '<exact detected file>' |
     Select-Object Status, StatusMessage, SignerCertificate
   Get-FileHash -Algorithm SHA256 -LiteralPath '<exact detected file>'
   ```

4. Prefer updating VS Code/security intelligence, correcting the vendor false
   positive, or using an approved file indicator. If an exception is still
   required, the endpoint-security owner—not the developer—must deploy the
   narrowest product-supported, time-bound exception to a pilot device first.
5. Verify that a non-elevated VS Code terminal starts, normal protection stays
   enabled, and unrelated files are still scanned. Remove the exception and
   retest after the next VS Code or security-product update; changed hashes or
   paths require a new review.

VS Code's official native-exception guidance currently identifies only these
files below the active installation's
`resources\app\node_modules.asar.unpacked\node-pty\build\Release` directory:

- `winpty.dll`
- `winpty-agent.exe`
- `conpty.node`
- `conpty_console_list.node`

Treat that list as investigation candidates, not a blanket allowlist. Approve
only the exact file that the security product demonstrably blocked. Never allow
the whole VS Code install directory, `node_modules`, a file extension, the
workspace, the user profile, `Code.exe`, `powershell.exe`, `pwsh.exe`, or
`cmd.exe`. A process exclusion is especially broad because it can also reduce
network-protection and ASR inspection. Certificate/publisher rules are allowed
only when the managed EDR product can also constrain product and path and the
endpoint-security owner documents why an exact-file rule is insufficient.

For third-party antivirus products, use the vendor's managed administration
console and false-positive process. Apply the same evidence, exact-target,
pilot, expiry, verification, and rollback requirements; do not translate this
guide into an unreviewed consumer-console click path.

Authoritative references:

- [VS Code: Troubleshoot Terminal launch failures](https://code.visualstudio.com/docs/supporting/troubleshoot-terminal-launch)
- [Microsoft Defender Antivirus exclusions](https://learn.microsoft.com/defender-endpoint/configure-contextual-file-folder-exclusions-microsoft-defender-antivirus)
- [Microsoft: User Account Control](https://learn.microsoft.com/windows/security/application-security/application-control/user-account-control/)
- [Microsoft: Local accounts](https://learn.microsoft.com/windows/security/identity-protection/access-control/local-accounts)

## 5. Exit Code Reading Guide

Record the exact exit code, shell, and launch command.

| Exit code | Usual meaning | First check |
| --- | --- | --- |
| `0` | Shell exited successfully | Profile or task may be closing it intentionally |
| `1` | General shell/script failure | Profile script, missing command, or syntax error |
| `2` | CLI argument or usage error | VS Code terminal profile args |
| `126` | Command found but not executable | File permissions or blocked executable |
| `127` | Command not found | PATH, shell path, or tool uninstall |
| `130` | Interrupted by Ctrl+C/SIGINT | User interrupt or extension cancellation |
| `3221225781` | Windows missing DLL / dependency | Reinstall shell/toolchain and inspect Event Viewer |

For PowerShell-specific failures, also capture:

```powershell
$LASTEXITCODE
$Error[0] | Format-List * -Force
Get-ExecutionPolicy -List
```

## 6. Search Known Issues

Search by shell, OS, exit code, and VS Code terminal component.

Useful queries:

```text
site:github.com/microsoft/vscode/issues "terminal.integrated" "exit code 1" PowerShell Windows
site:github.com/microsoft/vscode/issues "terminal.integrated" "process exited" "3221225781"
site:github.com/PowerShell/PowerShell/issues "VS Code" "NoProfile" "exit code"
site:github.com/git-for-windows/git/issues "VS Code terminal" bash "exited"
```

When opening a repo issue, include:

- VS Code version and commit
- OS version
- shell executable path
- terminal profile settings
- direct shell test result
- trace log excerpt with secrets redacted
- exact exit code

## 7. Recovery Decision Tree

1. **External shell fails**: fix shell install, PATH, profile, or permissions.
2. **External shell works, VS Code clean profile works**: normal profile setting
   or extension is the likely cause.
3. **External shell works, clean VS Code fails**: collect trace logs and search
   VS Code issues by exit code.
4. **Only this repo fails**: inspect `.vscode/`, workspace settings, tasks, and
   repo-specific environment variables.
5. **Network/proxy errors appear**: follow
   [`DEV_ENV_SETUP_GUIDE.md`](DEV_ENV_SETUP_GUIDE.md) section 4 before changing
   terminal profiles.

## 8. Minimal Evidence Template

```markdown
## VS Code terminal failure

- OS:
- VS Code version:
- Shell:
- Exit code:
- External shell test:
- `-NoProfile` / profile-free test:
- `code --disable-extensions` result:
- Relevant terminal settings:
- Redacted trace log excerpt:
- Protection-history / EDR event ID (if security software is suspected):
- Exact blocked path, SHA-256, signer, and product version:
- Exception ticket, approver, expiry, and rollback owner (if approved):
- Suspected cause:
```
