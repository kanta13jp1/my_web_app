#!/usr/bin/env bash
set -euo pipefail
test "$(ip -o link show | wc -l)" -eq 1
python3 -B test/fixtures/dining_page_stub.py > /tmp/dining-page-fixture.log 2>&1 &
server=$!
chromedriver --port=4444 > /tmp/dining-integration-driver.log 2>&1 &
driver=$!
cleanup() {
  status=$?
  trap - EXIT
  if [ "$status" -ne 0 ]; then
    echo "fixture rejection diagnostic (fixed categories only):" >&2
    grep "^FIXTURE_REJECTED " /tmp/dining-page-fixture.log >&2 || true
  fi
  kill "$driver" "$server" 2>/dev/null || true
  wait "$driver" 2>/dev/null || true
  wait "$server" 2>/dev/null || true
  if kill -0 "$driver" 2>/dev/null || kill -0 "$server" 2>/dev/null; then
    echo 'fixture process cleanup could not be verified' >&2
    exit 1
  fi
  exit "$status"
}
trap cleanup EXIT
for _ in {1..30}; do
  if curl -fsS http://127.0.0.1:18765/__fixture_status >/dev/null 2>&1 &&
      curl -fsS http://127.0.0.1:4444/status >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$server" 2>/dev/null || ! kill -0 "$driver" 2>/dev/null; then
    echo 'fixture server or driver exited during startup' >&2
    exit 1
  fi
  sleep 1
done
curl -fsS http://127.0.0.1:18765/__fixture_status >/dev/null
curl -fsS http://127.0.0.1:4444/status >/dev/null
timeout 240s flutter drive --no-pub --no-web-resources-cdn \
  --driver=test_driver/asset_ai_integration.dart \
  --target=integration_test/asset_dining_synthetic_integration_test.dart \
  -d web-server --browser-name=chrome --headless
curl -fsS http://127.0.0.1:18765/__fixture_status | python3 -c '
import json, sys
s = json.load(sys.stdin)
assert s["auth"] == 2 and s["flows_a"] > 0 and s["flows_b"] > 0
assert s["reflection_a"] > 0 and s["reflection_b"] > 0
assert s["read_rpc_a"] == 1 and s["read_rpc_b"] == 1
assert s["rejected_telemetry"] == 1 and s["rejected_authorized_telemetry"] == 1
assert s["rejected_writes"] == s["rejected_telemetry"] and s["rejected_identity"] == 0
print("fixture audit passed: synthetic reads; one rejected telemetry write; no persistence")
'
