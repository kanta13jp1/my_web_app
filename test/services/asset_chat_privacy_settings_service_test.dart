import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_chat_privacy_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'money range protection is off by default and persists opt-in',
    () async {
      const service = AssetChatPrivacySettingsService();

      expect(await service.loadMaskMoneyAmounts(), isFalse);

      await service.saveMaskMoneyAmounts(true);
      expect(await service.loadMaskMoneyAmounts(), isTrue);

      await service.saveMaskMoneyAmounts(false);
      expect(await service.loadMaskMoneyAmounts(), isFalse);
    },
  );
}
