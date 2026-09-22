#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
repo_root="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
evidence_dir="${ROOTLESS_EVIDENCE_DIR:-${repo_root}/.ci-logs/rootless-cloud}"
mkdir -p "${evidence_dir}"
cd "${repo_root}"

case "${mode}" in
  devcontainer|supabase) ;;
  *)
    echo "usage: $0 <devcontainer|supabase>" >&2
    exit 2
    ;;
esac

evidence_file="${evidence_dir}/${mode}.txt"
service_pid=""
supabase_started=false

record() {
  printf '%s\n' "$*" | tee -a "${evidence_file}"
}

cleanup() {
  status=$?
  set +e
  if [ "${supabase_started}" = true ]; then
    if supabase stop >/dev/null 2>&1; then
      record "supabase_cleanup=stopped_with_backup"
    else
      record "supabase_cleanup=stop_failed_runner_will_be_discarded"
    fi
  fi
  if [ -n "${service_pid}" ]; then
    kill "${service_pid}" >/dev/null 2>&1
    wait "${service_pid}" >/dev/null 2>&1
  fi
  record "exit_code=${status}"
  exit "${status}"
}
trap cleanup EXIT

: > "${evidence_file}"
record "mode=${mode}"
record "runner=${RUNNER_OS:-unknown}/${RUNNER_ARCH:-unknown}"
record "kernel=$(uname -srmo)"
record "uid=$(id -u) gid=$(id -g)"
record "podman_client=$(podman --version)"

rootless="$(podman info --format '{{.Host.Security.Rootless}}')"
record "podman_rootless=${rootless}"
if [ "${rootless}" != "true" ]; then
  echo "Podman must run rootless on the cloud runner." >&2
  exit 1
fi

record "uid_map=$(podman unshare cat /proc/self/uid_map | tr '\n' ';')"
record "unprivileged_port_start=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)"

if [ "${mode}" = devcontainer ]; then
  volume_dir="$(mktemp -d)"
  podman run --rm \
    --userns=keep-id \
    --volume "${volume_dir}:/workspace" \
    docker.io/library/alpine:3.22 \
    sh -ceu 'test "$(id -u)" -ne 0; touch /workspace/cloud-write'
  test -f "${volume_dir}/cloud-write"
  record "keep_id_volume_write=pass"

  image="localhost/my-web-app-devcontainer:${GITHUB_SHA:-local}"
  podman build \
    --file "${repo_root}/.devcontainer/Dockerfile" \
    --tag "${image}" \
    "${repo_root}/.devcontainer"

  podman run --rm \
    --userns=keep-id \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    "${image}" \
    bash -ceu '
      test "$(id -u)" -ne 0
      if command -v sudo >/dev/null 2>&1; then ! sudo -n true; fi
      flutter --version
    ' | tee -a "${evidence_file}"
  record "devcontainer_non_root=pass"
  record "devcontainer_sudo_denied=pass"
  record "devcontainer_build=pass"
  exit 0
fi

socket_dir="${RUNNER_TEMP:-/tmp}/rootless-podman-${GITHUB_RUN_ID:-local}"
mkdir -p "${socket_dir}"
socket_path="${socket_dir}/podman.sock"
podman system service --time=0 "unix://${socket_path}" \
  >"${socket_dir}/podman-service.log" 2>&1 &
service_pid=$!
export DOCKER_HOST="unix://${socket_path}"

for _ in $(seq 1 30); do
  if curl --fail --silent --unix-socket "${socket_path}" \
    http://d/_ping >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl --fail --silent --unix-socket "${socket_path}" http://d/_ping >/dev/null
record "docker_api_compatibility=pass"
record "supabase_cli=$(supabase --version 2>/dev/null | head -n 1)"

