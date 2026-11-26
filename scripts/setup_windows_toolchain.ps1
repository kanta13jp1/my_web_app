param(
    [switch]$DryRun,
    [switch]$ClearProxyEnv
)

$ErrorActionPreference = 'Stop'

if ($ClearProxyEnv) {
    foreach ($varName in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')) {
        if (Test-Path "Env:$varName") {
            Remove-Item "Env:$varName" -ErrorAction SilentlyContinue
            Write-Output "[proxy] Cleared Env:$varName"
        }
    }
} else {
    foreach ($varName in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')) {
        if (Test-Path "Env:$varName") {
            Write-Warning "Proxy env $varName is set; if ENOTFOUND occurs, re-run with -ClearProxyEnv."
        }
    }
}

$wingetPackages = @(
    @{ Name = 'Git'; Id = 'Git.Git' },
    @{ Name = 'GitHub CLI'; Id = 'GitHub.cli' },
    @{ Name = 'Deno'; Id = 'DenoLand.Deno' },
    @{ Name = 'Node.js LTS'; Id = 'OpenJS.NodeJS.LTS' }
)

foreach ($pkg in $wingetPackages) {
    $cmd = "winget install --id $($pkg.Id) --exact --accept-package-agreements --accept-source-agreements"
    if ($DryRun) {
        Write-Output "[dry-run] $cmd"
    } else {
        Write-Output "[install] $($pkg.Name) ($($pkg.Id))"
        winget install --id $pkg.Id --exact --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "winget exited with $LASTEXITCODE for $($pkg.Id) (may already be installed)."
        }
    }
}

Write-Output "[note] Flutter SDK and Supabase CLI are not in default winget source; install Flutter via official zip/FVM and Supabase CLI via 'npx supabase' or Scoop."

$versionChecks = @(
    'git --version',
    'gh --version',
    'deno --version',
    'node --version',
    'flutter --version',
    'supabase --version'
)

foreach ($check in $versionChecks) {
    if ($DryRun) {
        Write-Output "[dry-run] verify: $check"
    } else {
        Write-Output "[verify] $check"
        Invoke-Expression $check
    }
}
