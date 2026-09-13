import 'package:integration_test/integration_test.dart';
import '../test/widgets/asset_triage_withdrawal_test.dart' as scenarios;

// Synthetic persistence boundaries; no authenticated backend or real withdrawal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.main();
}
