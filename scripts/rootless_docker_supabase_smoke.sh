#!/usr/bin/env bash
set -euo pipefail

repo_root="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
evidence_dir="${ROOTLESS_EVIDENCE_DIR:-${repo_root}/.ci-logs/rootless-cloud}"
evidence_file="${evidence_dir}/supabase-docker.txt"
mkdir -p "${evidence_dir}"
cd "${repo_root}"

runtime_root="$(mktemp -d "${RUNNER_TEMP:-/tmp}/rootless-docker.XXXXXX")"
runtime_dir="${runtime_root}/run"
smoke_project="${runtime_root}/project"
daemon_log="${runtime_root}/dockerd-rootless.log"
start_log="${runtime_root}/supabase-start.log"
mkdir -p "${runtime_dir}" "${smoke_project}/supabase"
chmod 700 "${runtime_dir}"
cp "${repo_root}/supabase/config.toml" "${smoke_project}/supabase/config.toml"

export XDG_RUNTIME_DIR="${runtime_dir}"
export DOCKER_HOST="unix://${runtime_dir}/docker.sock"

daemon_pid=""
project_id=""
supabase_started=false

record() {
  printf '%s\n' "$*" | tee -a "${evidence_file}"
}

sanitize() {
  sed -E \
    -e '/anon key|service_role key|jwt secret|API URL|DB URL|Studio URL/Id' \
    -e 's#postgres(ql)?://[^[:space:]]+#postgresql://[redacted]#g' \
    -e 's/eyJ[A-Za-z0-9._-]+/[redacted-jwt]/g'
}

cleanup() {
  status=$?
  cleanup_failed=false
  trap - EXIT
  set +e

  if [ "${supabase_started}" = true ]; then
    if supabase --workdir "${smoke_project}" stop --no-backup >/dev/null 2>&1; then
      record "supabase_cleanup=stopped_no_backup"
      if [ -n "${project_id}" ]; then
        remaining="$(docker ps --all --quiet \
          --filter "label=com.supabase.cli.project=${project_id}" 2>/dev/null)"
        if [ -n "${remaining}" ]; then
          record "supabase_cleanup=orphan_containers_detected"
          cleanup_failed=true
        else
          record "supabase_cleanup_orphans=0"
        fi
      fi
    else
      record "supabase_cleanup=stop_failed"
      cleanup_failed=true
    fi
  fi

  if [ -n "${daemon_pid}" ]; then
    kill "${daemon_pid}" >/dev/null 2>&1
    wait "${daemon_pid}" >/dev/null 2>&1
    record "rootless_docker_cleanup=daemon_stopped"
  fi

  if [ "${cleanup_failed}" = true ] && [ "${status}" -eq 0 ]; then
    status=1
  fi
  record "exit_code=${status}"
  exit "${status}"
}
trap cleanup EXIT

: > "${evidence_file}"
record "mode=supabase-docker"
record "runner=${RUNNER_OS:-unknown}/${RUNNER_ARCH:-unknown}"
record "kernel=$(uname -srmo)"
record "uid=$(id -u) gid=$(id -g)"
record "docker_client=$(docker --version)"
record "supabase_cli=$(supabase --version 2>/dev/null | head -n 1)"
record "unprivileged_port_start=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)"

dockerd-rootless.sh \
  --host="${DOCKER_HOST}" \
  --storage-driver=fuse-overlayfs \
  --exec-opt native.cgroupdriver=cgroupfs \
  --data-root="${runtime_root}/data" \
  --exec-root="${runtime_root}/exec" \
  --pidfile="${runtime_root}/docker.pid" \
  --log-level=warn >"${daemon_log}" 2>&1 &
daemon_pid=$!

daemon_ready=false
for _ in $(seq 1 90); do
  if docker info >/dev/null 2>&1; then
    daemon_ready=true
    break
  fi
  if ! kill -0 "${daemon_pid}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if [ "${daemon_ready}" != true ]; then
  echo "Rootless Docker daemon failed to start:" >&2
  tail -n 120 "${daemon_log}" | sanitize >&2 || true
  exit 1
fi

security_options="$(docker info --format '{{json .SecurityOptions}}')"
if [[ "${security_options}" != *rootless* ]]; then
  echo "Docker daemon did not report the rootless security option." >&2
  exit 1
fi

daemon_uid="$(ps -o uid= -p "${daemon_pid}" | tr -d ' ')"
test "${daemon_uid}" = "$(id -u)"
record "docker_server=$(docker version --format '{{.Server.Version}}')"
record "docker_security_options=${security_options}"
record "docker_daemon_uid=${daemon_uid}"
record "docker_daemon_uid_map=$(tr '\n' ';' < "/proc/${daemon_pid}/uid_map")"
record "docker_socket=$(stat -c '%U:%G:%a' "${runtime_dir}/docker.sock")"
record "docker_api_compatibility=pass"
record "schema_mode=config_only_without_repository_migrations_or_seed"

project_id="$(sed -nE 's/^project_id[[:space:]]*=[[:space:]]*"([^"]+)"/\1/p' \
  "${smoke_project}/supabase/config.toml" | head -n 1)"
test -n "${project_id}"
supabase_started=true
if ! supabase --workdir "${smoke_project}" start \
  --exclude realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor \
  --yes >"${start_log}" 2>&1; then
  echo "Supabase start failed; relevant diagnostics:" >&2
  diagnostics_file="${evidence_dir}/supabase-docker-diagnostics.txt"
  {
    grep -Ei \
      'error|failed|denied|unhealthy|permission|operation not permitted|does not exist|not ready|read-only|invalid|already exists|workdir|exit code' \
      "${start_log}" | tail -n 120 || true
    docker ps --all \
      --filter label=com.supabase.cli.project \
      --format 'container={{.Names}} state={{.State}} status={{.Status}}' || true
  } | sanitize | tee "${diagnostics_file}" >&2
  exit 1
fi

db_container="$(docker ps \
  --filter "label=com.supabase.cli.project=${project_id}" \
  --format '{{.Names}}' | grep '^supabase_db_' | head -n 1)"
auth_container="$(docker ps \
  --filter "label=com.supabase.cli.project=${project_id}" \
  --format '{{.Names}}' | grep '^supabase_auth_' | head -n 1)"
test -n "${db_container}"
test -n "${auth_container}"

docker exec "${db_container}" pg_isready -U postgres | tee -a "${evidence_file}"
db_log="${runtime_root}/database.log"
docker logs "${db_container}" >"${db_log}" 2>&1
if grep -Eqi 'permission denied|operation not permitted' "${db_log}"; then
  echo "Database log contains a rootless volume permission error." >&2
  exit 1
fi
record "database_volume_permission_errors=0"

auth_status="$(curl --fail --silent --output /dev/null \
  --write-out '%{http_code}' http://127.0.0.1:54321/auth/v1/health)"
test "${auth_status}" = "200"
supabase --workdir "${smoke_project}" status >/dev/null

record "supabase_auth_container=${auth_container}"
record "supabase_auth_gateway_health=200"
record "supabase_database_health=ready"
record "supabase_rootless_docker_smoke=pass"
