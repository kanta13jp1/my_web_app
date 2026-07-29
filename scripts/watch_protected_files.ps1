<#
.SYNOPSIS
  Records which process empties a protected file, for as long as it takes to catch one.

.DESCRIPTION
  On 2026-07-21 eight tracked files under .github/workflows/ and .claude/ were
  truncated to 0 bytes within 52ms, in path-sorted order. The cause was never
  proven: git had no record of touching the working tree, Defender performed no
  remediation, and nothing on this machine was recording process attribution
  (Object Access auditing is off and Sysmon is not installed). It has not
  recurred since, so there is nothing left to find by looking backwards.

  This watcher supplies the one fact that was missing: *which process was running
  at the instant a file went to 0 bytes*. It is deliberately time-independent --
  the 03:30 correlation rests on a single observation and the scheduled task that
  ran then has since been largely exonerated, so keying on a clock would be
  fitting the instrument to a coincidence.

  READ-ONLY with respect to the repository. It never writes, restores, or stages
  anything, and its logs go outside the repo. Enforcement of the actual risk (an
  emptied file reaching main) lives in CI, in
  .github/workflows/protected-files-nonempty-guard.yml. This script only observes.

  LIMITATION, stated plainly: a process snapshot can only name a culprit that is
  still alive when the snapshot runs. If the truncation is done by a process that
  exits within milliseconds, this will capture the timing and the file list but
  not the offender -- which is itself the signal to escalate to Windows process
  creation auditing (event 4688 with command lines).

.NOTES
  Sunset: stops after the first capture, or after -SunsetDays from the first run,
  whichever comes first. This is temporary forensic instrumentation, not a
  permanent daemon; an unattended background writer left running forever is the
  very pattern that made the original incident hard to diagnose.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\watch_protected_files.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\Users\kanta\GitHub\my_web_app',

    # Deliberately outside the repository: this tool must never add to the
    # working tree it is watching.
    [string]$LogDir = (Join-Path $env:LOCALAPPDATA 'jibunkk-file-truncation-watch'),

    [int]$SunsetDays = 30,

    # How long to keep collecting sibling files after the first 0-byte hit. The
    # incident emptied eight files in 52ms, so the burst itself is evidence.
    [int]$BurstWindowSeconds = 10,

    # Test hook: exit after this long even if nothing is captured.
    [int]$MaxRuntimeSeconds = 0
)

$ErrorActionPreference = 'Stop'

$WatchedRelativeDirs = @('.github\workflows', '.claude')

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$startedMarker = Join-Path $LogDir 'first-run.txt'
if (Test-Path $startedMarker) {
    $firstRun = [datetime]::Parse((Get-Content $startedMarker -Raw).Trim())
} else {
    $firstRun = Get-Date
    $firstRun.ToString('o') | Out-File -FilePath $startedMarker -Encoding utf8
}

$sunsetAt = $firstRun.AddDays($SunsetDays)
$sessionLog = Join-Path $LogDir ('watch-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')

function Write-Log {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Message
    Add-Content -Path $sessionLog -Value $line -Encoding utf8
    Write-Output $line
}

function Get-ZeroBytePath {
    <# Every currently-empty file across the watched trees. #>
    $found = @()
    foreach ($rel in $WatchedRelativeDirs) {
        $dir = Join-Path $RepoRoot $rel
        if (-not (Test-Path $dir)) { continue }
        $found += Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -eq 0 } |
            ForEach-Object { $_.FullName }
    }
    return $found
}

function Save-ProcessSnapshot {
    param([string]$TriggerPath)

    # Taken first and fastest: a culprit that exits cannot be named later.
    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $dump = Join-Path $LogDir ('capture-' + $stamp + '.txt')

    @(
        '=== protected-file truncation capture ===',
        ('captured_at : ' + (Get-Date -Format 'o')),
        ('trigger     : ' + $TriggerPath),
        ('repo_root   : ' + $RepoRoot),
        '',
        '--- files currently 0 bytes in watched trees ---'
    ) | Out-File -FilePath $dump -Encoding utf8

    Get-ZeroBytePath | Out-File -FilePath $dump -Append -Encoding utf8

    '' | Out-File -FilePath $dump -Append -Encoding utf8
    '--- running processes (full command lines) ---' | Out-File -FilePath $dump -Append -Encoding utf8
    $procs | Sort-Object CreationDate -Descending |
        Format-Table -AutoSize -Wrap |
        Out-File -FilePath $dump -Append -Encoding utf8 -Width 500

    return $dump
}