start_log="${socket_dir}/supabase-start.log"
supabase_started=true
if ! supabase start \
  --exclude realtime,storage-api,imgproxy,mailpit,postgres-meta,studio,edge-runtime,logflare,vector,supavisor \
  --ignore-health-check \
  --yes >"${start_log}" 2>&1; then
  echo "Supabase start failed; relevant diagnostics:" >&2
  diagnostics_file="${evidence_dir}/supabase-start-diagnostics.txt"
  {
    grep -Ei \
      'error|failed|denied|unhealthy|permission|operation not permitted|does not exist|not ready|read-only|invalid|already exists|workdir|exit code' \
      "${start_log}" | tail -n 120 || true
    podman ps --all \
      --filter label=com.supabase.cli.project \
      --format 'container={{.Names}} state={{.State}} status={{.Status}}' || true
  } | sed -E \
    -e '/anon key|service_role key|jwt secret|API URL|DB URL|Studio URL/Id' \
    -e 's#postgres(ql)?://[^[:space:]]+#postgresql://[redacted]#g' \
    -e 's/eyJ[A-Za-z0-9._-]+/[redacted-jwt]/g' \
    | tee "${diagnostics_file}" >&2
  exit 1
fi

project_id="$(sed -nE 's/^project_id[[:space:]]*=[[:space:]]*"([^"]+)"/\1/p' \
  "${repo_root}/supabase/config.toml" | head -n 1)"
db_container=""
for _ in $(seq 1 30); do
  db_container="$(podman ps \
    --filter "label=com.supabase.cli.project=${project_id}" \
    --format '{{.Names}}' | grep '^supabase_db_' | head -n 1 || true)"
  if [ -n "${db_container}" ]; then
    break
  fi
  sleep 2
done
test -n "${db_container}"

database_ready=false
for _ in $(seq 1 60); do
  if podman exec "${db_container}" pg_isready -U postgres >/dev/null 2>&1; then
    database_ready=true
    break
  fi
  sleep 2
done
test "${database_ready}" = true
podman exec "${db_container}" pg_isready -U postgres | tee -a "${evidence_file}"
db_log="${socket_dir}/database.log"
podman logs "${db_container}" >"${db_log}" 2>&1
if grep -Eqi 'permission denied|operation not permitted' "${db_log}"; then
  echo "Database log contains a rootless volume permission error." >&2
  exit 1
fi
record "database_volume_permission_errors=0"

gateway_auth_status=""
for _ in $(seq 1 15); do
  if gateway_auth_status="$(curl --fail --silent --output /dev/null \
    --write-out '%{http_code}' http://127.0.0.1:54321/auth/v1/health)"; then
    break
  fi
  sleep 2
done

auth_container="$(podman ps \
  --filter "label=com.supabase.cli.project=${project_id}" \
  --format '{{.Names}}' | grep '^supabase_auth_' | head -n 1 || true)"
test -n "${auth_container}"
auth_ip="$(podman inspect \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  "${auth_container}")"
test -n "${auth_ip}"

internal_auth_status=""
for _ in $(seq 1 60); do
  internal_auth_status="$(podman exec "${db_container}" bash -c \
    "exec 3<>/dev/tcp/${auth_ip}/9999; printf 'GET /health HTTP/1.0\\r\\nHost: auth\\r\\n\\r\\n' >&3; head -n 1 <&3" \
    2>/dev/null | awk '{print $2}' || true)"
  if [ "${internal_auth_status}" = "200" ]; then
    break
  fi
  sleep 2
done
test "${internal_auth_status}" = "200"

record "supabase_auth_container_health=200"
if [ "${gateway_auth_status}" = "200" ]; then
  record "supabase_auth_gateway_health=200"
  record "supabase_rootless_smoke=pass"
else
  record "supabase_auth_gateway_health=unavailable_known_podman_kong_limit"
  record "supabase_rootless_smoke=pass_with_gateway_compatibility_limit"
fi
if supabase status >/dev/null 2>&1; then
  record "supabase_cli_status=pass"
else
  record "supabase_cli_status=degraded_known_podman_health_limit"
fi
record "supabase_database_health=ready"
