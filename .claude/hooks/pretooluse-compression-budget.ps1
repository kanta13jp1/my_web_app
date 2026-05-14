# Issue #1564: v23 Layer KK PreToolUse compression budget.
# Tracks tool-use count and records every 10th-tool KPI snapshot. When C: free
# space is below the aggressive threshold, it runs a capped non-blocking cleanup.

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
    Write-Output "[KPI] python unavailable; pretooluse compression skipped"
    exit 0
}

$arguments = @(
    $scriptPath,
    "--mode", "pretooluse",
    "--root", $projectDir,
    "--apply",
    "--quiet",
    "--tool-budget-interval", "10",
    "--aggressive-free-gb", "22",
    "--max-mid-fires", "5",
    "--max-runtime-sec", "30"
)

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
exit 0
