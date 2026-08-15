param(
  [string]$ProjectRef = "smmkxxavexumewbfaqpy",
  [string]$PythonPath = "C:\Users\kanta\AppData\Local\Programs\Python\Python312\python.exe",
  [string]$FunctionUrl = "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-hub",
  [string]$ReturnUrl = "https://my-web-app-b67f4.web.app/subscription-billing",
  [switch]$AlsoWebhookSecret,
  [switch]$SkipSecretUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-SecureStringToPlainText {
  param([Parameter(Mandatory = $true)][securestring]$Value)

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try {
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Assert-Command {
  param([Parameter(Mandatory = $true)][string]$Name)

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    throw "Required command '$Name' was not found on PATH."
  }
  return $command.Source
}

function Normalize-SecretInput {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value,
    [Parameter(Mandatory = $true)][string]$VariableName
  )

  $normalized = $Value.Trim()
  if ($normalized.StartsWith("$VariableName=")) {
    $normalized = $normalized.Substring($VariableName.Length + 1).Trim()
  }
  if (
    ($normalized.StartsWith('"') -and $normalized.EndsWith('"')) -or
    ($normalized.StartsWith("'") -and $normalized.EndsWith("'"))
  ) {
    $normalized = $normalized.Substring(1, $normalized.Length - 2).Trim()
  }
  return $normalized
}

function Assert-LiveStripeSecretKey {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value.StartsWith("pk_live_")) {
    throw "This is a Stripe publishable key (pk_live_...). Use a server-side secret key from Developers > API keys, not a publishable key."
  }
  if ($Value.StartsWith("sk_test_") -or $Value.StartsWith("rk_test_")) {
    throw "This is a Stripe test-mode key. Use a live-mode key for the revenue gate."
  }
  if ($Value.StartsWith("rk_live_")) {
    Write-Warning "Using a restricted live key (rk_live_...). It must allow Checkout Sessions write and the related read/write permissions needed by this app."
    return
  }
  if (-not $Value.StartsWith("sk_live_")) {
    throw "Refusing to set STRIPE_SECRET_KEY because the value is not a live secret key. Expected sk_live_... or a properly-permissioned rk_live_... restricted key."
  }
}

function Assert-StripeWebhookSecret {
  param([Parameter(Mandatory = $true)][string]$Value)

  if ($Value.StartsWith("we_")) {
    throw "This looks like a Stripe webhook endpoint ID (we_...). Use the webhook signing secret, which starts with whsec_."
  }
  if (-not $Value.StartsWith("whsec_")) {
    throw "Refusing to set STRIPE_WEBHOOK_SECRET because it does not start with whsec_."
  }
}

if (-not (Test-Path -LiteralPath $PythonPath)) {
  throw "Python was not found at '$PythonPath'. Pass -PythonPath if it moved."
}

$stripeSecretForProbe = $null

if (-not $SkipSecretUpdate) {
  $supabase = Assert-Command "supabase"
  $tempFile = New-TemporaryFile
  $plainStripeSecret = $null
  $plainWebhookSecret = $null

  try {
    $secureStripeSecret = Read-Host "Paste Stripe LIVE secret key (sk_live_... or rk_live_...)" -AsSecureString
    $plainStripeSecret = Normalize-SecretInput `
      -Value (Convert-SecureStringToPlainText $secureStripeSecret) `
      -VariableName "STRIPE_SECRET_KEY"
    Assert-LiveStripeSecretKey $plainStripeSecret
    $stripeSecretForProbe = $plainStripeSecret

    $lines = @("STRIPE_SECRET_KEY=$plainStripeSecret")

    if ($AlsoWebhookSecret) {
      $secureWebhookSecret = Read-Host "Paste Stripe LIVE webhook signing secret (whsec_...)" -AsSecureString
      $plainWebhookSecret = Normalize-SecretInput `
        -Value (Convert-SecureStringToPlainText $secureWebhookSecret) `
        -VariableName "STRIPE_WEBHOOK_SECRET"
      Assert-StripeWebhookSecret $plainWebhookSecret
      $lines += "STRIPE_WEBHOOK_SECRET=$plainWebhookSecret"
    }

    Set-Content -LiteralPath $tempFile -Value $lines -Encoding ascii
    & $supabase secrets set --project-ref $ProjectRef --env-file $tempFile
    if ($LASTEXITCODE -ne 0) {
      throw "supabase secrets set failed with exit code $LASTEXITCODE."
    }
  } finally {
    if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
      Remove-Item -LiteralPath $tempFile -Force
    }
    $plainStripeSecret = $null
    $plainWebhookSecret = $null
  }
}

$readinessArgs = @(
  "scripts\check_first_revenue_readiness.py",
  "--mode",
  "live",
  "--json",
  "--function-url",
  $FunctionUrl,
  "--return-url",
  $ReturnUrl
)

$previousStripeSecretEnv = [Environment]::GetEnvironmentVariable("STRIPE_SECRET_KEY", "Process")
$restoreStripeSecretEnv = $true
try {
  if (-not [string]::IsNullOrWhiteSpace($stripeSecretForProbe)) {
    $env:STRIPE_SECRET_KEY = $stripeSecretForProbe
  } elseif ([string]::IsNullOrWhiteSpace($env:STRIPE_SECRET_KEY)) {
    $restoreStripeSecretEnv = $false
  }

  if (-not [string]::IsNullOrWhiteSpace($env:STRIPE_SECRET_KEY)) {
    $readinessArgs += "--expire-checkout-session"
  }

  & $PythonPath @readinessArgs
} finally {
  if ($restoreStripeSecretEnv) {
    if ($null -eq $previousStripeSecretEnv) {
      Remove-Item Env:\STRIPE_SECRET_KEY -ErrorAction SilentlyContinue
    } else {
      $env:STRIPE_SECRET_KEY = $previousStripeSecretEnv
    }
  }
  $stripeSecretForProbe = $null
}

if ($LASTEXITCODE -ne 0) {
  throw "Live revenue readiness gate failed. Do not promote or take real payments yet."
}

Write-Host "Live revenue readiness gate passed. The next step is one real supporter payment, then webhook and bank-payout evidence."
