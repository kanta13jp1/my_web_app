#!/usr/bin/env bash
set -euo pipefail
cd "$SCRATCH"
python3 -B scripts/prepare_debt_read_sandbox.py "$SCRATCH"
# Dependency cache was populated before entering the isolated network.
flutter pub get --offline
flutter test test/widgets/debt_read_fail_closed_synthetic_test.dart \
  --no-pub --reporter expanded | tee "$SCRATCH/.debt-read-test.log"
python3 -B scripts/verify_debt_read_result.py "$SCRATCH/.debt-read-test.log"
