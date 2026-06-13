import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_management_main_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetManagementMainAccountStore', () {
    const store = AssetManagementMainAccountStore();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('returns null when unset', () async {
      expect(await store.load(), isNull);
    });

    test('saves and loads the selected account id', () async {
      await store.save('smbc_otsuka');
      expect(await store.load(), 'smbc_otsuka');
    });

    test('clears the selection when saving null or empty', () async {
      await store.save('smbc_otsuka');
      await store.save(null);
      expect(await store.load(), isNull);

      await store.save('jibun');
      await store.save('   ');
      expect(await store.load(), isNull);
    });
  });
}
