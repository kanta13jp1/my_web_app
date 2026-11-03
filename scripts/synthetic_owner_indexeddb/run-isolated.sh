#!/usr/bin/env bash
set -euo pipefail
# Run only on a disposable Linux runner after Playwright and Chromium are installed.
# Arguments are an absolute Playwright module path and browser cache path.
test "$#" -eq 2
case "$1" in /*) ;; *) exit 2;; esac
case "$2" in /*) ;; *) exit 2;; esac
test -d "$1"
test -d "$2"
test -d "${RUNNER_TEMP:?}"
probe_dir=$(cd -- "$(dirname -- "$0")" && pwd -P)
probe_user=$(id -un)
runner_home=$(mktemp -d "$RUNNER_TEMP/synthetic-idb-home.XXXXXXXX")
timeout 120s sudo unshare --net -- bash -c '
  set -euo pipefail
  ip link set lo up
  exec runuser -u "$1" -- env -i PATH="$2" HOME="$3" RUNNER_TEMP="$4" \
    PLAYWRIGHT_BROWSERS_PATH="$5" CI=true node "$6/probe.cjs" "$7"
' _ "$probe_user" "$PATH" "$runner_home" "$RUNNER_TEMP" "$2" "$probe_dir" "$1"
