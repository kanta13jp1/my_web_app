<#
.SYNOPSIS
Installs the baseline Windows developer tools for my_web_app.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_dev.ps1 -ClearProxy -DryRun
#>

[CmdletBinding()]
param(
    [switch]$SkipWinget,
    [switch]$SkipVSCodeExtensions,
    [switch]$ClearProxy,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProxyVariables = @(
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "NO_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
    "no_proxy"
)

$WingetPackages = @(
    @{ Id = "Git.Git"; Name = "Git" },
    @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
    @{ Id = "OpenJS.NodeJS.LTS"; Name = "Node.js LTS" },
    @{ Id = "EclipseAdoptium.Temurin.17.JDK"; Name = "OpenJDK 17" },
    @{ Id = "Python.Python.3.12"; Name = "Python 3.12" },
    @{ Id = "Amazon.AWSCLI"; Name = "AWS CLI" },
    @{ Id = "GitHub.cli"; Name = "GitHub CLI" },
    @{ Id = "DenoLand.Deno"; Name = "Deno" },
    @{ Id = "RedHat.Podman"; Name = "Podman" }
)

$VSCodeExtensions = @(
    "Dart-Code.dart-code",
    "Dart-Code.flutter",
    "denoland.vscode-deno",
    "ms-vscode.powershell",
    "GitHub.vscode-github-actions",
    "GitHub.copilot",
    "GitHub.copilot-chat",
    "ms-azuretools.vscode-containers",
    "ms-vscode-remote.remote-containers",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint"
)

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-SetupStep {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Write-Section $Description
    if ($DryRun) {
        Write-Host "[dry-run] $Description"
        return
    }

    try {
        & $Action
    } catch {
        Write-Host "[failed] $Description" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "See docs/setup/windows-dev-setup.md for proxy troubleshooting." -ForegroundColor Yellow
        throw
    }
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Clear-ProxyConfiguration {
    Invoke-SetupStep "Clear proxy environment variables and package-manager proxy settings" {
        foreach ($name in $ProxyVariables) {
            [Environment]::SetEnvironmentVariable($name, $null, "User")
            [Environment]::SetEnvironmentVariable($name, $null, "Process")
            Remove-Item -LiteralPath "Env:\$name" -ErrorAction SilentlyContinue
            Write-Host "cleared $name"
        }

        if (Test-CommandExists "npm") {
            npm config delete proxy | Out-Host
            npm config delete https-proxy | Out-Host
        }

        if (Test-CommandExists "git") {
            git config --global --unset http.proxy 2>$null
            git config --global --unset https.proxy 2>$null
        }
    }
}

function Test-WingetPackageInstalled {
    param([string]$PackageId)

    $output = winget list --id $PackageId --exact 2>$null | Out-String
    return ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($PackageId))
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$PackageName
    )

    Invoke-SetupStep "Install $PackageName ($PackageId)" {
        if (Test-WingetPackageInstalled $PackageId) {
            Write-Host "$PackageName is already installed."
            return
        }

        winget install `
            --id $PackageId `
            --exact `
            --silent `
            --accept-package-agreements `
            --accept-source-agreements
    }
}

function Install-VSCodeExtension {
    param([string]$ExtensionId)

    Invoke-SetupStep "Install VS Code extension $ExtensionId" {
        if (-not (Test-CommandExists "code")) {
            Write-Host "VS Code CLI 'code' is not on PATH. Open VS Code once and run 'Shell Command: Install code command in PATH' if needed." -ForegroundColor Yellow
            return
        }

        code --install-extension $ExtensionId --force
    }
}

function Show-VersionSummary {
    Write-Section "Version summary"
    $commands = @("git", "node", "npm", "python", "deno", "gh", "aws", "java", "code", "podman")
    foreach ($command in $commands) {
        if (-not (Test-CommandExists $command)) {
            Write-Host "${command}: not found" -ForegroundColor Yellow
            continue
        }

        try {
            $line = (& $command --version 2>$null | Select-Object -First 1)
            Write-Host "${command}: $line"
        } catch {
            Write-Host "${command}: installed, version check failed" -ForegroundColor Yellow
        }
    }
}

Write-Section "my_web_app Windows developer setup"
Write-Host "DryRun: $DryRun"
Write-Host "SkipWinget: $SkipWinget"
Write-Host "SkipVSCodeExtensions: $SkipVSCodeExtensions"
Write-Host "ClearProxy: $ClearProxy"

if ($ClearProxy) {
    Clear-ProxyConfiguration
}

if (-not $SkipWinget) {
    if (-not $DryRun -and -not (Test-CommandExists "winget")) {
        throw "winget is not available. Install App Installer from Microsoft Store first."
    }

    foreach ($package in $WingetPackages) {
        Install-WingetPackage -PackageId $package["Id"] -PackageName $package["Name"]
    }
}

if (-not $SkipVSCodeExtensions) {
    foreach ($extension in $VSCodeExtensions) {
        Install-VSCodeExtension -ExtensionId $extension
    }
}

if ($DryRun) {
    Write-Section "Version summary"
    Write-Host "[dry-run] skipped version checks"
} else {
    Show-VersionSummary
}

Write-Section "Done"
Write-Host "Next: run 'flutter doctor', 'dart --version', and 'deno --version' after opening a new terminal."
