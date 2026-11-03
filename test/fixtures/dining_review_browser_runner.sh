#!/usr/bin/env bash
set -euo pipefail
chromedriver --port=4444 > /tmp/dining-review-driver.log 2>&1 &
driver=$!
cleanup() {
  status=$?
  trap - EXIT
  kill "$driver" 2>/dev/null || true
  wait "$driver" 2>/dev/null || true
  if kill -0 "$driver" 2>/dev/null; then
    echo 'ChromeDriver cleanup could not be verified' >&2
    exit 1
  fi
  exit "$status"
}
trap cleanup EXIT
for i in {1..30}; do
  curl -fsS http://127.0.0.1:4444/status >/dev/null && break
  sleep 1
done
curl -fsS http://127.0.0.1:4444/status >/dev/null
flutter drive --no-pub --driver=test_driver/asset_ai_integration.dart --target=integration_test/asset_dining_review_test.dart -d web-server --browser-name=chrome --headless
