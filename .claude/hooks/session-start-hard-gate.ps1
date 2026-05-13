# Issue #1564: v23 Layer JJ SessionStart compression gate.
# Runs the repo-managed session compression guard and optionally enforces the
# target when SESSION_COMPRESSION_FAIL_CLOSED=1 is set in the host environment.

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

$scriptPath = Join-Path $projectDir "scripts\session_compression_guard.py"
if (-not (Test-Path $scriptPath)) {
    Write-Output "[KPI] session compression guard missing: $scriptPath"
    exit 0
}

$pythonCommand = @(Resolve-PythonCommand)
if ($pythonCommand.Count -eq 0) {
    Write-Output "[KPI] python unavailable; session compression guard skipped"
    exit 0
}

$arguments = @(
    $scriptPath,
    "--mode", "session-start",
    "--root", $projectDir,
    "--banner",
    "--max-runtime-sec", "120",
    "--min-free-gb", "26",
    "--target-free-gb", "28"
)

if ($env:SESSION_COMPRESSION_DRY_RUN -ne "1") {
    $arguments += "--apply"
}
if ($env:SESSION_COMPRESSION_FAIL_CLOSED -eq "1") {
    $arguments += "--enforce"
}
if ($env:SESSION_COMPRESSION_TIER18 -eq "1") {
    $arguments += "--tier18"
}
if ($env:SESSION_COMPRESSION_TIER19 -eq "1") {
    $arguments += "--tier19"
}

$command = $pythonCommand[0]
$prefixArgs = @()
if ($pythonCommand.Count -gt 1) {
    $prefixArgs = $pythonCommand[1..($pythonCommand.Count - 1)]
}

& $command @prefixArgs @arguments
$exitCode = $LASTEXITCODE

if ($env:SESSION_COMPRESSION_FAIL_CLOSED -eq "1" -and $exitCode -ne 0) {
    exit $exitCode
}

exit 0
