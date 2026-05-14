# Issue #1564: v23 Layer LL SessionEnd/wrap-up auto-compress.
# Runs a deterministic wrap-up compression pass. It is advisory by default and
# only fails closed when SESSION_COMPRESSION_WRAPUP_ENFORCE=1 is set.

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
    Write-Output "[KPI] python unavailable; wrap-up compression skipped"
    exit 0
}

$arguments = @(
    $scriptPath,
    "--mode", "wrap-up",
    "--root", $projectDir,
    "--apply",
    "--banner",
    "--target-free-gb", "28",
    "--max-runtime-sec", "120"
)

if ($env:SESSION_COMPRESSION_WRAPUP_ENFORCE -eq "1") {
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

if ($env:SESSION_COMPRESSION_WRAPUP_ENFORCE -eq "1" -and $exitCode -ne 0) {
    exit $exitCode
}

exit 0
