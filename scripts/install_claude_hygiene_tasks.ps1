<#
.SYNOPSIS
    Install repo-managed Claude session hygiene Windows Scheduled Tasks.

.DESCRIPTION
    Issue #2507 localizes the #2506 session hygiene primitive for the Windows
    desktop host. The script is safe by default: no task is registered unless
    -Install is passed. -Status and -Verify inspect the five expected tasks.

    Installed tasks run as the current interactive DOMAIN\USER identity. This
    avoids the Register-ScheduledTask UserId false-positive documented in
    docs/instance-constraints.md.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install_claude_hygiene_tasks.ps1 -Status

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install_claude_hygiene_tasks.ps1 -Install

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install_claude_hygiene_tasks.ps1 -Verify
#>

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Verify,
    [switch]$Status,
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$TaskPrefix = "",
    [string]$LogRoot = "",
    [switch]$InstallDisabled,
    [int]$MaxRuntimeMinutes = 10
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Write-Usage {
    Write-Host "Usage: -Install | -Uninstall | -Verify | -Status [-RepoPath <path>] [-TaskPrefix <prefix>] [-InstallDisabled]"
}

$actions = @(@($Install, $Uninstall, $Verify, $Status) | Where-Object { [bool]$_ })
if ($actions.Count -eq 0) {
    $Status = $true
} elseif ($actions.Count -gt 1) {
    Write-Usage
    throw "Pass only one action switch."
}

if (-not (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue)) {
    throw "Windows ScheduledTasks module is required."
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$sessionHygieneScript = Join-Path $repo "scripts\session_hygiene_check.py"
$ramTrimScript = Join-Path $repo "scripts\memory_trim_phase2.ps1"

if (-not (Test-Path -LiteralPath $sessionHygieneScript)) {
    throw "Missing session hygiene script: $sessionHygieneScript"
}
if (-not (Test-Path -LiteralPath $ramTrimScript)) {
    throw "Missing RAM trim script: $ramTrimScript"
}

if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = Join-Path $repo "memory\claude-hygiene-tasks"
}
New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null

