<#
.SYNOPSIS
Runs deterministic smoke checks against the tools-hub MCP facade.

.DESCRIPTION
This script is intentionally side-effect-light by default. It verifies public
metadata, MCP tool discovery, deny-by-default auth behavior, and optionally
authenticated read calls plus Dynamic Client Registration.

Set MCP_BEARER_TOKEN to verify authenticated tool calls. Pass
-RegistrationRedirectUri only when you intentionally want to create a DCR row.
#>
[CmdletBinding()]
param(
  [string]$BaseUrl = $env:TOOLS_HUB_MCP_URL,
  [string]$BearerToken = $env:MCP_BEARER_TOKEN,
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$SupabaseServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY,
  [string]$RegistrationRedirectUri = "",
  [switch]$SkipRegistration,
  [switch]$EnableWriteConfirmationProbe,
  [int]$AuditLookbackMinutes = 2,
  [int]$TimeoutSec = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail {
  param([string]$Message)
  throw "tools-hub MCP smoke failed: $Message"
}

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )
  if (-not $Condition) {
    Fail $Message
  }
  Write-Host "[ok] $Message"
}

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "== $Message =="
}

function Join-SmokeUrl {
  param(
    [string]$Root,
    [string]$Path
  )
  return ("{0}/{1}" -f $Root.TrimEnd("/"), $Path.TrimStart("/"))
}

function Get-JsonProperty {
  param(
    [object]$Object,
    [string]$Name
  )
  if ($null -eq $Object) {
    return $null
  }
  $prop = $Object.PSObject.Properties[$Name]
  if ($null -eq $prop) {
    return $null
  }
  return $prop.Value
}

