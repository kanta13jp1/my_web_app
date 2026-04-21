<#
.SYNOPSIS
  Verify or rotate the BYPASS_RULES GitHub Actions repository secret.

.DESCRIPTION
  Uses GitHub CLI (`gh`) to check whether BYPASS_RULES exists, or to set it
  without placing the secret value on the command line. When setting a value,
  the script prompts with SecureString and writes a temporary body file that is
  deleted immediately after `gh secret set` completes.

.PARAMETER Repo
  Repository in owner/name form. Defaults to GITHUB_REPOSITORY or origin remote.

.PARAMETER SecretName
  Secret name to verify or set. Defaults to BYPASS_RULES.

.PARAMETER VerifyOnly
  Only check whether the secret exists; do not prompt for or write a value.

.EXAMPLE
  ./scripts/set_bypass_rules_secret.ps1 -VerifyOnly

.EXAMPLE
  ./scripts/set_bypass_rules_secret.ps1 -Repo "kanta13jp1/my_web_app"
#>

[CmdletBinding()]
param(
    [string]$Repo = $env:GITHUB_REPOSITORY,
    [ValidateNotNullOrEmpty()]
    [string]$SecretName = 'BYPASS_RULES',
    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Error $Message
    exit 1
}

function Get-RepoFromOrigin {
    $remote = git remote get-url origin 2>$null
    if ([string]::IsNullOrWhiteSpace($remote)) {
        return $null
    }

    if ($remote -match 'github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(\.git)?$') {
        return "$($Matches.owner)/$($Matches.repo)"
    }

    return $null
}

function ConvertTo-PlainText([securestring]$Secret) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail 'gh CLI not found. Install GitHub CLI and run `gh auth login`.'
}

if ([string]::IsNullOrWhiteSpace($Repo)) {
    $Repo = Get-RepoFromOrigin
}

if ([string]::IsNullOrWhiteSpace($Repo)) {
    Fail "Repository not specified. Provide -Repo 'owner/repo' or run inside a GitHub repo."
}

Write-Host "Repository: $Repo"
Write-Host "Secret:     $SecretName"

gh auth status --hostname github.com | Out-Host

$secretLine = gh secret list --repo $Repo |
    Where-Object { $_ -match "^$([regex]::Escape($SecretName))\s" } |
    Select-Object -First 1

if ($VerifyOnly) {
    if ($secretLine) {
        Write-Host "OK: $SecretName exists in $Repo ($secretLine)"
        exit 0
    }

    Fail "$SecretName is not configured in $Repo."
}

if ($secretLine) {
    Write-Host "Existing secret found: $secretLine"
    Write-Host 'Rotating value. Press Ctrl+C now to cancel.'
}

$secureValue = Read-Host "Enter new value for $SecretName" -AsSecureString
$plainValue = ConvertTo-PlainText $secureValue
if ([string]::IsNullOrWhiteSpace($plainValue)) {
    Fail 'Secret value is empty.'
}

$tempFile = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText(
        $tempFile,
        $plainValue,
        [System.Text.UTF8Encoding]::new($false)
    )
    gh secret set $SecretName --repo $Repo --body-file $tempFile
}
finally {
    $plainValue = $null
    if (Test-Path -LiteralPath $tempFile) {
        Remove-Item -LiteralPath $tempFile -Force
    }
}

$updatedLine = gh secret list --repo $Repo |
    Where-Object { $_ -match "^$([regex]::Escape($SecretName))\s" } |
    Select-Object -First 1

if (-not $updatedLine) {
    Fail "$SecretName was not found after update."
}

Write-Host "OK: $SecretName is configured in $Repo ($updatedLine)"
