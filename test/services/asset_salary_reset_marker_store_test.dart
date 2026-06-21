import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = AssetSalaryResetMarkerStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AssetSalaryResetMarkerStore', () {
    test('default is null when nothing saved', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(await store.load(prefs: prefs), isNull);
    });

    test('save / load round-trips a valid cycle key', () async {
      final prefs = await SharedPreferences.getInstance();
      await store.save('2026-06', prefs: prefs);
      expect(await store.load(prefs: prefs), '2026-06');
    });

    test('save null clears the marker', () async {
      final prefs = await SharedPreferences.getInstance();
      await store.save('2026-06', prefs: prefs);
      await store.save(null, prefs: prefs);
      expect(await store.load(prefs: prefs), isNull);
    });

    test('invalid stored value is treated as null', () async {
      final prefs = await SharedPreferences.getInstance();
      await store.save('not-a-cycle', prefs: prefs);
      expect(await store.load(prefs: prefs), isNull);
    });

    test('encode / decode mirror value round-trips', () {
      final encoded = AssetSalaryResetMarkerStore.encodeMirrorValue('2026-06');
      expect(encoded, <String, dynamic>{'cycle': '2026-06'});
      expect(
        AssetSalaryResetMarkerStore.decodeMirrorValue(encoded),
        '2026-06',
      );
    });

    test('decode rejects malformed mirror values', () {
      expect(AssetSalaryResetMarkerStore.decodeMirrorValue(null), isNull);
      expect(
        AssetSalaryResetMarkerStore.decodeMirrorValue(<String, dynamic>{}),
        isNull,
      );
      expect(
        AssetSalaryResetMarkerStore.decodeMirrorValue(
          <String, dynamic>{'cycle': '2026/06'},
        ),
        isNull,
      );
    });

    test('mergeLater keeps the chronologically newer cycle', () {
      expect(
        AssetSalaryResetMarkerStore.mergeLater('2026-05', '2026-06'),
        '2026-06',
      );
      expect(
        AssetSalaryResetMarkerStore.mergeLater('2026-06', '2026-05'),
        '2026-06',
      );
      // 年跨ぎ。
      expect(
        AssetSalaryResetMarkerStore.mergeLater('2025-12', '2026-01'),
        '2026-01',
      );
    });

    test('isResetPending is false until a different cycle is current', () {
      // marker 未設定(初回) → 保留でない(当日サイクル採用)。
      expect(
        AssetSalaryResetMarkerStore.isResetPending(
          dateCycleKey: '2026-06',
          ackedCycleKey: null,
        ),
        isFalse,
      );
      // 当日サイクルを承認済み → 保留でない。
      expect(
        AssetSalaryResetMarkerStore.isResetPending(
          dateCycleKey: '2026-06',
          ackedCycleKey: '2026-06',
        ),
        isFalse,
      );
      // 前サイクルまでしか承認していない → 当日サイクルはリセット保留。
      expect(
        AssetSalaryResetMarkerStore.isResetPending(
          dateCycleKey: '2026-06',
          ackedCycleKey: '2026-05',
        ),
        isTrue,
      );
    });

    test('mergeLater never regresses past a null/invalid side', () {
      expect(
          AssetSalaryResetMarkerStore.mergeLater(null, '2026-06'), '2026-06');
      expect(
          AssetSalaryResetMarkerStore.mergeLater('2026-06', null), '2026-06');
      expect(AssetSalaryResetMarkerStore.mergeLater(null, null), isNull);
      // 不正値は無視され、有効な方が残る。
      expect(
        AssetSalaryResetMarkerStore.mergeLater('bad', '2026-06'),
        '2026-06',
      );
    });
  });
}
