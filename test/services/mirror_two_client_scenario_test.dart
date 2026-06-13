import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_expected_inflow_store.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ミラー系 (入金予定 / 表示設定) の「端末A → サーバ → 端末B」統合シナリオ。
///
/// サーバは asset_pref_mirror / inflow ミラーの行リスト (List<Map>) として
/// 模擬し、端末の切替は SharedPreferences のモック初期値を差し替えて表現する
/// (切替後は旧ハンドルへ触らない逐次シミュレーション)。supabase クライアント
/// 本体の fake 化は auth セッション偽装が必要になるため採らない (part 283 判断)。

const String _inflowItemsKey = 'asset_expected_inflows_v1';

Future<SharedPreferences> _switchClient([
  Map<String, Object> seed = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

/// ページの upsert と同じ shape でローカル状態をサーバ行へ展開する。
List<Map<String, dynamic>> _uploadInflows(
  List<AssetExpectedInflow> items,
  List<AssetExpectedInflowRule> rules,
) {
  return <Map<String, dynamic>>[
    for (final rule in rules)
      <String, dynamic>{
        'id': rule.id,
        'kind': 'rule',
        'day_of_month': rule.dayOfMonth,
        'amount': rule.amount,
        'label': rule.label,
      },
    for (final item in items)
      <String, dynamic>{
        'id': item.id,
        'kind': 'one_time',
        'date': item.date.toUtc().toIso8601String(),
        'amount': item.amount,
        'label': item.label,
      },
  ];
}

void main() {
  group('mirror two-client scenarios', () {
    test('client A uploads inflows and empty client B restores identically',
        () async {
      final prefsA = await _switchClient();
      final storeA = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );
      await storeA.add(
        date: DateTime(2026, 6, 25),
        amount: 280000,
        label: '給料',
        prefs: prefsA,
      );
      await storeA.add(
        date: DateTime(2026, 6, 30),
        amount: 12000,
        label: 'フリマ売上',
        prefs: prefsA,
      );
      await storeA.addRule(
        dayOfMonth: 15,
        amount: 30000,
        label: '副業振込',
        prefs: prefsA,
      );
      final itemsA = await storeA.loadAll(prefs: prefsA);
      final rulesA = await storeA.loadRules(prefs: prefsA);
      final serverRows = _uploadInflows(itemsA, rulesA);

      final prefsB = await _switchClient();
      final storeB = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 13, 10),
      );
      final restored = await storeB.restoreFromMirrorRows(
        serverRows,
        prefs: prefsB,
      );

      expect(restored, isTrue);
      final itemsB = await storeB.loadAll(prefs: prefsB);
      final rulesB = await storeB.loadRules(prefs: prefsB);
      expect(
        itemsB.map((item) => '${item.id}|${item.date}|${item.amount}'),
        itemsA.map((item) => '${item.id}|${item.date}|${item.amount}'),
      );
      expect(rulesB.single.id, rulesA.single.id);
      expect(rulesB.single.dayOfMonth, 15);

      // 既にローカルがある端末では復元は no-op (上書き事故防止)。
      expect(
        await storeB.restoreFromMirrorRows(serverRows, prefs: prefsB),
        isFalse,
      );
    });

    test(
        'client B addition merges into client A as union '
        '(local deletion resurrects without tombstones)', () async {
      // 端末A: 2件登録してサーバへ反映。
      final prefsA1 = await _switchClient();
      final storeA = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 13, 9),
      );
      await storeA.add(
        date: DateTime(2026, 6, 25),
        amount: 280000,
        label: '給料',
        prefs: prefsA1,
      );
      await storeA.add(
        date: DateTime(2026, 6, 30),
        amount: 12000,
        label: 'フリマ売上',
        prefs: prefsA1,
      );
      var serverRows = _uploadInflows(
        await storeA.loadAll(prefs: prefsA1),
        const <AssetExpectedInflowRule>[],
      );
      final snapshotA = <String, Object>{
        _inflowItemsKey: prefsA1.getString(_inflowItemsKey)!,
      };

      // 端末B: 復元後に1件追加してサーバへ反映。
      final prefsB = await _switchClient();
      final storeB = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 14, 9),
      );
      await storeB.restoreFromMirrorRows(serverRows, prefs: prefsB);
      await storeB.add(
        date: DateTime(2026, 7, 10),
        amount: 50000,
        label: 'ボーナス',
        prefs: prefsB,
      );
      serverRows = _uploadInflows(
        await storeB.loadAll(prefs: prefsB),
        const <AssetExpectedInflowRule>[],
      );
      expect(serverRows, hasLength(3));

      // 端末Aへ戻り、フリマ売上をローカル削除してから手動統合する。
      final prefsA2 = await _switchClient(snapshotA);
      final removedId = (await storeA.loadAll(prefs: prefsA2))
          .firstWhere((item) => item.label == 'フリマ売上')
          .id;
      await storeA.remove(removedId, prefs: prefsA2);

      final added = await storeA.mergeFromMirrorRows(
        serverRows,
        prefs: prefsA2,
      );
      final merged = await storeA.loadAll(prefs: prefsA2);

      // 和集合マージ: B の追加分に加え、トゥームストーンが無いため
      // ローカル削除済みの ID もサーバ残存分から復活する (仕様の明文化)。
      expect(added, 2);
      expect(merged, hasLength(3));
      expect(merged.map((item) => item.label), contains('ボーナス'));
      expect(merged.map((item) => item.id), contains(removedId));
    });

    test('client B applies display prefs diff from client A rows', () async {
      // 端末A: 標準モード + グラフ常時表示を保存しサーバ行へ展開。
      final prefsA = await _switchClient();
      const displayStore = AssetManagementDisplayModeStore();
      await displayStore.save(
        AssetManagementDisplayMode.standard,
        prefs: prefsA,
        recordEvent: false,
      );
      await displayStore.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.pinned,
        prefs: prefsA,
      );
      final modeA = await displayStore.load(prefs: prefsA);
      final overridesA = await displayStore.loadOverrides(prefs: prefsA);
      final updatedAt = DateTime(2026, 6, 13, 12).toUtc().toIso8601String();
      final serverRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'pref_key': 'display_mode',
          'value': <String, dynamic>{'mode': modeA.storageId},
          'updated_at': updatedAt,
        },
        <String, dynamic>{
          'pref_key': 'section_overrides',
          'value': <String, dynamic>{
            for (final entry in overridesA.entries)
              entry.key.storageId: entry.value.storageId,
          },
          'updated_at': updatedAt,
        },
      ];

      // 端末B: ミニマム運用中。通知判定 → 差分プレビュー → 適用。
      final prefsB = await _switchClient(<String, Object>{
        'asset_management_display_mode_v1': 'minimum',
      });
      final modeB = await displayStore.load(prefs: prefsB);
      final overridesB = await displayStore.loadOverrides(prefs: prefsB);
      final diff = AssetManagementDisplayModeStore.evaluateMirrorPrefRows(
        rows: serverRows,
        currentMode: modeB,
        currentOverrides: overridesB,
        localChangedAt: DateTime(2026, 6, 13, 8),
      );

      expect(diff.mode, AssetManagementDisplayMode.standard);
      final preview = AssetManagementDisplayModeStore.describeMirrorPrefsDiff(
        currentMode: modeB,
        currentOverrides: overridesB,
        diff: diff,
      );
      expect(preview, contains('表示モード: ミニマム → 標準'));
      expect(preview, contains('グラフ: 自動 → 常に表示'));

      final newMode = diff.mode;
      if (newMode != null) {
        await displayStore.save(newMode, prefs: prefsB, recordEvent: false);
      }
      for (final entry in (diff.overrides ?? overridesB).entries) {
        await displayStore.saveOverride(
          entry.key,
          entry.value,
          prefs: prefsB,
        );
      }

      expect(await displayStore.load(prefs: prefsB), modeA);
      expect(await displayStore.loadOverrides(prefs: prefsB), overridesA);
    });
  });
}
