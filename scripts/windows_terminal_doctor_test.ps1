$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
. (Join-Path $repoRoot "scripts\windows_terminal_doctor.ps1")

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )
    if ($Actual -ne $Expected) {
        throw "$Message. Expected '$Expected', got '$Actual'."
    }
}

$legacy = Get-LegacyConsoleAssessment -ForceV2 0
Assert-Equal $legacy.IsLegacy $true "ForceV2=0 must be reported as legacy"
Assert-Equal $legacy.Status "legacy-enabled" "Legacy status mismatch"

$modern = Get-LegacyConsoleAssessment -ForceV2 1
Assert-Equal $modern.IsLegacy $false "ForceV2=1 must be modern"

$englishWsl = @"
Windows Subsystem for Linux Distributions:
Ubuntu (Default)
docker-desktop
"@
$wsl = Get-WslDefaultAssessment -WslConfigOutput $englishWsl -RegistryDefault "Debian"
Assert-Equal $wsl.DefaultDistribution "Ubuntu" "wslconfig output must win over fallback"
Assert-Equal $wsl.IsDockerInternal $false "Ubuntu must be accepted"

$nulSeparatedWsl = "d`0o`0c`0k`0e`0r`0-`0d`0e`0s`0k`0t`0o`0p`0-`0d`0a`0t`0a`0 `0(`0D`0e`0f`0a`0u`0l`0t`0)`0"
$dockerWsl = Get-WslDefaultAssessment -WslConfigOutput $nulSeparatedWsl -RegistryDefault $null
Assert-Equal $dockerWsl.DefaultDistribution "docker-desktop-data" "UTF-16-style NULs must be removed"
Assert-Equal $dockerWsl.IsDockerInternal $true "Docker data distro must be rejected as default"

$fallbackWsl = Get-WslDefaultAssessment -WslConfigOutput "header only" -RegistryDefault "Debian"
Assert-Equal $fallbackWsl.DefaultDistribution "Debian" "Registry fallback must be used for localized output"

$now = [datetime]"2026-08-27T04:00:00Z"
$first = @(
    [pscustomobject]@{ Name = "pwsh.exe"; ProcessId = 10; ParentProcessId = 1; CreationTime = $now.AddHours(-4); CpuTicks = 100 },
    [pscustomobject]@{ Name = "powershell.exe"; ProcessId = 11; ParentProcessId = 1; CreationTime = $now.AddHours(-4); CpuTicks = 100 },
    [pscustomobject]@{ Name = "wsl.exe"; ProcessId = 12; ParentProcessId = 1; CreationTime = $now.AddMinutes(-5); CpuTicks = 100 },
    [pscustomobject]@{ Name = "wslhost.exe"; ProcessId = 13; ParentProcessId = 1; CreationTime = $now.AddHours(-4); CpuTicks = 100 }
)
$second = @(
    [pscustomobject]@{ Name = "pwsh.exe"; ProcessId = 10; ParentProcessId = 1; CreationTime = $now.AddHours(-4); CpuTicks = 100 },
    [pscustomobject]@{ Name = "powershell.exe"; ProcessId = 11; ParentProcessId = 1; CreationTime = $now.AddHours(-4); CpuTicks = 101 },
    [pscustomobject]@{ Name = "wsl.exe"; ProcessId = 12; ParentProcessId = 1; CreationTime = $now.AddMinutes(-5); CpuTicks = 100 },
    [pscustomobject]@{ Name = "wslhost.exe"; ProcessId = 13; ParentProcessId = 1; CreationTime = $now.AddHours(-4); CpuTicks = 100 }
)
$candidates = @(
    Get-StaleShellProcessCandidates `
        -FirstSnapshot $first `
        -SecondSnapshot $second `
        -Now $now `
        -MinimumAgeMinutes 120 `
        -ProtectedProcessIds @()
)
Assert-Equal $candidates.Count 1 "Only old CPU-idle user shell launchers may be candidates"
Assert-Equal $candidates[0].ProcessId 10 "Unexpected idle candidate"

$protected = @(
    Get-StaleShellProcessCandidates `
        -FirstSnapshot $first `
        -SecondSnapshot $second `
        -Now $now `
        -MinimumAgeMinutes 120 `
        -ProtectedProcessIds @(10)
)
Assert-Equal $protected.Count 0 "The active process ancestry must be protected"

Write-Host "windows_terminal_doctor_test: PASS"
