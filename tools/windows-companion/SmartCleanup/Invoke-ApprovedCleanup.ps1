[CmdletBinding()]
param(
  [string]$ApprovalCsv,
  [switch]$Apply
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

function Test-UnderAnyRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Roots
  )

  foreach ($root in $Roots) {
    if ($Path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function ConvertTo-BooleanApproval {
  param([string]$Value)

  return $Value -match '^(true|yes|y|1|approved)$'
}

function Send-FileToRecycleBin {
  param([Parameter(Mandatory = $true)][string]$Path)

  Add-Type -AssemblyName Microsoft.VisualBasic
  [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
    $Path,
    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
  )
}

$googleRoot = Get-GoogleMyDriveRoot
$reportRoot = if ($googleRoot) {
  Join-Path $googleRoot 'C-drive-archive\cleanup-reports'
} else {
  Join-Path $env:USERPROFILE 'SmartCleanupReports'
}

if (-not $ApprovalCsv) {
  $ApprovalCsv = Join-Path $reportRoot 'cleanup-approval-latest.csv'
}

if (-not (Test-Path -LiteralPath $ApprovalCsv)) {
  throw "Approval CSV not found: $ApprovalCsv"
}

$allowedLocalRoots = @(
  (Join-Path $env:USERPROFILE 'Downloads'),
  (Join-Path $env:USERPROFILE 'Videos'),
  (Join-Path $env:USERPROFILE 'Documents'),
  (Join-Path $env:USERPROFILE 'Desktop')
) | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object {
  (Resolve-Path -LiteralPath $_).Path
}

$googleRootResolved = if ($googleRoot) {
  (Resolve-Path -LiteralPath $googleRoot).Path
} else {
  $null
}

$rows = Import-Csv -LiteralPath $ApprovalCsv
$approvedRows = @($rows | Where-Object {
  (ConvertTo-BooleanApproval -Value $_.Approved) -and
  $_.Action -eq 'RecycleLocalCopy'
})

New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$resultRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $approvedRows) {
  $localPath = [string]$row.LocalPath
  $googleCopyPath = [string]$row.GoogleCopyPath
  $status = 'DryRun'
  $message = ''

  try {
    if (-not (Test-Path -LiteralPath $localPath)) {
      throw "Local file not found: $localPath"
    }
    if ($googleCopyPath -and -not (Test-Path -LiteralPath $googleCopyPath)) {
      throw "Google copy not found: $googleCopyPath"
    }

    $localResolved = (Resolve-Path -LiteralPath $localPath).Path
    if (-not (Test-UnderAnyRoot -Path $localResolved -Roots $allowedLocalRoots)) {
      throw "Local path is outside approved cleanup roots: $localResolved"
    }

    $localHash = (Get-FileHash -LiteralPath $localResolved -Algorithm SHA256).Hash
    if ($localHash -ne $row.Hash) {
      throw "Local hash changed since approval CSV was generated: $localResolved"
    }

    if ($googleCopyPath) {
      $googleResolved = (Resolve-Path -LiteralPath $googleCopyPath).Path
      if ($googleRootResolved -and -not $googleResolved.StartsWith($googleRootResolved, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Google copy is outside Google Drive root: $googleResolved"
      }
      $googleHash = (Get-FileHash -LiteralPath $googleResolved -Algorithm SHA256).Hash
      if ($googleHash -ne $row.Hash) {
        throw "Google copy hash does not match approved duplicate hash: $googleResolved"
      }
    }

    if ($Apply) {
      Send-FileToRecycleBin -Path $localResolved
      $status = 'Recycled'
      $message = 'Moved local duplicate to Recycle Bin.'
    } else {
      $message = 'Verified. Re-run with -Apply to move to Recycle Bin.'
    }
  } catch {
    $status = 'Skipped'
    $message = $_.Exception.Message
  }

  $resultRows.Add([pscustomobject]@{
    Status = $status
    Message = $message
    SizeMB = $row.SizeMB
    LocalPath = $localPath
    GoogleCopyPath = $googleCopyPath
  })
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$resultPath = Join-Path $reportRoot "approved-cleanup-result-$timestamp.csv"
$latestResultPath = Join-Path $reportRoot 'approved-cleanup-result-latest.csv'
$resultRows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $resultPath
$resultRows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $latestResultPath

Write-Output "Approved cleanup completed."
Write-Output "Mode: $(if ($Apply) { 'Apply' } else { 'DryRun' })"
Write-Output "Approved rows: $($approvedRows.Count)"
Write-Output "Result CSV: $resultPath"
if (-not $Apply) {
  Write-Output 'No files were deleted or moved. Re-run with -Apply after reviewing the dry-run result.'
}
