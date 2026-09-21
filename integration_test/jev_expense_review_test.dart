import 'package:integration_test/integration_test.dart';
import 'jev_expense_review_scenarios.dart' as scenarios;

// Browser UI boundary with synthetic server responses; no real keys or expenses.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.main();
}
