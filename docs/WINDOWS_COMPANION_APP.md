# Windows Companion App

The Windows companion app is the local execution surface for smart cleanup workflows that cannot run inside the hosted web app.

## Build

```powershell
flutter config --enable-windows-desktop
git config --global core.longpaths true
flutter pub get
flutter build windows --release --no-tree-shake-icons --target lib/windows_companion_main.dart
```

The executable is created under:

```text
build\windows\x64\runner\Release\my_web_app.exe
```

## Portable Package

```powershell
New-Item -ItemType Directory -Force -Path build\windows\x64\runner\Release\scripts\SmartCleanup
Copy-Item tools\windows-companion\SmartCleanup\*.ps1 build\windows\x64\runner\Release\scripts\SmartCleanup -Force
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath dist\jibun-windows-companion.zip -Force
```

## MSIX Package

MSIX gives the companion app a normal Windows install/update surface. The
repository builds both:

- `jibun-windows-companion.msix`: signed Windows app package.
- `jibun-windows-companion.cer`: public certificate for self-signed builds.
- `jibun-windows-companion.zip`: portable fallback.

Local package command:

```powershell
.\tools\windows-companion\msix\New-WindowsCompanionMsix.ps1 `
  -ReleaseDir build\windows\x64\runner\Release `
  -OutputDir dist `
  -Version 1.0.0.0 `
  -Publisher 'CN=Jibun Windows Companion'
```

For production signing, configure these GitHub repository secrets:

```text
WINDOWS_MSIX_PFX_BASE64
WINDOWS_MSIX_PFX_PASSWORD
WINDOWS_MSIX_PUBLISHER
WINDOWS_MSIX_PUBLISHER_DISPLAY_NAME
```

`WINDOWS_MSIX_PUBLISHER` must match the certificate subject, for example
`CN=Jibun Windows Companion`.

If `WINDOWS_MSIX_PFX_BASE64` is not configured, the workflow creates a
self-signed certificate and publishes the `.cer` next to the `.msix`. The user
must trust that certificate before installing the MSIX.

## Release

Run the `Build Windows Companion App` workflow from GitHub Actions.

- Artifact only: run with `publish_release=false`.
- Site download link: run with `publish_release=true` and `release_tag=windows-companion-latest`.

The stable download URL used by the web app is:

```text
https://github.com/kanta13jp1/my_web_app/releases/download/windows-companion-latest/jibun-windows-companion.zip
```

The stable MSIX URL used by the web app is:

```text
https://github.com/kanta13jp1/my_web_app/releases/download/windows-companion-latest/jibun-windows-companion.msix
```

The public certificate URL for self-signed builds is:

```text
https://github.com/kanta13jp1/my_web_app/releases/download/windows-companion-latest/jibun-windows-companion.cer
```

## Safety Model

- The web app never deletes local files directly.
- The Windows app runs on the user's PC and can call local PowerShell scripts.
- Release ZIPs include the smart cleanup PowerShell scripts under `scripts\SmartCleanup`.
- Cleanup must follow: scan, review CSV, approve rows, apply approved rows, save result logs.
- Approved cleanup should move files to the Recycle Bin, not permanently delete them.
