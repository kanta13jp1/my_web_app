# Win版#132 part 136: SessionStart hook — inject-rules.txt drift 自動修復 (Tier 1)
# AI_FLEET_SYNERGY Principle #5: Memory & State Continuity Hooks
# Fires when Claude Code session starts. Verifies canonical vs home, auto-applies if drift detected.
# Silent failure (= hook failure does not block session start).

param()

$ErrorActionPreference = "SilentlyContinue"

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = Get-Location }

$script = Join-Path $projectDir "scripts\sync_inject_rules.py"
$logDir  = Join-Path $projectDir "memory\inject-rules-sync"
$logFile = Join-Path $logDir ("sync-" + (Get-Date -Format "yyyyMMdd") + ".log")

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$entry = "[$timestamp] "

# Sanity check: script exists?
if (-not (Test-Path $script)) {
    Add-Content -Path $logFile -Value "${entry}skipped: scripts/sync_inject_rules.py not found"
    exit 0
}

# Try Python (= prefer python, fallback python3)
$python = "python"
if (-not (Get-Command $python -ErrorAction SilentlyContinue)) {
    $python = "python3"
    if (-not (Get-Command $python -ErrorAction SilentlyContinue)) {
        Add-Content -Path $logFile -Value "${entry}skipped: Python not found in PATH"
        exit 0
    }
}

# Step 1: --verify (= check drift)
$env:PYTHONUTF8 = "1"
$verifyOutput = & $python $script "--verify" "--json" 2>&1
$verifyExit = $LASTEXITCODE

if ($verifyExit -ne 0 -and $verifyExit -ne 1) {
    # exit 0 = ok / 1 = canonical KPI fail / 2 = canonical not found / other = unexpected
    Add-Content -Path $logFile -Value "${entry}verify failed (exit=$verifyExit): $verifyOutput"
    exit 0
}

# Parse drift status from JSON
try {
    $verifyJson = $verifyOutput -join "`n" | ConvertFrom-Json
} catch {
    Add-Content -Path $logFile -Value "${entry}verify JSON parse failed: $_"
    exit 0
}

$drift = $verifyJson.drift_between_canonical_and_home
$canonicalLines = $verifyJson.canonical.lines
$homeLines      = if ($verifyJson.home.lines) { $verifyJson.home.lines } else { 0 }

if ($drift -eq $false -or $drift -eq $null) {
    # No drift or no home file — nothing to do (= success)
    Add-Content -Path $logFile -Value "${entry}sync: drift=False (= no action / canonical=$canonicalLines / home=$homeLines)"
    exit 0
}

# Step 2: drift 検出 → --apply で自動修復
Add-Content -Path $logFile -Value "${entry}sync: drift detected — applying canonical → home"
$applyOutput = & $python $script "--apply" 2>&1
$applyExit = $LASTEXITCODE

if ($applyExit -eq 0) {
    Add-Content -Path $logFile -Value "${entry}sync: --apply success (canonical=$canonicalLines lines written to home)"
} else {
    Add-Content -Path $logFile -Value "${entry}sync: --apply failed (exit=$applyExit): $applyOutput"
}

exit 0
