import 'package:integration_test/integration_test.dart';
import 'asset_triage_withdrawal_scenarios.dart' as scenarios;

// Synthetic persistence boundaries; no authenticated backend or real withdrawal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.main();
}
