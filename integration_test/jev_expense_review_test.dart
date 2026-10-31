import 'package:integration_test/integration_test.dart';
import 'jev_expense_review_scenarios.dart' as scenarios;
import 'jev_expense_review_search_scenarios.dart' as search_scenarios;

// Browser UI boundary with synthetic server responses; no real keys or expenses.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  search_scenarios.main(
    capture: (name) async {
      await binding.takeScreenshot(name);
    },
  );
  scenarios.main(
    capture: (name) async {
      await binding.takeScreenshot(name);
    },
  );
}
