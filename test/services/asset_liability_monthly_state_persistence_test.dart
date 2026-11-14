import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = AssetLiabilityMonthlyStateStore();
  const state = AssetLiabilityMonthlyState(
    paymentOverrides: <String, double>{'synthetic_payment': 100},
  );

  for (final position in <int>[1, 7, 14]) {
    test('monthly state rejection at write $position stops and permits retry',
        () async {
      final prefs = _MonthPreferences();
      await store.saveMonth(
        month: DateTime(2026, 4),
        state: state,
        prefs: prefs,
      );
      prefs.values['unrelated'] = 'keep';
      final before = Map<String, String>.from(prefs.values);
      prefs.writes = 0;
      prefs.rejectAt = position;

      await expectLater(
        store.saveMonth(
          month: DateTime(2026, 5),
          state: state,
          prefs: prefs,
        ),
        throwsA(isA<StateError>()),
      );
      expect(prefs.writes, position);
      expect(prefs.values['unrelated'], 'keep');
      for (final key in before.keys.where((key) => key != 'unrelated')) {
        final current = jsonDecode(prefs.values[key]!) as Map<String, dynamic>;
        final original = jsonDecode(before[key]!) as Map<String, dynamic>;
        expect(current['2026-04'], original['2026-04'], reason: key);
      }

      prefs.rejectAt = null;
      await store.saveMonth(
        month: DateTime(2026, 5),
        state: state,
        prefs: prefs,
      );
      expect(prefs.writes, position + 14);
      final payments = jsonDecode(
        prefs.values[AssetLiabilityMonthlyStateStore.paymentPrefsKey]!,
      ) as Map<String, dynamic>;
      expect(payments['2026-04'], <String, dynamic>{'synthetic_payment': 100});
      expect(payments['2026-05'], <String, dynamic>{'synthetic_payment': 100});
      expect(prefs.values['unrelated'], 'keep');
    });
  }

  test('monthly state write exception propagates without automatic retry',
      () async {
    final failure = StateError('synthetic monthly state failure');
    final prefs = _MonthPreferences()
      ..throwAt = 2
      ..failure = failure;

    await expectLater(
      store.saveMonth(
        month: DateTime(2026, 5),
        state: state,
        prefs: prefs,
      ),
      throwsA(same(failure)),
    );
    expect(prefs.writes, 2);
  });
}

class _MonthPreferences extends Fake implements SharedPreferences {
  final values = <String, String>{};
  int writes = 0;
  int? rejectAt;
  int? throwAt;
  Error? failure;

  @override
  Object? get(String key) => values[key];

  @override
  Future<bool> setString(String key, String value) async {
    writes += 1;
    if (writes == throwAt) throw failure!;
    if (writes == rejectAt) return false;
    values[key] = value;
    return true;
  }
}
