import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default telemetry tolerates an uninitialized application client', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ShopFunnelService();
    final visitor = await service.visitorId();
    expect(visitor, isNotNull);
    expect(await service.visitorId(), visitor);
    await expectLater(
      service.record('product_view', productId: 'hexciv-win64'),
      completes,
    );
  });
}