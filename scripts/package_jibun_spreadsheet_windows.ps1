[CmdletBinding()]
param(
  [string]$Version = '1.0.0',
  [string]$BuildDirectory,
  [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
  $BuildDirectory = Join-Path $projectRoot 'build\windows\x64\runner\Release'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $OutputDirectory = Join-Path $projectRoot 'dist'
}

$resolvedBuild = (Resolve-Path -LiteralPath $BuildDirectory).Path
$expectedExe = Join-Path $resolvedBuild 'JibunSpreadsheet.exe'
if (-not (Test-Path -LiteralPath $expectedExe -PathType Leaf)) {
  throw "Windows release executable was not found: $expectedExe"
}

$releaseName = "JibunSpreadsheet-v$Version-win64"
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
$stagingRoot = Join-Path $outputRoot ".staging-$releaseName"
$zipPath = Join-Path $outputRoot "$releaseName.zip"
$manifestPath = Join-Path $outputRoot "$releaseName.manifest.json"
$packagingRoot = Join-Path $projectRoot 'packaging\jibun_spreadsheet'

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
if (Test-Path -LiteralPath $stagingRoot) {
  Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingRoot | Out-Null

try {
  Copy-Item -Path (Join-Path $resolvedBuild '*') -Destination $stagingRoot -Recurse -Force
  Copy-Item -LiteralPath (Join-Path $packagingRoot 'README.txt') -Destination $stagingRoot
  Copy-Item -LiteralPath (Join-Path $packagingRoot 'LICENSE.txt') -Destination $stagingRoot

  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal

  $zipFile = Get-Item -LiteralPath $zipPath
  $sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $sourceCommit = (git -C $projectRoot rev-parse HEAD).Trim()
  $manifest = [ordered]@{
    artifact_id = 'jibun-spreadsheet-win64'
    version = $Version
    file_name = $zipFile.Name
    file_size_bytes = $zipFile.Length
    sha256 = $sha256
    platform = 'windows-x64'
    build_target = 'lib/main_spreadsheet_windows.dart'
    source_commit = $sourceCommit
    created_at = (Get-Date).ToUniversalTime().ToString('o')
  }
  $manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8

  [pscustomobject]@{
    ZipPath = $zipPath
    ManifestPath = $manifestPath
    FileSizeBytes = $zipFile.Length
    Sha256 = $sha256
  }
}
finally {
  if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
  }
}

