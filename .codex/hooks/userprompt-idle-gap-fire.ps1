# Issue #1564: v23 Layer MM UserPromptSubmit idle-gap auto-fire.
# Performs a short cleanup when the last compression fire is older than the
# idle-gap threshold. Cooldown prevents repeated fires during active work.

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
    Write-Output "[KPI] python unavailable; idle-gap compression skipped"
    exit 0
}

$arguments = @(
    $scriptPath,
    "--mode", "userprompt",
    "--root", $projectDir,
    "--apply",
    "--quiet",
    "--max-age-minutes", "30",
    "--cooldown-minutes", "60",
    "--max-runtime-sec", "30"
)

$command = $pythonCommand[0]
$prefixArgs = @()
if ($pythonCommand.Count -gt 1) {
    $prefixArgs = $pythonCommand[1..($pythonCommand.Count - 1)]
}

& $command @prefixArgs @arguments
exit 0
