import 'package:integration_test/integration_test.dart';
import '../test/widgets/asset_auto_debit_bulk_guard_test.dart' as bulk;
import '../test/widgets/asset_salary_confirmation_guard_test.dart' as salary;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const suite = String.fromEnvironment('ASSET_GUARD_SUITE', defaultValue: 'bulk');
  if (suite == 'salary') {
    salary.main();
  } else {
    bulk.main();
  }
}
