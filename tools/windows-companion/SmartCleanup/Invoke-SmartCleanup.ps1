[CmdletBinding()]
param(
  [int64]$MinimumBytes = 1MB
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GoogleMyDriveRoot {
  if (-not (Test-Path -LiteralPath 'G:\')) {
    return $null
  }

  $visibleRoots = Get-ChildItem -LiteralPath 'G:\' -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object {
      -not ($_.Attributes -band [IO.FileAttributes]::Hidden) -and
      -not ($_.Attributes -band [IO.FileAttributes]::System)
    }

  return ($visibleRoots | Select-Object -First 1).FullName
}

function Test-ExcludedPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $parts = $Path -split '[\\/]'
  $excludedNames = @(
    '.git',
    '.dart_tool',
    '.gradle',
    '.venv',
    '.vscode',
    '__pycache__',
    'build',
    'node_modules',
    'venv'
  )

  foreach ($name in $excludedNames) {
    if ($parts -contains $name) {
      return $true
    }
  }

  return $false
}

function New-ReportDirectory {
  param([string]$GoogleRoot)

  if ($GoogleRoot) {
    $root = Join-Path $GoogleRoot 'C-drive-archive\cleanup-reports'
  } else {
    $root = Join-Path $env:USERPROFILE 'SmartCleanupReports'
  }

  New-Item -ItemType Directory -Force -Path $root | Out-Null
  return $root
}

function Publish-LatestFile {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [int]$Retries = 6,
    [int]$DelayMilliseconds = 750
  )

  $tempPath = "$Destination.tmp-$PID-$([guid]::NewGuid().ToString('N'))"
  Copy-Item -LiteralPath $Source -Destination $tempPath -Force -ErrorAction Stop

  try {
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
      try {
        Move-Item -LiteralPath $tempPath -Destination $Destination -Force -ErrorAction Stop
        return $true
      } catch {
        if ($attempt -ge $Retries) {
          Write-Warning "Could not refresh latest file: $Destination"
          Write-Warning $_.Exception.Message
          Write-Warning "Timestamped file remains available: $Source"
          return $false
        }
        Start-Sleep -Milliseconds $DelayMilliseconds
      }
    }
  } finally {
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
  }
}

$googleRoot = Get-GoogleMyDriveRoot
$archiveRoot = if ($googleRoot) { Join-Path $googleRoot 'C-drive-archive' } else { $null }
$reportRoot = New-ReportDirectory -GoogleRoot $googleRoot
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$csvPath = Join-Path $reportRoot "duplicate-report-$timestamp.csv"
$summaryPath = Join-Path $reportRoot "duplicate-summary-$timestamp.md"
$approvalPath = Join-Path $reportRoot "cleanup-approval-$timestamp.csv"
$latestCsvPath = Join-Path $reportRoot 'duplicate-report-latest.csv'
$latestSummaryPath = Join-Path $reportRoot 'duplicate-summary-latest.md'
$latestApprovalPath = Join-Path $reportRoot 'cleanup-approval-latest.csv'

$candidateRoots = @(
  (Join-Path $env:USERPROFILE 'Downloads'),
  (Join-Path $env:USERPROFILE 'Videos'),
  (Join-Path $env:USERPROFILE 'Documents'),
  (Join-Path $env:USERPROFILE 'Desktop')
)

if ($archiveRoot -and (Test-Path -LiteralPath $archiveRoot)) {
  $candidateRoots += $archiveRoot
}

$scanRoots = $candidateRoots |
  Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
  Select-Object -Unique

$files = foreach ($root in $scanRoots) {
  Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Length -ge $MinimumBytes -and
      -not (Test-ExcludedPath -Path $_.FullName) -and
      $_.FullName -notlike (Join-Path $reportRoot '*')
    } |
    Select-Object FullName, Length, LastWriteTime
}

$sameSizeGroups = $files |
  Group-Object Length |
  Where-Object { $_.Count -gt 1 }

$hashed = foreach ($group in $sameSizeGroups) {
  foreach ($file in $group.Group) {
    try {
      $hash = Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop
      [pscustomobject]@{
        FullName = $file.FullName
        Length = [int64]$file.Length
        LastWriteTime = $file.LastWriteTime
        Hash = $hash.Hash
      }
    } catch {
      [pscustomobject]@{
        FullName = $file.FullName
        Length = [int64]$file.Length
        LastWriteTime = $file.LastWriteTime
        Hash = ''
      }
    }
  }
}