function ConvertFrom-SmokeJson {
  param([string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $null
  }
  try {
    return $Text | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return $null
  }
}

function Get-ResponseText {
  param([object]$Response)
  if ($null -eq $Response) {
    return ""
  }

  if ($Response.GetType().FullName -eq "System.Net.Http.HttpResponseMessage") {
    if ($null -eq $Response.Content) {
      return ""
    }
    try {
      return $Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    } catch {
      if (
        $_.Exception -is [System.ObjectDisposedException] -or
        $_.Exception.InnerException -is [System.ObjectDisposedException]
      ) {
        return ""
      }
      throw
    }
  }

  $stream = $Response.GetResponseStream()
  if ($null -eq $stream) {
    return ""
  }
  $reader = New-Object System.IO.StreamReader($stream)
  try {
    return $reader.ReadToEnd()
  } finally {
    $reader.Dispose()
  }
}

function Invoke-SmokeRequest {
  param(
    [string]$Method,
    [string]$Url,
    [hashtable]$Headers = @{},
    [object]$Body = $null
  )

  $params = @{
    Method = $Method
    Uri = $Url
    Headers = $Headers
    TimeoutSec = $TimeoutSec
    UseBasicParsing = $true
    ErrorAction = "Stop"
  }
  if ($null -ne $Body) {
    $params.ContentType = "application/json"
    $params.Body = $Body | ConvertTo-Json -Depth 30
  }

  $invokeWebRequestCommand = Get-Command Invoke-WebRequest -CommandType Cmdlet -ErrorAction Stop
  if ($invokeWebRequestCommand.Parameters.ContainsKey("SkipHttpErrorCheck")) {
    $params.SkipHttpErrorCheck = $true
  }

  try {
    $response = Invoke-WebRequest @params
    $text = [string]$response.Content
    return [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      Headers = $response.Headers
      Text = $text
      Json = ConvertFrom-SmokeJson $text
    }
  } catch {
    $response = $null
    if ($_.Exception.PSObject.Properties["Response"]) {
      $response = $_.Exception.Response
    }
    if ($null -eq $response) {
      throw
    }

    $text = ""
    if ($null -ne $_.ErrorDetails) {
      $text = [string]$_.ErrorDetails.Message
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
      $text = Get-ResponseText $response
    }
    return [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      Headers = $response.Headers
      Text = $text
      Json = ConvertFrom-SmokeJson $text
    }
  }
}

function Get-SmokeHeader {
  param(
    [object]$Headers,
    [string]$Name
  )
  if ($null -eq $Headers) {
    return ""
  }

  if ($null -ne $Headers.PSObject.Methods["TryGetValues"]) {
    $headerValues = $null
    if ($Headers.TryGetValues($Name, [ref]$headerValues)) {
      return (@($headerValues) -join ", ")
    }
  }

  $value = $null
  try {
    $value = $Headers[$Name]
  } catch {
    $value = $null
  }

  if ($null -eq $value) {
    $keys = @()
    try {
      $keys = @($Headers.Keys)
    } catch {
      $keys = @()
    }
    if ($keys.Count -eq 0) {
      try {
        $keys = @($Headers.AllKeys)
      } catch {
        $keys = @()
      }
    }
    foreach ($key in $keys) {
      if ([string]::Equals([string]$key, $Name, [StringComparison]::OrdinalIgnoreCase)) {
        try {
          $value = $Headers[$key]
        } catch {
          $value = $null
        }
        break
      }
    }
  }

  if ($null -eq $value) {
    return ""
  }
  if ($value -is [array]) {
    return ($value -join ", ")
  }
  return [string]$value
}

function New-JsonRpcRequest {
  param(
    [string]$Id,
    [string]$Method,
    [hashtable]$Params = @{}
  )
  return @{
    jsonrpc = "2.0"
    id = $Id
    method = $Method
    params = $Params
  }
}

function Resolve-SupabaseUrl {
  param([string]$ToolsHubUrl)

  if (-not [string]::IsNullOrWhiteSpace($SupabaseUrl)) {
    return $SupabaseUrl.Trim().TrimEnd("/")
  }

  try {
    $uri = [Uri]$ToolsHubUrl
    if ($uri.Host.EndsWith(".supabase.co", [StringComparison]::OrdinalIgnoreCase)) {
      return ("{0}://{1}" -f $uri.Scheme, $uri.Host)
    }
  } catch {
    return ""
  }

  return ""
}

function Get-McpAuditLog {
  param(
    [string]$ToolName,
    [int]$ResponseStatus,
    [DateTime]$SinceUtc
  )

  $resolvedSupabaseUrl = Resolve-SupabaseUrl $BaseUrl
  if (
    [string]::IsNullOrWhiteSpace($resolvedSupabaseUrl) -or
    [string]::IsNullOrWhiteSpace($SupabaseServiceRoleKey)
  ) {
    return $null
  }

  $sinceIso = $SinceUtc.ToUniversalTime().ToString("o")
  $query = @(
    "select=id,client_id,tool_name,response_status,invoked_at",
    "tool_name=eq.$([Uri]::EscapeDataString($ToolName))",
    "response_status=eq.$ResponseStatus",
    "invoked_at=gte.$([Uri]::EscapeDataString($sinceIso))",
    "order=invoked_at.desc",
    "limit=1"
  ) -join "&"
  $url = Join-SmokeUrl $resolvedSupabaseUrl "rest/v1/mcp_audit_log?$query"
  $headers = @{
    apikey = $SupabaseServiceRoleKey
    Authorization = "Bearer $SupabaseServiceRoleKey"
    Accept = "application/json"
  }

  $response = Invoke-SmokeRequest -Method "GET" -Url $url -Headers $headers
  if ($response.StatusCode -ne 200) {
    Fail "mcp_audit_log query returned HTTP $($response.StatusCode)"
  }

  $rows = @($response.Json)
  if ($rows.Count -eq 0) {
    return $null
  }
  return $rows[0]
}

function Assert-McpAuditLog {
  param(
    [string]$ToolName,
    [int]$ResponseStatus,
    [DateTime]$SinceUtc,
    [string]$Message
  )

  $resolvedSupabaseUrl = Resolve-SupabaseUrl $BaseUrl
  if (
    [string]::IsNullOrWhiteSpace($resolvedSupabaseUrl) -or
    [string]::IsNullOrWhiteSpace($SupabaseServiceRoleKey)
  ) {
    Write-Host "[skip] mcp_audit_log proof skipped; SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY not configured"
    return
  }

  for ($attempt = 1; $attempt -le 5; $attempt++) {
    $row = Get-McpAuditLog -ToolName $ToolName -ResponseStatus $ResponseStatus -SinceUtc $SinceUtc
    if ($null -ne $row) {
      $invokedAt = Get-JsonProperty $row "invoked_at"
      Write-Host ("[ok] {0}; audit invoked_at={1}" -f $Message, $invokedAt)
      return
    }
    Start-Sleep -Seconds 2
  }

  Fail $Message
}

if ($MyInvocation.InvocationName -eq ".") {
  return
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  if (-not [string]::IsNullOrWhiteSpace($env:SUPABASE_URL)) {
    $BaseUrl = Join-SmokeUrl $env:SUPABASE_URL "functions/v1/tools-hub"
  } else {
    Fail "Provide -BaseUrl, TOOLS_HUB_MCP_URL, or SUPABASE_URL."
  }
}

$BaseUrl = $BaseUrl.Trim().TrimEnd("/")
$wellKnownUrl = Join-SmokeUrl $BaseUrl ".well-known/oauth-protected-resource"
$registerUrl = Join-SmokeUrl $BaseUrl "register"
$smokeStartedAt = (Get-Date).ToUniversalTime().AddMinutes(-1 * [Math]::Max($AuditLookbackMinutes, 1))
$authHeaders = @{}
if (-not [string]::IsNullOrWhiteSpace($BearerToken)) {
  $authHeaders.Authorization = "Bearer $BearerToken"
}

Write-Host "tools-hub MCP smoke target: $BaseUrl"

Write-Step "Protected resource metadata"
$metadata = Invoke-SmokeRequest -Method "GET" -Url $wellKnownUrl
Assert-True ($metadata.StatusCode -eq 200) "well-known metadata returns HTTP 200"
$resource = Get-JsonProperty $metadata.Json "resource"
$scopes = @(Get-JsonProperty $metadata.Json "scopes_supported")
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$resource)) "metadata advertises resource"
foreach ($scope in @("read", "create", "wbs.tasks.list", "feature_request.create", "user_tasks.list")) {
  Assert-True ($scopes -contains $scope) "metadata scopes include $scope"
}

