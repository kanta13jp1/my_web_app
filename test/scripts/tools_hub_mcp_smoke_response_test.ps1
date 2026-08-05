$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Net.Http

$scriptPath = Join-Path $PSScriptRoot "..\..\scripts\tools_hub_mcp_smoke.ps1"
. $scriptPath

function Assert-Equal {
  param(
    [string]$Expected,
    [string]$Actual,
    [string]$Message
  )

  if ($Expected -ne $Actual) {
    throw "$Message`nExpected: $Expected`nActual: $Actual"
  }
}

$httpResponse = [System.Net.Http.HttpResponseMessage]::new(
  [System.Net.HttpStatusCode]::Unauthorized
)
$httpResponse.Content = [System.Net.Http.StringContent]::new(
  '{"error":"unauthorized"}',
  [System.Text.Encoding]::UTF8,
  "application/json"
)
$httpResponse.Headers.WwwAuthenticate.ParseAdd(
  'Bearer resource_metadata="https://example.test/.well-known/oauth-protected-resource"'
)
try {
  Assert-Equal `
    '{"error":"unauthorized"}' `
    (Get-ResponseText $httpResponse) `
    "HttpResponseMessage content should be read through HttpContent."
  Assert-Equal `
    'Bearer resource_metadata="https://example.test/.well-known/oauth-protected-resource"' `
    (Get-SmokeHeader $httpResponse.Headers "WWW-Authenticate") `
    "HttpResponseHeaders values should be read through TryGetValues."
} finally {
  $httpResponse.Dispose()
}

$disposedHttpResponse = [System.Net.Http.HttpResponseMessage]::new(
  [System.Net.HttpStatusCode]::Unauthorized
)
$disposedHttpResponse.Content = [System.Net.Http.StringContent]::new(
  '{"error":"disposed"}',
  [System.Text.Encoding]::UTF8,
  "application/json"
)
$disposedHttpResponse.Dispose()
Assert-Equal `
  "" `
  (Get-ResponseText $disposedHttpResponse) `
  "Disposed HttpResponseMessage content should fall back to empty text."

$script:capturedSkipHttpErrorCheck = $false
function Invoke-WebRequest {
  param(
    [string]$Method,
    [string]$Uri,
    [hashtable]$Headers,
    [int]$TimeoutSec,
    [switch]$UseBasicParsing,
    [string]$ErrorAction,
    [switch]$SkipHttpErrorCheck,
    [string]$ContentType,
    [object]$Body
  )

  $script:capturedSkipHttpErrorCheck = $PSBoundParameters.ContainsKey(
    "SkipHttpErrorCheck"
  )
  return [pscustomobject]@{
    StatusCode = 401
    Headers = @{ "WWW-Authenticate" = "Bearer" }
    Content = '{"error":"unauthorized"}'
  }
}

try {
  $supportsSkipHttpErrorCheck = (
    Get-Command Invoke-WebRequest -CommandType Cmdlet -ErrorAction Stop
  ).Parameters.ContainsKey("SkipHttpErrorCheck")
  $mockResponse = Invoke-SmokeRequest `
    -Method "POST" `
    -Url "https://example.test/functions/v1/tools-hub" `
    -Body @{ jsonrpc = "2.0" }
  Assert-Equal "401" ([string]$mockResponse.StatusCode) "HTTP errors should be returned."
  Assert-Equal `
    ([string]$supportsSkipHttpErrorCheck) `
    ([string]$script:capturedSkipHttpErrorCheck) `
    "SkipHttpErrorCheck should be used only when the runtime supports it."
} finally {
  Remove-Item Function:\Invoke-WebRequest
}

$legacyResponse = [pscustomobject]@{}
$legacyResponse | Add-Member -MemberType ScriptMethod -Name GetResponseStream -Value {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"legacy"}')
  return [System.IO.MemoryStream]::new($bytes)
}
Assert-Equal `
  '{"error":"legacy"}' `
  (Get-ResponseText $legacyResponse) `
  "Legacy WebResponse streams should remain supported."

Assert-Equal "" (Get-ResponseText $null) "Null responses should return empty text."

Write-Host "tools-hub MCP smoke response compatibility tests passed."
