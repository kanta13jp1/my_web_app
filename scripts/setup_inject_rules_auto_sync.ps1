# Win版#132 part 136 — Tier 2: Windows Task Scheduler setup for inject-rules.txt auto sync
#
# 1-shot installer that creates a daily 03:30 JST Windows Task running:
#   git -C <repo> pull origin main
#   python <repo>\scripts\sync_inject_rules.py --apply
#
# Idempotent: re-running with --install replaces existing task.
# Safety: Tier 2 catches drift when Claude Code session-start hook (Tier 1) has not run for >24h
# (= Codex CLI sessions, dormant fleet, etc).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup_inject_rules_auto_sync.ps1 -Install
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup_inject_rules_auto_sync.ps1 -Status
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup_inject_rules_auto_sync.ps1 -Uninstall

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status,
    [string]$RepoPath = "C:\Users\kanta\GitHub\my_web_app",
    [string]$TaskName = "JibunKK-InjectRulesAutoSync",
    [string]$TriggerTime = "03:30"
)

if (-not ($Install -or $Uninstall -or $Status)) {
    Write-Host "Usage: -Install | -Uninstall | -Status [-RepoPath <path>] [-TaskName <name>] [-TriggerTime HH:MM]"
    exit 1
}

if ($Status) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "Task '$TaskName' is INSTALLED."
        $info = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Host "  Last run    : $($info.LastRunTime)"
        Write-Host "  Last result : $($info.LastTaskResult)"
        Write-Host "  Next run    : $($info.NextRunTime)"
        $task.Triggers | ForEach-Object { Write-Host "  Trigger     : $($_.StartBoundary)" }
    } else {
        Write-Host "Task '$TaskName' is NOT installed."
    }
    exit 0
}

if ($Uninstall) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Task '$TaskName' UNINSTALLED."
    } else {
        Write-Host "Task '$TaskName' was not installed."
    }
    exit 0
}

if ($Install) {
    if (-not (Test-Path $RepoPath)) {
        Write-Error "Repo path not found: $RepoPath"
        exit 2
    }
    $script = Join-Path $RepoPath "scripts\sync_inject_rules.py"
    if (-not (Test-Path $script)) {
        Write-Error "Sync script not found: $script"
        exit 3
    }

    # Build inline command:
    # 1. cd to repo
    # 2. git pull origin main (silent fail OK / sync still runs)
    # 3. python sync_inject_rules.py --apply
    # 4. Append exit code + timestamp to log
    $logDir = Join-Path $RepoPath "memory\inject-rules-sync"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $cmd = @"
`$ErrorActionPreference = 'Continue'
`$env:PYTHONUTF8 = '1'
Set-Location '$RepoPath'
git pull origin main 2>&1 | Out-Null
`$out = & python '$script' --apply 2>&1
`$exit = `$LASTEXITCODE
`$logFile = Join-Path '$logDir' ('cron-' + (Get-Date -Format 'yyyyMMdd') + '.log')
`$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Add-Content -Path `$logFile -Value ('[' + `$ts + '] cron --apply exit=' + `$exit + ' / output: ' + (`$out -join ' | '))
"@

    # PowerShell command-line wrapper
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""

    # Daily trigger at specified time (= local timezone)
    $trigger = New-ScheduledTaskTrigger -Daily -At $TriggerTime

    # Run as current user, only when user is logged on (= simpler / no service account needed)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -MultipleInstances IgnoreNew

    # Replace existing task if present
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "自分株式会社 / Win版#132 part 136 — inject-rules.txt drift 自動修復 (Tier 2)" | Out-Null

    Write-Host "✅ Task '$TaskName' INSTALLED."
    Write-Host "   Repo        : $RepoPath"
    Write-Host "   Trigger     : daily $TriggerTime (local timezone)"
    Write-Host "   Log         : $logDir\cron-YYYYMMDD.log"
    Write-Host ""
    Write-Host "Verify: powershell -File scripts/setup_inject_rules_auto_sync.ps1 -Status"
    Write-Host "Uninstall: powershell -File scripts/setup_inject_rules_auto_sync.ps1 -Uninstall"
    exit 0
}
