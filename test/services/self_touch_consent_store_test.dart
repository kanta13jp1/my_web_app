import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/self_touch_consent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('grantConsent persists the version and timestamp locally', () async {
    final store = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 9, 3, 3, 0);

    await SelfTouchConsentStore.grantConsent(
      version: SelfTouchDisclosure.fallback.version,
      preferences: store,
      now: now,
    );

    expect(
      await SelfTouchConsentStore.hasCurrentConsent(
        version: SelfTouchDisclosure.fallback.version,
        preferences: store,
      ),
      isTrue,
    );
    expect(
      store.getString(SelfTouchConsentStore.localConsentedAtKey),
      now.toIso8601String(),
    );
  });

  test('a stale disclosure version requires acknowledgement again', () async {
    final store = await SharedPreferences.getInstance();
    await store.setString(
      SelfTouchConsentStore.localVersionKey,
      '2026-08-01-v1',
    );
    await store.setString(
      SelfTouchConsentStore.localConsentedAtKey,
      DateTime.utc(2026, 8, 1).toIso8601String(),
    );

    expect(
      await SelfTouchConsentStore.hasCurrentConsent(
        version: SelfTouchDisclosure.fallback.version,
        preferences: store,
      ),
      isFalse,
    );
  });

  test('invalid remote disclosure data cannot replace the safe fallback', () {
    expect(
      SelfTouchDisclosure.fromJson(<String, dynamic>{
        'version': 'v2',
        'title': 'title',
        'body': 'body',
        'support_label': 'support',
        'support_url': 'javascript:alert(1)',
      }),
      isNull,
    );
  });
}
