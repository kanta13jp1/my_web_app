[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$containerName = "mwa-video-sql-test-$PID"
$postgresPassword = 'local-video-contract-only'
$migrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260819165405_create_first_party_video_service.sql'
$artifactFixturePath = Join-Path $repositoryRoot 'supabase/tests/video_artifact_review_loop_pre_migration.sql'
$artifactMigrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260822084126_add_video_artifact_review_loop.sql'
$authorizationMigrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260830053403_video_improvement_authorization_envelopes.sql'
$authorizationRetryMigrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260830123038_allow_authorized_video_retry_after_failure.sql'
$authorizationRetryIndexMigrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260830123552_allow_authorized_video_retry_index.sql'
$pendingAuthorizationMigrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260830162041_persist_pending_video_improvement_authorizations.sql'
$authorizedReviewMigrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260902090000_add_authorized_video_review_rpc.sql'
$publicationFixturePath = Join-Path $repositoryRoot 'supabase/tests/video_publication_pre_migration.sql'
$publicationMigrationPath = Join-Path $repositoryRoot 'supabase/migrations/20260830151707_create_video_publication_authorizations.sql'
$bootstrapPath = Join-Path $repositoryRoot 'supabase/tests/video_service_bootstrap.sql'
$contractPath = Join-Path $repositoryRoot 'supabase/tests/first_party_video_service_contract.sql'
$artifactContractPath = Join-Path $repositoryRoot 'supabase/tests/video_artifact_review_loop_contract.sql'
$authorizationContractPath = Join-Path $repositoryRoot 'supabase/tests/video_improvement_authorization_contract.sql'
$authorizedReviewContractPath = Join-Path $repositoryRoot 'supabase/tests/video_authorized_artifact_review_contract.sql'
$publicationContractPath = Join-Path $repositoryRoot 'supabase/tests/video_publication_authorization_contract.sql'

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

  foreach ($sqlPath in @(
      $bootstrapPath,
      $migrationPath,
      $artifactFixturePath,
      $artifactMigrationPath,
      $authorizationMigrationPath,
      $authorizationRetryMigrationPath,
      $authorizationRetryIndexMigrationPath,
      $pendingAuthorizationMigrationPath,
      $authorizedReviewMigrationPath,
      $publicationFixturePath,
      $publicationMigrationPath,
      $contractPath,
      $artifactContractPath,
      $authorizationContractPath,
      $authorizedReviewContractPath,
      $publicationContractPath
    )) {
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
