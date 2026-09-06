import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import 'asset_ai_current_input_scenarios.dart' as scenarios;

class _DiagnosticBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    (reportData ??= <String, dynamic>{})['firstFrameworkError'] =
        exception.toString();
    super.reportExceptionNoticed(exception);
  }
}

// Run the same page interactions on a real browser engine, with controlled
// synthetic AI/history/repository boundaries. This is not an authenticated
// backend persistence or browser-reload test; those remain separate gates.
void main() {
  _DiagnosticBinding();
  scenarios.main();
}