Write-Step "MCP tools/list"
$toolsListBody = New-JsonRpcRequest -Id "tools-list" -Method "tools/list"
$toolsList = Invoke-SmokeRequest -Method "POST" -Url $BaseUrl -Body $toolsListBody
Assert-True ($toolsList.StatusCode -eq 200) "tools/list returns HTTP 200"
$toolsResult = Get-JsonProperty $toolsList.Json "result"
$tools = @(Get-JsonProperty $toolsResult "tools")
$toolNames = @($tools | ForEach-Object { Get-JsonProperty $_ "name" })
foreach ($toolName in @("wbs.tasks.list", "feature_request.create", "user_tasks.list")) {
  Assert-True ($toolNames -contains $toolName) "tools/list includes $toolName"
}

Write-Step "Deny-by-default tool auth"
$unauthBody = New-JsonRpcRequest -Id "unauth-wbs" -Method "tools/call" -Params @{
  name = "wbs.tasks.list"
  arguments = @{
    instance = "codex"
    limit = 1
  }
}
$unauth = Invoke-SmokeRequest -Method "POST" -Url $BaseUrl -Body $unauthBody
Assert-True ($unauth.StatusCode -eq 401) "unauthenticated tools/call returns HTTP 401"
$wwwAuthenticate = Get-SmokeHeader $unauth.Headers "WWW-Authenticate"
Assert-True ($wwwAuthenticate -match "Bearer") "401 response includes WWW-Authenticate Bearer challenge"
Assert-McpAuditLog -ToolName "wbs.tasks.list" -ResponseStatus 401 -SinceUtc $smokeStartedAt -Message "mcp_audit_log records unauthenticated wbs.tasks.list 401"

