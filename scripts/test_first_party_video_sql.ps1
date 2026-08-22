[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$containerName = "mwa-video-sql-test-$PID"
$postgresPassword = 'local-video-contract-only'
$migrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260819165405_create_first_party_video_service.sql'
$bootstrapPath = Join-Path $repositoryRoot 'supabase/tests/video_service_bootstrap.sql'
$contractPath = Join-Path $repositoryRoot 'supabase/tests/first_party_video_service_contract.sql'

try {
  docker run --detach --rm `
    --name $containerName `
    --env "POSTGRES_PASSWORD=$postgresPassword" `
    postgres:17-alpine | Out-Null

  $ready = $false
  for ($attempt = 0; $attempt -lt 30; $attempt += 1) {
    $savedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $probe = docker exec $containerName `
      psql --username postgres --dbname postgres `
        --tuples-only --no-align --command 'select 1' 2>$null
    $probeExitCode = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorActionPreference
    if ($probeExitCode -eq 0 -and $probe.Trim() -eq '1') {
      $ready = $true
      break
    }
    Start-Sleep -Seconds 1
  }
  if (-not $ready) {
    throw 'Temporary PostgreSQL did not become ready.'
  }

  foreach ($sqlPath in @($bootstrapPath, $migrationPath, $contractPath)) {
    Get-Content -LiteralPath $sqlPath -Raw |
      docker exec --interactive $containerName `
        psql --username postgres --dbname postgres --set ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) {
      throw "SQL contract failed: $sqlPath"
    }
  }

  Write-Output 'First-party video SQL contract passed.'
}
finally {
  $exists = docker inspect --format '{{.Name}}' $containerName 2>$null
  if ($LASTEXITCODE -eq 0 -and $exists -eq "/$containerName") {
    docker stop --time 5 $containerName | Out-Null
  }
}
