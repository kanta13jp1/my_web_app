import 'package:integration_test/integration_test.dart';
import 'asset_bulk_guard_scenarios.dart' as bulk;
import 'asset_salary_guard_scenarios.dart' as salary;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const suite = String.fromEnvironment('SUITE', defaultValue: 'bulk');
  if (suite == 'salary') {
    salary.main();
  } else {
    bulk.main();
  }
}
