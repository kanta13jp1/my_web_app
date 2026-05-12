<#
.SYNOPSIS
    Issue #1984 RAM trim Phase 2 helper.

.DESCRIPTION
    Trims working sets for idle, user-owned editor/agent processes without
    requiring administrator rights. This is intended for SessionStart/End hook
    integration and emits ram_trim_count / ram_trim_total_mb_freed metrics.
#>

param(
    [int]$MinWorkingSetMB = 200,
    [int]$MinAgeMinutes = 10,
    [switch]$Json
)

$ErrorActionPreference = 'SilentlyContinue'

$signature = @'
[DllImport("psapi.dll")]
public static extern bool EmptyWorkingSet(System.IntPtr hProcess);
'@
$api = Add-Type -MemberDefinition $signature -Name 'PsApiPhase2' -Namespace 'MemMgmt' -PassThru -ErrorAction SilentlyContinue

$pattern = '^(claude|codex|code|cursor|node|electron)$'
$targets = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -match $pattern -and
    $_.WorkingSet64 -gt ($MinWorkingSetMB * 1MB) -and
    $null -ne $_.StartTime -and
    ((Get-Date) - $_.StartTime).TotalMinutes -gt $MinAgeMinutes
}

$trimmed = 0
$before = 0
$after = 0

foreach ($proc in $targets) {
    try {
        $before += $proc.WorkingSet64
        if ($null -ne $api) {
            [void]$api::EmptyWorkingSet($proc.Handle)
        } else {
            [void]$proc.MinWorkingSet
            $proc.MinWorkingSet = 1MB
        }
        Start-Sleep -Milliseconds 50
        $proc.Refresh()
        $after += $proc.WorkingSet64
        $trimmed += 1
    } catch {
        # Locked or already exited process: skip.
    }
}

$freedMB = [math]::Round([math]::Max(0, $before - $after) / 1MB, 1)
$payload = [ordered]@{
    ram_trim_count = $trimmed
    ram_trim_total_mb_freed = $freedMB
    min_working_set_mb = $MinWorkingSetMB
    min_age_minutes = $MinAgeMinutes
}

if ($Json) {
    $payload | ConvertTo-Json -Compress
} else {
    "ram_trim_count=$trimmed ram_trim_total_mb_freed=$freedMB"
}
