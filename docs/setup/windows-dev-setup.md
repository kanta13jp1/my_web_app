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
| Core CLI | Git, GitHub CLI, Node.js LTS, Python 3.12, Deno, Podman |
| App tooling | Visual Studio Code, OpenJDK 17, AWS CLI |
| VS Code | Dart, Flutter, Deno, PowerShell, GitHub Actions, Copilot, Container Tools, Dev Containers, Prettier, ESLint |

After the script finishes, open a new terminal and run:

```powershell
git --version
node --version
npm --version
python --version
deno --version
gh --version
java --version
podman --version
```

Flutter itself is intentionally not installed by the script because teams often
pin the SDK through FVM, a local SDK cache, or a managed corporate image. Use
the repository's current Flutter setup notes before adding a global SDK.

The script installs the Podman CLI but does not create or start a Podman machine,
pull images, or change the active container runtime. Complete those host-changing
steps only after the resource and approval gates in
[`ROOTLESS_CONTAINER_SETUP.md`](../ROOTLESS_CONTAINER_SETUP.md) pass.

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

## VS Code integrated terminal launch failures

Use this sequence when a terminal fails before the shell prompt appears. Stop
as soon as the terminal works; do not add antivirus exclusions preemptively.

Start with the repository doctor. It is read-only by default and checks the
global `HKCU:\Console\ForceV2` legacy-console flag, the `wslconfig.exe /l`
default distribution (with a locale-neutral registry fallback), and old
`powershell` / `pwsh` / `wsl` launchers whose CPU time does not change during a
short sample:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows_terminal_doctor.ps1
```

Interpret the reported Windows codes precisely. `259` is the Win32
`STILL_ACTIVE` status returned while a process is still running, not evidence
by itself that the process is hung. `3221225786` (`0xC000013A`) is
`STATUS_CONTROL_C_EXIT`, commonly produced after Ctrl+C or console closure; it
does not prove that legacy-console mode caused the termination. Correlate the
code with the doctor findings and VS Code terminal trace before changing any
setting or stopping a process.

Use machine-readable output when attaching redacted evidence to an Issue:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows_terminal_doctor.ps1 -Json
```

An idle candidate is not proof that a process is hung. The doctor never stops
anything by default, excludes its own process ancestry, and never targets
`wslhost`, `wslservice`, `vmmem`, or Docker Desktop processes. Review the PID
and any unsaved terminal work first. To request a confirmation prompt for each
reported user-shell launcher, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/windows_terminal_doctor.ps1 -OfferStop -Confirm
```

Do not pass `-Confirm:$false` unless every listed PID has been independently
verified as disposable. The doctor only reports findings; the manual recovery
steps below remain the rollback-safe source of truth.

### 1. Confirm the default WSL distribution

Run both the current WSL command and the compatibility command requested by
older VS Code troubleshooting guidance:

```powershell
wsl.exe --list --verbose
wslconfig.exe /l
```

The current command marks the default distribution with `*`; older output can
show `(Default)`. The default must be an interactive Linux distribution such as
Ubuntu or Debian. Before changing it, record the exact name on the marked line
as the rollback value. Then set the intended installed distribution using the
current command:

```powershell
$targetDistro = 'Ubuntu' # Replace with the exact installed name from the list.
wsl.exe --set-default $targetDistro
```

Use the compatibility syntax instead only when the current command is not
available on an older WSL installation:

```powershell
$targetDistro = 'Ubuntu' # Replace with the exact installed name from the list.
wslconfig.exe /setdefault $targetDistro
```

Run `wsl.exe --list --verbose` again and then verify the selected distribution
without changing it further:

```powershell
wsl.exe --distribution $targetDistro -- echo WSL-ready
```

If the change does not fix the VS Code terminal or the machine needs its former
default, restore the name recorded before the change:

```powershell
$previousDefault = 'Debian' # Replace with the exact previously marked name.
wsl.exe --set-default $previousDefault

