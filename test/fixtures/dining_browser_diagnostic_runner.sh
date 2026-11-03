#!/usr/bin/env bash
set -euo pipefail
diagnostic_dir="$PWD/dining-browser-diagnostic"
mkdir -p "$diagnostic_dir"
chromedriver --port=4444 --verbose > "$diagnostic_dir/chromedriver.log" 2>&1 &
driver=$!
cleanup() {
  status=$?
  trap - EXIT
  kill "$driver" 2>/dev/null || true
  wait "$driver" 2>/dev/null || true
  python3 - "$diagnostic_dir/chromedriver.log" <<'PY' || true
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(errors='replace').lower()
for label, marker in [('error-lines', '[severe]'), ('navigation-events', 'navigate'),
                      ('timeout-events', 'timeout'), ('session-events', 'session')]:
    print('driver diagnostic:', label, sum(marker in line for line in text.splitlines()))
PY
  if kill -0 "$driver" 2>/dev/null; then
    echo 'ChromeDriver cleanup could not be verified' >&2
    exit 1
  fi
  exit "$status"
}
trap cleanup EXIT
for i in {1..30}; do
  curl -fsS http://127.0.0.1:4444/status >/dev/null 2>&1 && break
  sleep 1
done
curl -fsS http://127.0.0.1:4444/status >/dev/null
echo 'diagnostic: starting Flutter fixture'
timeout 180s flutter drive --no-pub --driver=test_driver/asset_ai_integration.dart --target=integration_test/asset_dining_review_test.dart -d web-server --browser-name=chrome --headless
