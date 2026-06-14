import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/drink_challenge_service.dart';
import 'package:my_web_app/services/drink_challenge_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrinkChallengeStore', () {
    const store = DrinkChallengeStore();

    test('round-trips records through SharedPreferences', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        <String, DrinkRecordStatus>{
          '2026-06-19': DrinkRecordStatus.abstained,
          '2026-06-20': DrinkRecordStatus.drank,
        },
        prefs: prefs,
      );

      final loaded = await store.load(prefs: prefs);
      expect(loaded['2026-06-19'], DrinkRecordStatus.abstained);
      expect(loaded['2026-06-20'], DrinkRecordStatus.drank);
    });

    test('returns empty map when nothing stored', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      expect(await store.load(prefs: prefs), isEmpty);
    });

    test('save with empty map clears the key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      await store.save(
        <String, DrinkRecordStatus>{
          '2026-06-19': DrinkRecordStatus.abstained,
        },
        prefs: prefs,
      );
      await store.save(
        const <String, DrinkRecordStatus>{},
        prefs: prefs,
      );
      expect(await store.load(prefs: prefs), isEmpty);
    });
  });
}