$duplicateHashGroups = $hashed |
  Where-Object { $_.Hash } |
  Group-Object Hash |
  Where-Object { $_.Count -gt 1 }

$rows = New-Object System.Collections.Generic.List[object]
$groupIndex = 0
foreach ($group in $duplicateHashGroups) {
  $groupIndex++
  $hasGoogleCopy = $false
  if ($archiveRoot) {
    $hasGoogleCopy = @($group.Group | Where-Object {
      $_.FullName.StartsWith($archiveRoot, [StringComparison]::OrdinalIgnoreCase)
    }).Count -gt 0
  }

  $ordered = $group.Group | Sort-Object `
    @{ Expression = {
      if ($archiveRoot -and $_.FullName.StartsWith($archiveRoot, [StringComparison]::OrdinalIgnoreCase)) { 0 } else { 1 }
    } }, `
    @{ Expression = 'LastWriteTime'; Descending = $true }, `
    @{ Expression = 'FullName'; Ascending = $true }

  $keeper = $ordered | Select-Object -First 1
  foreach ($file in $ordered) {
    $recommendation = if ($file.FullName -eq $keeper.FullName) {
      'Keep'
    } elseif ($hasGoogleCopy -and $file.FullName.StartsWith($env:USERPROFILE, [StringComparison]::OrdinalIgnoreCase)) {
      'ReviewRemoveLocalCopy'
    } else {
      'ReviewDuplicate'
    }

    $rows.Add([pscustomobject]@{
      GroupId = $groupIndex
      Recommendation = $recommendation
      SizeMB = [math]::Round($file.Length / 1MB, 2)
      Hash = $file.Hash
      LastWriteTime = $file.LastWriteTime.ToString('s')
      Path = $file.FullName
    })
  }
}

$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csvPath
Publish-LatestFile -Source $csvPath -Destination $latestCsvPath | Out-Null

$approvalRows = New-Object System.Collections.Generic.List[object]
foreach ($row in ($rows | Where-Object { $_.Recommendation -eq 'ReviewRemoveLocalCopy' })) {
  $googleCopy = $rows |
    Where-Object {
      $_.GroupId -eq $row.GroupId -and
      $_.Recommendation -eq 'Keep' -and
      $archiveRoot -and
      $_.Path.StartsWith($archiveRoot, [StringComparison]::OrdinalIgnoreCase)
    } |
    Select-Object -First 1

  $approvalRows.Add([pscustomobject]@{
    Approved = 'false'
    Action = 'RecycleLocalCopy'
    GroupId = $row.GroupId
    SizeMB = $row.SizeMB
    Hash = $row.Hash
    LocalPath = $row.Path
    GoogleCopyPath = if ($googleCopy) { $googleCopy.Path } else { '' }
    Note = 'Set Approved=true after manually confirming this local duplicate can be sent to Recycle Bin.'
  })
}

$approvalRows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $approvalPath
Publish-LatestFile -Source $approvalPath -Destination $latestApprovalPath | Out-Null

$candidateBytes = ($rows |
  Where-Object { $_.Recommendation -ne 'Keep' } |
  Measure-Object SizeMB -Sum).Sum

$summary = @(
  '# Codex Smart Cleanup Report',
  '',
  "- Generated: $(Get-Date -Format s)",
  "- Minimum file size: $([math]::Round($MinimumBytes / 1MB, 2)) MB",
  "- Scan roots:",
  ($scanRoots | ForEach-Object { "  - $_" }),
  '',
  "Duplicate groups: $($duplicateHashGroups.Count)",
  "Reviewable duplicate volume: $([math]::Round(($candidateBytes / 1024), 2)) GB",
  "Approval candidates: $($approvalRows.Count)",
  '',
  'No files were deleted or moved by this task.',
  "CSV: $csvPath",
  "Approval CSV: $approvalPath"
)

$summary | Set-Content -Encoding UTF8 -Path $summaryPath
Publish-LatestFile -Source $summaryPath -Destination $latestSummaryPath | Out-Null

Write-Output "Codex Smart Cleanup report generated."
Write-Output "Summary: $summaryPath"
Write-Output "CSV: $csvPath"
Write-Output "Approval CSV: $approvalPath"