Write-Step "Authenticated read call"
if ($authHeaders.ContainsKey("Authorization")) {
  $readBody = New-JsonRpcRequest -Id "auth-wbs" -Method "tools/call" -Params @{
    name = "wbs.tasks.list"
    arguments = @{
      instance = "codex"
      limit = 1
    }
  }
  $read = Invoke-SmokeRequest -Method "POST" -Url $BaseUrl -Headers $authHeaders -Body $readBody
  Assert-True ($read.StatusCode -eq 200) "authenticated wbs.tasks.list returns HTTP 200"
  $readResult = Get-JsonProperty $read.Json "result"
  $structured = Get-JsonProperty $readResult "structuredContent"
  Assert-True ($null -ne $structured) "authenticated read returns structuredContent"
  Assert-McpAuditLog -ToolName "wbs.tasks.list" -ResponseStatus 200 -SinceUtc $smokeStartedAt -Message "mcp_audit_log records authenticated wbs.tasks.list 200"
} else {
  Write-Host "[skip] MCP_BEARER_TOKEN not set; authenticated read call skipped"
}

Write-Step "Write confirmation gate"
if ($EnableWriteConfirmationProbe) {
  if (-not $authHeaders.ContainsKey("Authorization")) {
    Fail "-EnableWriteConfirmationProbe requires -BearerToken or MCP_BEARER_TOKEN."
  }
  $writeProbeBody = New-JsonRpcRequest -Id "write-confirmation" -Method "tools/call" -Params @{
    name = "feature_request.create"
    arguments = @{
      title = "[smoke] tools-hub MCP confirmation gate"
      description = "This probe intentionally omits confirm=true and must not create a WBS task."
      instance = "codex"
      priority = "low"
    }
  }
  $writeProbe = Invoke-SmokeRequest -Method "POST" -Url $BaseUrl -Headers $authHeaders -Body $writeProbeBody
  Assert-True ($writeProbe.StatusCode -eq 409) "feature_request.create without confirmation returns HTTP 409"
  $writeResult = Get-JsonProperty $writeProbe.Json "result"
  $writeStructured = Get-JsonProperty $writeResult "structuredContent"
  $writeError = Get-JsonProperty $writeStructured "error"
  Assert-True ($writeError -eq "confirmation_required") "write probe returns confirmation_required"
  Assert-McpAuditLog -ToolName "feature_request.create" -ResponseStatus 409 -SinceUtc $smokeStartedAt -Message "mcp_audit_log records feature_request.create confirmation_required"
} else {
  Write-Host "[skip] Write confirmation probe skipped; pass -EnableWriteConfirmationProbe to verify it"
}

Write-Step "Dynamic Client Registration"
if ($SkipRegistration) {
  Write-Host "[skip] DCR skipped by -SkipRegistration"
} elseif ([string]::IsNullOrWhiteSpace($RegistrationRedirectUri)) {
  Write-Host "[skip] DCR skipped; pass -RegistrationRedirectUri to create a test client row"
} else {
  $registrationBody = @{
    client_name = "tools-hub MCP smoke"
    redirect_uris = @($RegistrationRedirectUri)
    grant_types = @("authorization_code", "refresh_token")
    scope = "read create"
  }
  $registration = Invoke-SmokeRequest -Method "POST" -Url $registerUrl -Body $registrationBody
  Assert-True ($registration.StatusCode -eq 201) "DCR returns HTTP 201"
  $clientId = [string](Get-JsonProperty $registration.Json "client_id")
  $clientSecret = [string](Get-JsonProperty $registration.Json "client_secret")
  Assert-True ($clientId.StartsWith("mcp_")) "DCR returns mcp_ client_id"
  Assert-True ($clientSecret.StartsWith("mcp_secret_")) "DCR returns client_secret"
  Write-Host ("[ok] DCR client created: {0}; client_secret=<redacted>" -f $clientId)
}

Write-Host ""
Write-Host "tools-hub MCP smoke completed."
