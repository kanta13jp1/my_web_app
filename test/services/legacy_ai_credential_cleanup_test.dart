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
  test('secure cleanup still runs when preferences are unavailable', () async {
    final deleted = <String>[];
    final cleanup = LegacyAiCredentialCleanup(
      preferencesProvider: () async => throw StateError('fixture preferences'),
      secureDelete: (key) async => deleted.add(key),
    );

    await expectLater(cleanup.run(), throwsStateError);
    expect(deleted, <String>['gemini_api_key']);
  });

  test('preferences cleanup still runs when secure cleanup fails', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'gemini_api_key': 'synthetic obsolete value',
      'theme_mode': 'dark',
    });
    final cleanup = LegacyAiCredentialCleanup(
      secureDelete: (key) async => throw StateError('fixture secure store'),
    );

    await expectLater(cleanup.run(), throwsStateError);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('gemini_api_key'), isFalse);
    expect(preferences.getString('theme_mode'), 'dark');
  });

  test('cleanup can retry after a synchronous secure delete failure', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'gemini_api_key': 'synthetic obsolete value',
    });
    var calls = 0;
    final cleanup = LegacyAiCredentialCleanup(
      secureDelete: (key) {
        calls += 1;
        if (calls == 1) throw StateError('fixture synchronous failure');
        return Future<void>.value();
      },
    );

    await expectLater(cleanup.run(), throwsStateError);
    await cleanup.run();
    expect(calls, 2);
  });
}
