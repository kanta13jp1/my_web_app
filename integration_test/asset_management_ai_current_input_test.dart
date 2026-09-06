import 'package:integration_test/integration_test.dart';

import 'asset_ai_current_input_scenarios.dart' as scenarios;

// Run the same page interactions on a real browser engine, with controlled
// synthetic AI/history/repository boundaries. This is not an authenticated
// backend persistence or browser-reload test; those remain separate gates.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.main();
}
