import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/asset_triage_withdrawal_scenarios.dart'
    as scenarios;

class _DiagnosticBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  void reportExceptionNoticed(FlutterErrorDetails exception) {
    debugPrint(exception.toString());
    super.reportExceptionNoticed(exception);
  }
}

void main() {
  _DiagnosticBinding();
  scenarios.main();
}