# Older WSL compatibility command, if required:
wslconfig.exe /setdefault $previousDefault
```

`docker-desktop` and the older `docker-desktop-data` entry are Docker Desktop
internal distributions, not developer login distributions. VS Code can exit
with code 1 when `docker-desktop-data` is selected as the default. Select a real
Linux distribution instead. Do **not** run `wsl --unregister` against either
Docker entry; that can remove Docker-managed state. Newer Docker Desktop
versions might not expose a separate `docker-desktop-data` entry at all.

### 2. Disable Windows compatibility mode for VS Code

1. Close every VS Code window.
2. Find the actual `Code.exe` from the Start menu or VS Code shortcut, choose
   **Open file location**, then open **Properties** for `Code.exe`.
3. On **Compatibility**, record the current checkbox and selected Windows
   version, then clear **Run this program in compatibility mode for**.
4. If **Change settings for all users** is available, check that page too; ask
   the device administrator before changing an organization-managed setting.
5. Apply the change and start VS Code normally, not with **Run as
   administrator**.

Compatibility emulation interferes with the low-level terminal process used by
VS Code. This step changes only the executable compatibility setting; it does
not change repository files or the selected shell. If it does not improve the
terminal, restore the recorded checkbox and Windows-version selection.

### 3. Disable legacy Windows Console mode

1. Open `cmd.exe` from the Start menu.
2. Right-click its title bar and choose **Properties**.
3. On **Options**, clear **Use legacy console** and select **OK**.
4. Close existing console and VS Code windows, then retry the integrated
   terminal.

The legacy-console choice applies to console sessions started afterward. If an
older command-line program genuinely requires it, restore the checkbox after
testing rather than changing unrelated registry values.

### 4. Add a narrow antivirus exclusion only after diagnosis

Use this only when VS Code reports a native exception and terminal trace or
antivirus protection history identifies `winpty`/`conpty` under VS Code's
bundled `node-pty` directory. First locate the active installation:

```powershell
$codeExe = Get-Process Code -ErrorAction Stop |
  Select-Object -First 1 -ExpandProperty Path
$installPath = Split-Path -Parent $codeExe
$nodePtyRelease = Join-Path $installPath `
  'resources\app\node_modules.asar.unpacked\node-pty\build\Release'
Get-ChildItem -LiteralPath $nodePtyRelease
```

After security-team approval, open **Windows Security > Virus & threat
protection > Manage settings > Add or remove exclusions** and add a **File**
exclusion only for an existing file implicated by the log:

```text
{install_path}\resources\app\node_modules.asar.unpacked\node-pty\build\Release\winpty.dll
{install_path}\resources\app\node_modules.asar.unpacked\node-pty\build\Release\winpty-agent.exe
{install_path}\resources\app\node_modules.asar.unpacked\node-pty\build\Release\conpty.node
{install_path}\resources\app\node_modules.asar.unpacked\node-pty\build\Release\conpty_console_list.node
```

Do not exclude the entire VS Code installation, user profile, repository,
extension directory, file type, or terminal process. An exclusion reduces
malware inspection and can be blocked by organization policy. Retry the
terminal, record which exact file fixed the issue, and remove the exclusion
after VS Code or antivirus updates resolve the false positive. For third-party
antivirus software, use its equivalent single-file procedure or ask the device
security owner.

### Evidence for a support request

Record the commands and outcome without copying tokens or environment-variable
values:

```powershell
code --version
wsl.exe --list --verbose
$PSVersionTable.PSVersion
```

In VS Code, run **Developer: Set Log Level > Trace**, reproduce the failure,
and attach only the relevant terminal log lines. Revert the log level after the
incident.

Official references:

- [VS Code: Troubleshoot terminal launch failures](https://code.visualstudio.com/docs/supporting/troubleshoot-terminal-launch)
- [Microsoft: Basic commands for WSL](https://learn.microsoft.com/windows/wsl/basic-commands)
- [Microsoft: Legacy Console mode](https://learn.microsoft.com/windows/console/legacymode)
- [Microsoft: `GetExitCodeProcess` and `STILL_ACTIVE`](https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-getexitcodeprocess)
- [Microsoft: `3221225786` / `STATUS_CONTROL_C_EXIT`](https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/misc-info)
- [Microsoft Defender Antivirus exclusions](https://learn.microsoft.com/defender-endpoint/microsoft-defender-antivirus-exclusions-overview)
- [Docker Desktop WSL 2 backend](https://docs.docker.com/desktop/features/wsl/)

## Recovery checklist

- Run `scripts/setup_windows_dev.ps1 -DryRun` to confirm the planned steps.
- Run `scripts/setup_windows_dev.ps1 -ClearProxy -SkipVSCodeExtensions` if
  winget or npm fails before VS Code is available.
- Open a new terminal after installation so PATH changes are loaded.
- Follow the VS Code terminal sequence above before changing antivirus or WSL
  state.
- Run `gh auth login` before GitHub issue, PR, or Actions work.
- Run `flutter doctor` only after confirming the repository's Flutter SDK path.
