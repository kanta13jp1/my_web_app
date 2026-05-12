[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$ReleaseDir,
  [Parameter(Mandatory = $true)][string]$OutputDir,
  [string]$Version = '1.0.0.0',
  [string]$Publisher = 'CN=Jibun Windows Companion',
  [string]$PublisherDisplayName = 'Jibun Inc.',
  [string]$CertificateBase64,
  [string]$CertificatePassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-WindowsSdkTool {
  param([Parameter(Mandatory = $true)][string]$ToolName)

  $roots = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
    "$env:ProgramFiles\Windows Kits\10\bin"
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

  foreach ($root in $roots) {
    $tool = Get-ChildItem -LiteralPath $root -Recurse -Filter $ToolName -File -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\x64\\' } |
      Sort-Object FullName -Descending |
      Select-Object -First 1
    if ($tool) {
      return $tool.FullName
    }
  }

  throw "$ToolName was not found. Install the Windows 10/11 SDK."
}

function ConvertTo-MsixVersion {
  param([Parameter(Mandatory = $true)][string]$RawVersion)

  $parts = $RawVersion.Split('.') | ForEach-Object {
    $value = 0
    if ([int]::TryParse($_, [ref]$value)) {
      [Math]::Min([Math]::Max($value, 0), 65535)
    } else {
      0
    }
  }

  while ($parts.Count -lt 4) {
    $parts += 0
  }
  return ($parts[0..3] -join '.')
}

function Escape-XmlText {
  param([string]$Value)

  return [Security.SecurityElement]::Escape($Value)
}

function New-ResizedPng {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][int]$Width,
    [Parameter(Mandatory = $true)][int]$Height
  )

  Add-Type -AssemblyName System.Drawing
  $sourceImage = [Drawing.Image]::FromFile($Source)
  $bitmap = New-Object Drawing.Bitmap $Width, $Height
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.DrawImage($sourceImage, 0, 0, $Width, $Height)
    $bitmap.Save($Destination, [Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
    $sourceImage.Dispose()
  }
}

function New-MsixCertificate {
  param(
    [Parameter(Mandatory = $true)][string]$Subject,
    [Parameter(Mandatory = $true)][string]$PfxPath,
    [Parameter(Mandatory = $true)][string]$CerPath,
    [Parameter(Mandatory = $true)][securestring]$Password
  )

  $cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $Subject `
    -FriendlyName 'Jibun Windows Companion MSIX Signing' `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -KeyUsage DigitalSignature `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')

  Export-PfxCertificate -Cert $cert -FilePath $PfxPath -Password $Password | Out-Null
  Export-Certificate -Cert $cert -FilePath $CerPath | Out-Null
  Remove-Item -LiteralPath "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force -ErrorAction SilentlyContinue
}

$releaseDirResolved = (Resolve-Path -LiteralPath $ReleaseDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $releaseDirResolved 'my_web_app.exe'))) {
  throw "my_web_app.exe was not found in release directory: $releaseDirResolved"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$outputDirResolved = (Resolve-Path -LiteralPath $OutputDir).Path
$packageRoot = Join-Path $outputDirResolved 'msix-package'
$assetsDir = Join-Path $packageRoot 'Assets'
$msixPath = Join-Path $outputDirResolved 'jibun-windows-companion.msix'
$cerPath = Join-Path $outputDirResolved 'jibun-windows-companion.cer'
$pfxPath = Join-Path $outputDirResolved 'jibun-windows-companion-signing.pfx'

Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $assetsDir | Out-Null
Copy-Item -Path (Join-Path $releaseDirResolved '*') -Destination $packageRoot -Recurse -Force

$iconSource = Join-Path $PWD 'web\icons\Icon-512.png'
if (-not (Test-Path -LiteralPath $iconSource)) {
  $iconSource = Join-Path $PWD 'web\favicon.png'
}
if (-not (Test-Path -LiteralPath $iconSource)) {
  throw 'No source icon was found under web/icons or web/favicon.png.'
}

New-ResizedPng -Source $iconSource -Destination (Join-Path $assetsDir 'StoreLogo.png') -Width 50 -Height 50
New-ResizedPng -Source $iconSource -Destination (Join-Path $assetsDir 'Square44x44Logo.png') -Width 44 -Height 44
New-ResizedPng -Source $iconSource -Destination (Join-Path $assetsDir 'Square71x71Logo.png') -Width 71 -Height 71
New-ResizedPng -Source $iconSource -Destination (Join-Path $assetsDir 'Square150x150Logo.png') -Width 150 -Height 150
New-ResizedPng -Source $iconSource -Destination (Join-Path $assetsDir 'Wide310x150Logo.png') -Width 310 -Height 150
New-ResizedPng -Source $iconSource -Destination (Join-Path $assetsDir 'Square310x310Logo.png') -Width 310 -Height 310

$msixVersion = ConvertTo-MsixVersion -RawVersion $Version
$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  IgnorableNamespaces="uap rescap">
  <Identity Name="Kanta13jp1.JibunWindowsCompanion" Publisher="$(Escape-XmlText $Publisher)" Version="$msixVersion" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>Jibun Windows Companion</DisplayName>
    <PublisherDisplayName>$(Escape-XmlText $PublisherDisplayName)</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.22621.0" />
  </Dependencies>
  <Resources>
    <Resource Language="ja-jp" />
    <Resource Language="en-us" />
  </Resources>
  <Applications>
    <Application Id="JibunWindowsCompanion" Executable="my_web_app.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements
        DisplayName="Jibun Windows Companion"
        Description="Local smart cleanup companion for Jibun App"
        BackgroundColor="#00897B"
        Square150x150Logo="Assets\Square150x150Logo.png"
        Square44x44Logo="Assets\Square44x44Logo.png">
        <uap:DefaultTile
          Square71x71Logo="Assets\Square71x71Logo.png"
          Wide310x150Logo="Assets\Wide310x150Logo.png"
          Square310x310Logo="Assets\Square310x310Logo.png" />
      </uap:VisualElements>
    </Application>
  </Applications>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
</Package>
"@
$manifest | Set-Content -LiteralPath (Join-Path $packageRoot 'AppxManifest.xml') -Encoding UTF8

$makeAppx = Find-WindowsSdkTool -ToolName 'makeappx.exe'
$signTool = Find-WindowsSdkTool -ToolName 'signtool.exe'
& $makeAppx pack /d $packageRoot /p $msixPath /overwrite
if ($LASTEXITCODE -ne 0) {
  throw "makeappx failed with exit code $LASTEXITCODE"
}

$plainPassword = if ($CertificatePassword) { $CertificatePassword } else { [guid]::NewGuid().ToString('N') }
$securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
if ($CertificateBase64) {
  [IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($CertificateBase64))
  $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2
  $cert.Import($pfxPath, $plainPassword, 'Exportable')
  [IO.File]::WriteAllBytes($cerPath, $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
} else {
  New-MsixCertificate -Subject $Publisher -PfxPath $pfxPath -CerPath $cerPath -Password $securePassword
}

& $signTool sign /fd SHA256 /f $pfxPath /p $plainPassword $msixPath
if ($LASTEXITCODE -ne 0) {
  throw "signtool failed with exit code $LASTEXITCODE"
}

Remove-Item -LiteralPath $pfxPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue

Get-Item -LiteralPath $msixPath, $cerPath | Select-Object FullName, Length, LastWriteTime
