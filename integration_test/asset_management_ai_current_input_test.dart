import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'asset_ai_current_input_scenarios.dart' as scenarios;

// Run the same page interactions on a real browser engine, with controlled
// synthetic AI/history/repository boundaries. This is not an authenticated
// backend persistence or browser-reload test; those remain separate gates.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  binding.reportData = <String, dynamic>{'frameworkErrors': errors};
  setUp(() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.toString());
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  });
  scenarios.main();
}
