import 'package:integration_test/integration_test.dart';
import '../test/widgets/expense_classification_review_test.dart' as scenarios;

// Browser UI boundary with synthetic server responses; no real keys or expenses.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  scenarios.main();
}