function Quote-Single {
    param([Parameter(Mandatory = $true)][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

function Get-CurrentUserId {
    if ([string]::IsNullOrWhiteSpace($env:USERDOMAIN) -or [string]::IsNullOrWhiteSpace($env:USERNAME)) {
        throw "USERDOMAIN and USERNAME are required for Scheduled Task principal."
    }
    return "$env:USERDOMAIN\$env:USERNAME"
}

function Get-TaskName {
    param([Parameter(Mandatory = $true)][string]$BaseName)
    return "$TaskPrefix$BaseName"
}

function New-EncodedPowerShellArgument {
    param([Parameter(Mandatory = $true)][string]$ScriptBody)
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($ScriptBody)
    $encoded = [Convert]::ToBase64String($bytes)
    return "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
}

function New-HygieneAction {
    param(
        [Parameter(Mandatory = $true)][string]$Mode,
        [switch]$Force,
        [double]$DiskWarnGb = 25.0,
        [double]$DiskAutoGb = 15.0,
        [double]$RamWarnPct = 85.0,
        [double]$RamAutoPct = 90.0
    )

    $repoLiteral = Quote-Single $repo
    $scriptLiteral = Quote-Single $sessionHygieneScript
    $logRootLiteral = Quote-Single $LogRoot
    $modeLiteral = Quote-Single $Mode
    $forceArg = if ($Force) { " --force" } else { "" }

    $body = @"
`$ErrorActionPreference = 'Continue'
`$env:PYTHONUTF8 = '1'
Set-Location $repoLiteral
`$logRoot = $logRootLiteral
New-Item -ItemType Directory -Path `$logRoot -Force | Out-Null
`$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
`$taskLog = Join-Path `$logRoot ('$Mode-' + `$stamp + '.log')
`$jsonOut = Join-Path `$logRoot ('$Mode-latest.json')
`$csvLog = Join-Path $repoLiteral 'memory\session_hygiene_log.csv'
`$out = & python $scriptLiteral --root $repoLiteral --mode $modeLiteral --log-path `$csvLog --json-out `$jsonOut --disk-warn-gb $DiskWarnGb --disk-auto-gb $DiskAutoGb --ram-warn-pct $RamWarnPct --ram-auto-pct $RamAutoPct --max-runtime-sec 180 --command-timeout 60 --apply$forceArg 2>&1
`$exit = `$LASTEXITCODE
Add-Content -Path `$taskLog -Value (`$out -join [Environment]::NewLine)
Add-Content -Path `$taskLog -Value ('exit=' + `$exit)
exit `$exit
"@

    return New-ScheduledTaskAction -Execute "powershell.exe" -Argument (New-EncodedPowerShellArgument $body)
}

function New-RamGcAction {
    $repoLiteral = Quote-Single $repo
    $scriptLiteral = Quote-Single $ramTrimScript
    $logRootLiteral = Quote-Single $LogRoot

    $body = @"
`$ErrorActionPreference = 'Continue'
Set-Location $repoLiteral
`$logRoot = $logRootLiteral
New-Item -ItemType Directory -Path `$logRoot -Force | Out-Null
`$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
`$taskLog = Join-Path `$logRoot ('claude_ram_gc-' + `$stamp + '.log')
`$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptLiteral -Json 2>&1
`$exit = `$LASTEXITCODE
Add-Content -Path `$taskLog -Value (`$out -join [Environment]::NewLine)
Add-Content -Path `$taskLog -Value ('exit=' + `$exit)
exit `$exit
"@

    return New-ScheduledTaskAction -Execute "powershell.exe" -Argument (New-EncodedPowerShellArgument $body)
}

function New-StandardSettings {
    param([switch]$RunOnlyIfIdle)
    $settingsArgs = @{
        StartWhenAvailable        = $true
        AllowStartIfOnBatteries   = $true
        DontStopIfGoingOnBatteries = $true
        ExecutionTimeLimit        = (New-TimeSpan -Minutes $MaxRuntimeMinutes)
        MultipleInstances         = "IgnoreNew"
    }
    if ($InstallDisabled) {
        $settingsArgs["Disable"] = $true
    }
    if ($RunOnlyIfIdle) {
        $settingsArgs["RunOnlyIfIdle"] = $true
        $settingsArgs["IdleDuration"] = (New-TimeSpan -Minutes 60)
        $settingsArgs["IdleWaitTimeout"] = (New-TimeSpan -Minutes 90)
        $settingsArgs["DontStopOnIdleEnd"] = $true
    }
    return New-ScheduledTaskSettingsSet @settingsArgs
}

$userId = Get-CurrentUserId
$repeatStart = (Get-Date).Date.AddMinutes(5)

$TaskSpecs = @(
    @{
        BaseName = "claude_session_start"
        Trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
        Action = New-HygieneAction -Mode "claude_session_start" -Force
        Settings = New-StandardSettings
        Description = "Claude/Codex local session hygiene at interactive logon."
    },
    @{
        BaseName = "claude_session_mid"
        Trigger = New-ScheduledTaskTrigger -Once -At $repeatStart -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650)
        Action = New-HygieneAction -Mode "claude_session_mid"
        Settings = New-StandardSettings
        Description = "Claude/Codex local session hygiene every 30 minutes when auto thresholds are crossed."
    },
    @{
        BaseName = "claude_session_end"
        Trigger = New-ScheduledTaskTrigger -Once -At $repeatStart -RepetitionInterval (New-TimeSpan -Minutes 60) -RepetitionDuration (New-TimeSpan -Days 3650)
        Action = New-HygieneAction -Mode "claude_session_end_idle" -Force
        Settings = New-StandardSettings -RunOnlyIfIdle
        Description = "Claude/Codex idle session hygiene after the host is idle for 60 minutes."
    },
    @{
        BaseName = "claude_disk_compress"
        Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:20"
        Action = New-HygieneAction -Mode "claude_disk_compress" -Force -DiskWarnGb 28.0 -DiskAutoGb 26.0
        Settings = New-StandardSettings
        Description = "Claude/Codex weekly forced disk compression pass."
    },
    @{
        BaseName = "claude_ram_gc"
        Trigger = New-ScheduledTaskTrigger -Once -At $repeatStart -RepetitionInterval (New-TimeSpan -Minutes 15) -RepetitionDuration (New-TimeSpan -Days 3650)
        Action = New-RamGcAction
        Settings = New-StandardSettings
        Description = "Claude/Codex local RAM working-set trim every 15 minutes."
    }
)

