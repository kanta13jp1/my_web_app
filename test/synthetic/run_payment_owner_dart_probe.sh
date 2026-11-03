#!/usr/bin/env bash
set -euo pipefail
flutter test --no-pub test/payment_owner_candidate_stub_test.dart --reporter expanded
dart compile js web/payment_owner_candidate_probe.dart -o "$SYNTHETIC_DART_JS"
timeout 90s node test/synthetic/payment_owner_dart_idb_probe.cjs
timeout 90s node test/synthetic/payment_owner_prefix_loss_probe.cjs
