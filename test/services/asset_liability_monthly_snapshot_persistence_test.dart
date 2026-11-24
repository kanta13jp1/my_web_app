import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = AssetLiabilityMonthlyStateStore();

  test('snapshot rejection preserves stored months and permits explicit retry',
      () async {
    final prefs = _SnapshotPreferences();
    await store.saveMonthlySnapshot(_snapshot('2026-04', 50), prefs: prefs);
    await store.saveMonthlySnapshot(_snapshot('2026-05', 100), prefs: prefs);
    expect(
      AssetLiabilityMonthlyStateStore.decodeMonthlySnapshots(
        prefs.values[AssetLiabilityMonthlyStateStore.monthlySnapshotPrefsKey],
      ),
      hasLength(2),
    );
    prefs.values['unrelated'] = 'keep';
    final before = Map<String, String>.from(prefs.values);
    prefs.accept = false;

    await expectLater(
      store.saveMonthlySnapshot(_snapshot('2026-05', 200), prefs: prefs),
      throwsA(isA<StateError>()),
    );
    expect(prefs.writes, 3);
    expect(prefs.values, before);
    expect(
      prefs.lastKey,
      AssetLiabilityMonthlyStateStore.monthlySnapshotPrefsKey,
    );

    prefs.accept = true;
    await store.saveMonthlySnapshot(_snapshot('2026-05', 200), prefs: prefs);
    expect(prefs.writes, 4);
    final saved = AssetLiabilityMonthlyStateStore.decodeMonthlySnapshots(
      prefs.values[AssetLiabilityMonthlyStateStore.monthlySnapshotPrefsKey],
    );
    expect(saved, hasLength(2));
    expect(saved.singleWhere((s) => s.monthKey == '2026-04').cashLikeTotal, 50);
    expect(
      saved.singleWhere((s) => s.monthKey == '2026-05').cashLikeTotal,
      200,
    );
    expect(prefs.values['unrelated'], 'keep');
  });

  test('snapshot write exception propagates unchanged without automatic retry',
      () async {
    final prefs = _SnapshotPreferences();
    await store.saveMonthlySnapshot(_snapshot('2026-05', 100), prefs: prefs);
    final before = Map<String, String>.from(prefs.values);
    final failure = StateError('synthetic snapshot write failure');
    prefs.failure = failure;

    await expectLater(
      store.saveMonthlySnapshot(_snapshot('2026-05', 200), prefs: prefs),
      throwsA(same(failure)),
    );
    expect(prefs.writes, 2);
    expect(prefs.values, before);
  });
}

AssetLiabilityMonthlySnapshot _snapshot(String monthKey, double cash) {
  return AssetLiabilityMonthlySnapshot(
    monthKey: monthKey,
    savedAt: DateTime.utc(2026, 5, 31, 20),
    positiveAssetTotal: cash,
    liabilityTotal: 0,
    netWorth: cash,
    cashLikeTotal: cash,
    monthlyScheduledPaymentTotal: 0,
    monthlyPaidPaymentTotal: 0,
    monthlyUnpaidPaymentTotal: 0,
    overduePaymentCount: 0,
  );
}

class _SnapshotPreferences extends Fake implements SharedPreferences {
  final values = <String, String>{};
  bool accept = true;
  Error? failure;
  int writes = 0;
  String? lastKey;

  @override
  Object? get(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    writes += 1;
    lastKey = key;
    if (failure != null) throw failure!;
    if (accept) values[key] = value;
    return accept;
  }
}
