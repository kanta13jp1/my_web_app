#!/usr/bin/env bash
# Only for this approved, disposable GitHub-hosted verification runner.
# Dependencies are downloaded before entering the network namespace. Tests and
# generators get loopback only, with no external route, and run as the runner
# user, not root. Failure to isolate must fail closed, never run tests online.
set -euo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true || "${RUNNER_OS:-}" != Linux || $# -eq 0 ]]; then
  echo 'Expected a Linux GitHub Actions runner and an explicit command.' >&2
  exit 2
fi

sudo -E unshare --net -- bash -c '
  set -euo pipefail
  ip link set lo up
  if [[ -n "$(ip route show default)" || -n "$(ip -6 route show default)" ]]; then
    echo "External route present; refusing to execute." >&2
    exit 3
  fi
  task_uid="$1"
  task_gid="$2"
  shift 2
  echo "OFFLINE NAMESPACE: loopback only; unprivileged command follows"
  exec setpriv --reuid="$task_uid" --regid="$task_gid" --init-groups "$@"
' _ "$(id -u)" "$(id -g)" "$@"