function Get-TaskStatusRows {
    $rows = @()
    foreach ($spec in $TaskSpecs) {
        $taskName = Get-TaskName $spec.BaseName
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
            $rows += [pscustomobject]@{
                TaskName = $taskName
                State = [string]$task.State
                LastRunTime = if ($info) { $info.LastRunTime } else { $null }
                LastTaskResult = if ($info) { $info.LastTaskResult } else { $null }
                NextRunTime = if ($info) { $info.NextRunTime } else { $null }
            }
        } else {
            $rows += [pscustomobject]@{
                TaskName = $taskName
                State = "Missing"
                LastRunTime = $null
                LastTaskResult = $null
                NextRunTime = $null
            }
        }
    }
    return $rows
}

function Write-OperationLog {
    param(
        [Parameter(Mandatory = $true)][string]$Operation,
        [Parameter(Mandatory = $true)]$Rows
    )
    $payload = [ordered]@{
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        operation = $Operation
        repo = $repo
        user_id = $userId
        task_prefix = $TaskPrefix
        install_disabled = [bool]$InstallDisabled
        tasks = $Rows
    }
    $path = Join-Path $LogRoot ("install-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".json")
    $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
    Write-Host "Log: $path"
}

if ($Status) {
    $rows = Get-TaskStatusRows
    $rows | Format-Table -AutoSize
    $missing = @($rows | Where-Object { $_.State -eq "Missing" }).Count
    Write-Host "Installed: $($rows.Count - $missing) / $($rows.Count)"
    exit 0
}

if ($Verify) {
    $rows = Get-TaskStatusRows
    $rows | Format-Table -AutoSize
    $missing = @($rows | Where-Object { $_.State -eq "Missing" }).Count
    Write-OperationLog -Operation "verify" -Rows $rows
    if ($missing -gt 0) {
        Write-Error "Missing $missing Claude hygiene scheduled task(s)."
        exit 5
    }
    Write-Host "[OK] All Claude hygiene scheduled tasks are installed."
    exit 0
}

if ($Uninstall) {
    foreach ($spec in $TaskSpecs) {
        $taskName = Get-TaskName $spec.BaseName
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-Host "Uninstalled: $taskName"
        } else {
            Write-Host "Not installed: $taskName"
        }
    }
    $rows = Get-TaskStatusRows
    Write-OperationLog -Operation "uninstall" -Rows $rows
    exit 0
}

if ($Install) {
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel Limited
    foreach ($spec in $TaskSpecs) {
        $taskName = Get-TaskName $spec.BaseName
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        }
        Register-ScheduledTask `
            -TaskName $taskName `
            -Action $spec.Action `
            -Trigger $spec.Trigger `
            -Principal $principal `
            -Settings $spec.Settings `
            -Description $spec.Description `
            -ErrorAction Stop | Out-Null

        $created = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if (-not $created) {
            Write-Error "Register-ScheduledTask returned but task was not found: $taskName"
            exit 6
        }
        Write-Host "Installed: $taskName"
    }

    $rows = Get-TaskStatusRows
    Write-OperationLog -Operation "install" -Rows $rows
    $missing = @($rows | Where-Object { $_.State -eq "Missing" }).Count
    if ($missing -gt 0) {
        Write-Error "Post-install verify failed: $missing task(s) missing."
        exit 7
    }
    Write-Host "[OK] Claude hygiene scheduled tasks installed and verified."
    Write-Host "Verify: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install_claude_hygiene_tasks.ps1 -Verify"
    exit 0
}
