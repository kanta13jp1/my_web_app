import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/legacy_ai_credential_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deletes legacy AI credentials without touching unrelated settings',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'gemini_api_key': 'discard-me',
      'theme_mode': 'dark',
    });
    final secureDeletes = <String>[];
    final cleanup = LegacyAiCredentialCleanup(
      secureDelete: (key) async => secureDeletes.add(key),
    );

    await cleanup.run();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('gemini_api_key'), isFalse);
    expect(preferences.getString('theme_mode'), 'dark');
    expect(secureDeletes, <String>['gemini_api_key']);
  });
}