if ((Get-Date) -ge $sunsetAt) {
    Write-Log ("Sunset reached (first run {0}, +{1} days). Nothing captured; the CI guard remains the standing protection. Exiting." -f $firstRun.ToString('yyyy-MM-dd'), $SunsetDays)
    exit 0
}

Write-Log ("Watching {0} under {1} | sunset {2}" -f ($WatchedRelativeDirs -join ', '), $RepoRoot, $sunsetAt.ToString('yyyy-MM-dd HH:mm'))

# Events are handled in this scope rather than via -Action scriptblocks, which
# run in a separate session state where these functions and variables are not
# visible.
$watchers = @()
$subscriptions = @()
$index = 0

foreach ($rel in $WatchedRelativeDirs) {
    $dir = Join-Path $RepoRoot $rel
    if (-not (Test-Path $dir)) {
        Write-Log ("Skipping missing directory: {0}" -f $dir)
        continue
    }

    $fsw = New-Object System.IO.FileSystemWatcher
    $fsw.Path = $dir
    $fsw.IncludeSubdirectories = $true
    $fsw.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::Size
    $fsw.EnableRaisingEvents = $true

    foreach ($eventName in @('Changed', 'Created')) {
        $sourceId = "protected-files-$eventName-$index"
        Register-ObjectEvent -InputObject $fsw -EventName $eventName -SourceIdentifier $sourceId | Out-Null
        $subscriptions += $sourceId
    }

    $watchers += $fsw
    $index++
    Write-Log ("Armed on {0}" -f $dir)
}

if ($watchers.Count -eq 0) {
    Write-Log 'No directories to watch; exiting.'
    exit 1
}

$captured = $false
$deadline = if ($MaxRuntimeSeconds -gt 0) {
    (Get-Date).AddSeconds($MaxRuntimeSeconds)
} else {
    $sunsetAt
}

try {
    while (-not $captured -and (Get-Date) -lt $deadline) {
        $evt = Wait-Event -Timeout 5
        if ($null -eq $evt) { continue }

        $path = $null
        if ($evt.SourceEventArgs -and $evt.SourceEventArgs.FullPath) {
            $path = $evt.SourceEventArgs.FullPath
        }
        Remove-Event -EventIdentifier $evt.EventIdentifier -ErrorAction SilentlyContinue
        if (-not $path) { continue }

        $isEmpty = $false
        try {
            $item = Get-Item -LiteralPath $path -ErrorAction Stop
            $isEmpty = (-not $item.PSIsContainer) -and ($item.Length -eq 0)
        } catch {
            continue
        }
        if (-not $isEmpty) { continue }

        # Snapshot immediately, filter afterwards: waiting to confirm would let a
        # short-lived writer exit before it can be named.
        $dump = Save-ProcessSnapshot -TriggerPath $path

        Start-Sleep -Milliseconds 250
        $stillEmpty = $false
        try {
            $stillEmpty = ((Get-Item -LiteralPath $path -ErrorAction Stop).Length -eq 0)
        } catch {
            $stillEmpty = $false
        }

        if (-not $stillEmpty) {
            # Transient 0-byte state from an ordinary write-then-flush. Discard so
            # a normal editor save does not burn the single capture.
            Remove-Item -LiteralPath $dump -Force -ErrorAction SilentlyContinue
            continue
        }

        $captured = $true
        Write-Log ("CAPTURED: {0} is 0 bytes. Process snapshot -> {1}" -f $path, $dump)

        Start-Sleep -Seconds $BurstWindowSeconds
        Write-Log ('Files 0 bytes after burst window: ' + ((Get-ZeroBytePath) -join '; '))
    }

    if ($captured) {
        Write-Log 'Capture complete. Review the capture-*.txt dump; if the offender had already exited, escalate to process creation auditing (event 4688 with command lines).'
    } elseif ((Get-Date) -ge $sunsetAt) {
        Write-Log 'Sunset reached with no capture. Retiring this instrumentation is correct: the CI guard is the standing protection.'
    } else {
        Write-Log 'Max runtime reached with no capture.'
    }
} finally {
    foreach ($sourceId in $subscriptions) {
        Unregister-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue
    }
    foreach ($fsw in $watchers) {
        $fsw.EnableRaisingEvents = $false
        $fsw.Dispose()
    }
}

if ($captured) { exit 0 } else { exit 0 }
