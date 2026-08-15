# Issue #1564: v27 Layer GGG SmartCleanup_MonthlyDeep stuck guard.
# Reports the 1999 LastRunTime / 267011 never-ran failure mode. It only starts
# the task when SMARTCLEANUP_MONTHLYDEEP_FIX=1 is set.

param()

$ErrorActionPreference = "SilentlyContinue"

function Resolve-PythonCommand {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        return @($python.Source)
    }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py) {
        return @($py.Source, "-3")
    }

    return @()
}

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

$scriptPath = Join-Path $projectDir "scripts\smartcleanup_task_guard.py"
if (-not (Test-Path $scriptPath)) {
    Write-Output "[KPI] SmartCleanup guard missing: $scriptPath"
    exit 0
}

$pythonCommand = @(Resolve-PythonCommand)
if ($pythonCommand.Count -eq 0) {
    Write-Output "[KPI] python unavailable; SmartCleanup guard skipped"
    exit 0
}

$arguments = @(
    $scriptPath,
    "--task-name", "SmartCleanup_MonthlyDeep",
    "--max-age-days", "35"
)

if ($env:SMARTCLEANUP_MONTHLYDEEP_FIX -eq "1") {
    $arguments += "--fix"
}
if ($env:SMARTCLEANUP_MONTHLYDEEP_ENFORCE -eq "1") {
    $arguments += "--enforce"
}

$command = $pythonCommand[0]
$prefixArgs = @()
if ($pythonCommand.Count -gt 1) {
    $prefixArgs = $pythonCommand[1..($pythonCommand.Count - 1)]
}

& $command @prefixArgs @arguments
$exitCode = $LASTEXITCODE

if ($env:SMARTCLEANUP_MONTHLYDEEP_ENFORCE -eq "1" -and $exitCode -ne 0) {
    exit $exitCode
}

exit 0
