# Issue #1564: SessionStart state check for two-instance recovery.
# Logs branch/worktree drift, ahead/behind, dirty paths, unpushed commits,
# and the next quality gate without blocking the host session.

param()

$ErrorActionPreference = "SilentlyContinue"

function Invoke-GitText {
    param(
        [string]$ProjectDir,
        [string[]]$Arguments
    )

    $output = & git -C $ProjectDir @Arguments 2>$null
    if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
        return ""
    }

    return ($output -join "`n").Trim()
}

function Add-SessionLog {
    param(
        [string]$Path,
        [string]$Message
    )

    Add-Content -Path $Path -Value $Message -ErrorAction SilentlyContinue
}

function Get-FirstNonEmptyLine {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return ""
    }

    $line = Get-Content -Path $Path -ErrorAction SilentlyContinue |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1
    if ($null -eq $line) {
        return ""
    }
    return $line.Trim()
}

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

$logDir = Join-Path $projectDir "memory\session-start-check"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$logFile = Join-Path $logDir ("session-start-" + (Get-Date -Format "yyyyMMdd") + ".log")
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$entry = "[$timestamp]"

try {
    $branch = Invoke-GitText $projectDir @("branch", "--show-current")
    $headSha = Invoke-GitText $projectDir @("rev-parse", "--short", "HEAD")
    $root = Invoke-GitText $projectDir @("rev-parse", "--show-toplevel")
    $upstream = Invoke-GitText $projectDir @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")

    Add-SessionLog $logFile "$entry session-start: project=$projectDir root=$root branch=$branch head=$headSha"
    Add-SessionLog $logFile "$entry policy: active instances are Win Claude + Win Codex only; old Codex #2/#3 lanes stay dormant."

    $instance = $env:CLAUDE_INSTANCE
    if (-not $instance) {
        if ($branch -match '^(codex|codex1)/') {
            $instance = "win-codex"
        } elseif ($branch -match '^claude/') {
            $instance = "win-claude"
        } else {
            $instance = "unknown"
        }
    }

    $expectedPrefixes = @()
    if ($instance -match 'codex') {
        $expectedPrefixes = @("codex/", "codex1/")
    } elseif ($instance -match 'claude') {
        $expectedPrefixes = @("claude/")
    }

    if ($expectedPrefixes.Count -gt 0) {
        $matchesPrefix = $false
        foreach ($prefix in $expectedPrefixes) {
            if ($branch.StartsWith($prefix)) {
                $matchesPrefix = $true
                break
            }
        }
        if (-not $matchesPrefix) {
            Add-SessionLog $logFile "$entry WARN branch=$branch expected_prefix=$($expectedPrefixes -join ',') instance=$instance"
        }
    }

    if ($branch -match '^(codex2|codex3|old-codex|ps[0-9]+)/') {
        Add-SessionLog $logFile "$entry WARN dormant instance branch prefix detected: $branch"
    }

    if ($upstream) {
        $counts = Invoke-GitText $projectDir @("rev-list", "--left-right", "--count", "HEAD...$upstream")
        if ($counts) {
            $parts = $counts -split "\s+"
            if ($parts.Count -ge 2) {
                $ahead = [int]$parts[0]
                $behind = [int]$parts[1]
                Add-SessionLog $logFile "$entry upstream=$upstream ahead=$ahead behind=$behind"
                if ($ahead -gt 0) {
                    Add-SessionLog $logFile "$entry WARN unpushed_commits=$ahead upstream=$upstream"
                }
                if ($behind -gt 0) {
                    Add-SessionLog $logFile "$entry WARN branch_behind=$behind upstream=$upstream"
                }
            }
        }
    } else {
        Add-SessionLog $logFile "$entry WARN branch has no upstream"
    }

    $dirtyText = Invoke-GitText $projectDir @("status", "--short")
    $dirty = @($dirtyText -split "`n" | Where-Object { $_.Trim() })
    if ($dirty.Count -gt 0) {
        Add-SessionLog $logFile "$entry WARN dirty_paths=$($dirty.Count)"
        foreach ($line in ($dirty | Select-Object -First 20)) {
            Add-SessionLog $logFile "$entry dirty: $line"
        }
    }

    $gateFile = Join-Path $projectDir "memory\next-quality-gate.txt"
    $nextGate = Get-FirstNonEmptyLine $gateFile
    if ($nextGate) {
        Add-SessionLog $logFile "$entry next_quality_gate=$nextGate"
    } else {
        Add-SessionLog $logFile "$entry WARN next_quality_gate missing"
    }

    $script = Join-Path $projectDir "scripts\codex_session_check.py"
    if (Test-Path $script) {
        $python = "python"
        if (-not (Get-Command $python -ErrorAction SilentlyContinue)) {
            $python = "python3"
        }
        if (Get-Command $python -ErrorAction SilentlyContinue) {
            $env:PYTHONUTF8 = "1"
            $checkOutput = & $python $script "--json" 2>&1
            $checkExit = $LASTEXITCODE
            Add-SessionLog $logFile "$entry codex_session_check_exit=$checkExit"
            foreach ($line in ($checkOutput | Select-Object -First 120)) {
                Add-SessionLog $logFile $line
            }
        } else {
            Add-SessionLog $logFile "$entry WARN python unavailable; codex_session_check skipped"
        }
    } else {
        Add-SessionLog $logFile "$entry WARN scripts/codex_session_check.py missing"
    }
} catch {
    Add-SessionLog $logFile "$entry WARN session-start-state-check failed: $_"
}

exit 0
