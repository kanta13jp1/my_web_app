#!/usr/bin/env bash
set -euo pipefail
cd "$SCRATCH"
if [[ ! -d .ci-logs || -L .ci-logs ]]; then
  echo 'Invalid screenshot parent directory'; exit 1
fi
if [[ -e .ci-logs/asset-triage-visual || -L .ci-logs/asset-triage-visual ]]; then
  echo 'Refusing pre-existing screenshot output directory'; exit 1
fi
python3 -B scripts/prepare_browser_scratch.py
flutter pub get --offline
chromedriver --port=4444 --allowed-ips=127.0.0.1 > "$SCRATCH/chromedriver-private.log" 2>&1 &
driver_pid=$!
trap 'kill "$driver_pid" 2>/dev/null || true; wait "$driver_pid" 2>/dev/null || true' EXIT
for attempt in {1..30}; do
  if ! kill -0 "$driver_pid" 2>/dev/null; then
    echo 'ChromeDriver exited before readiness'; exit 1
  fi
  if curl --fail --silent http://127.0.0.1:4444/status > /dev/null; then break; fi
  sleep 1
done
curl --fail --silent http://127.0.0.1:4444/status > /dev/null
flutter drive --no-pub --driver=test_driver/asset_triage_visual.dart \
  --target=integration_test/asset_debt_read_browser_test.dart \
  --browser-dimension=1440x1000@1 -d web-server --browser-name=chrome --headless
for name in existing failed missing; do
  test -s ".ci-logs/asset-triage-visual/synthetic-debt-read-$name.png"
done
