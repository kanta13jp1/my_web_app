import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_salary_amount_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = AssetSalaryAmountStore();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('load returns null when unset', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(await store.load(prefs: prefs), isNull);
  });

  test('save then load round-trips a valid amount', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(280000, prefs: prefs);
    expect(await store.load(prefs: prefs), 280000);
  });

  test('save with null or non-positive clears to unset (null)', () async {
    final prefs = await SharedPreferences.getInstance();
    await store.save(280000, prefs: prefs);
    expect(await store.load(prefs: prefs), 280000);
    await store.save(0, prefs: prefs);
    expect(await store.load(prefs: prefs), isNull);
    await store.save(150000, prefs: prefs);
    await store.save(null, prefs: prefs);
    expect(await store.load(prefs: prefs), isNull);
  });

  test('normalize rejects 0/negative/NaN and caps the max', () {
    expect(AssetSalaryAmountStore.normalize(null), isNull);
    expect(AssetSalaryAmountStore.normalize(0), isNull);
    expect(AssetSalaryAmountStore.normalize(-1), isNull);
    expect(AssetSalaryAmountStore.normalize(double.nan), isNull);
    expect(AssetSalaryAmountStore.normalize(280000), 280000);
    const overMax = AssetSalaryAmountStore.maxSalaryAmount + 1;
    expect(
      AssetSalaryAmountStore.normalize(overMax),
      AssetSalaryAmountStore.maxSalaryAmount,
    );
  });

  test('encodeMirrorValue wraps as {amount: N}', () {
    expect(AssetSalaryAmountStore.encodeMirrorValue(280000), <String, dynamic>{
      'amount': 280000,
    });
  });

  test('decodeMirrorValue parses, normalizes, and falls back to null', () {
    expect(
      AssetSalaryAmountStore.decodeMirrorValue(<String, dynamic>{
        'amount': 280000,
      }),
      280000,
    );
    expect(
      AssetSalaryAmountStore.decodeMirrorValue(<String, dynamic>{'amount': 0}),
      isNull,
    );
    expect(AssetSalaryAmountStore.decodeMirrorValue('nope'), isNull);
    expect(
      AssetSalaryAmountStore.decodeMirrorValue(<String, dynamic>{}),
      isNull,
    );
  });
}
