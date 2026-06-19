import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_salary_day_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = AssetSalaryDayStore();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('load returns the default when unset', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(
      await store.load(prefs: prefs),
      AssetSalaryDayStore.defaultSalaryDay,
    );
  });

  test('save then load round-trips a valid day', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(15, prefs: prefs);
    expect(await store.load(prefs: prefs), 15);
  });

  test('save clamps out-of-range days to 1..28', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(40, prefs: prefs);
    expect(await store.load(prefs: prefs), 28);
    await store.save(0, prefs: prefs);
    expect(await store.load(prefs: prefs), 1);
  });

  test('encodeMirrorValue clamps and wraps as {day: N}', () {
    expect(AssetSalaryDayStore.encodeMirrorValue(15), <String, dynamic>{
      'day': 15,
    });
    expect(AssetSalaryDayStore.encodeMirrorValue(99), <String, dynamic>{
      'day': 28,
    });
  });

  test('decodeMirrorValue parses, clamps, and falls back to default', () {
    expect(AssetSalaryDayStore.decodeMirrorValue(<String, dynamic>{'day': 10}),
        10);
    expect(AssetSalaryDayStore.decodeMirrorValue(<String, dynamic>{'day': 99}),
        28);
    expect(
      AssetSalaryDayStore.decodeMirrorValue('nope'),
      AssetSalaryDayStore.defaultSalaryDay,
    );
    expect(
      AssetSalaryDayStore.decodeMirrorValue(<String, dynamic>{}),
      AssetSalaryDayStore.defaultSalaryDay,
    );
  });
}
