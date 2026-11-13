import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'asset_savings_scenarios.dart' as savings;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const width = int.fromEnvironment('WIDTH', defaultValue: 1200);
  setUp(() => binding.setSurfaceSize(Size(width.toDouble(), 844)));
  savings.main();
}
