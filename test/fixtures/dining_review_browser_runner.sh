#!/usr/bin/env bash
set -euo pipefail
chromedriver --port=4444 > /tmp/dining-review-driver.log 2>&1 &
driver=$!
trap 'kill "$driver" 2>/dev/null || true' EXIT
for i in {1..30}; do
  curl -fsS http://127.0.0.1:4444/status >/dev/null && break
  sleep 1
done
curl -fsS http://127.0.0.1:4444/status >/dev/null
flutter drive --driver=test_driver/asset_ai_integration.dart --target=integration_test/asset_dining_review_test.dart -d web-server --browser-name=chrome --headless
