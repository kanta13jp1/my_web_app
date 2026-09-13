import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import 'asset_triage_withdrawal_scenarios.dart' as scenarios;

class _DiagnosticBinding extends IntegrationTestWidgetsFlutterBinding {
  @override
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    final data = reportData ??= <String, dynamic>{};
    data.putIfAbsent('firstFrameworkError', () => exception.toString());
    super.reportExceptionNoticed(exception);
  }
}

// Synthetic persistence boundaries; no authenticated backend or real withdrawal.
void main() {
  _DiagnosticBinding();
  scenarios.main();
}
