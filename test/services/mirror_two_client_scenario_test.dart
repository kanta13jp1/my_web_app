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
const String _inflowDeletedIdsKey = 'asset_expected_inflow_deleted_ids_v1';
const String _sectionOverridesKey = 'asset_management_section_overrides_v1';
const String _sectionOverrideDeletedKey =
    'asset_management_section_override_deleted_v1';

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
        '(tombstone prevents local-deletion resurrection)', () async {
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

      // 和集合マージ (#part285 本対策): B の追加分 (ボーナス) のみ取り込み、
      // ローカル削除済みの ID はトゥームストーンにより復活しない。
      expect(added, 1);
      expect(merged, hasLength(2));
      expect(merged.map((item) => item.label), contains('ボーナス'));
      expect(merged.map((item) => item.id), isNot(contains(removedId)));
    });

    test('client A deletion propagates to client B via remote tombstones',
        () async {
      // 端末A: 2件登録 → サーバ行へ展開 (ID はサーバ行が保持する)。
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
      final serverRows = _uploadInflows(
        await storeA.loadAll(prefs: prefsA),
        const <AssetExpectedInflowRule>[],
      );
      final removedId = serverRows
          .firstWhere((row) => row['label'] == 'フリマ売上')['id']
          .toString();
      // 端末A でローカル削除 → トゥームストーン (= サーバへ上げる集合) を得る。
      await storeA.remove(removedId, prefs: prefsA);
      final tombstones = (await storeA.loadDeletedIds(prefs: prefsA)).toList();
      expect(tombstones, contains(removedId));

      // 端末B: サーバから復元すると A と同じ ID 集合を保持する。
      final prefsB = await _switchClient();
      final storeB = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 14, 9),
      );
      await storeB.restoreFromMirrorRows(serverRows, prefs: prefsB);
      expect(await storeB.loadAll(prefs: prefsB), hasLength(2));

      // 端末B がサーバ経由のトゥームストーンを取り込む → 同 ID が消える。
      final removed = await storeB.applyRemoteDeletedIds(
        tombstones,
        prefs: prefsB,
      );

      expect(removed, 1);
      final itemsB = await storeB.loadAll(prefs: prefsB);
      expect(itemsB.single.label, '給料');
      expect(itemsB.map((e) => e.id), isNot(contains(removedId)));
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

    test(
        'full round trip: A deletes → server → B reflects → B re-uploads → '
        'A keeps deletion', () async {
      // 端末A: I1(給料)+I2(フリマ) を登録しサーバ行へ。
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
      final serverInitial = _uploadInflows(
        await storeA.loadAll(prefs: prefsA1),
        const <AssetExpectedInflowRule>[],
      );
      final removedId = serverInitial
          .firstWhere((row) => row['label'] == 'フリマ売上')['id']
          .toString();

      // 端末A: I2 をローカル削除 → トゥームストーンをミラー値 (encode) へ。
      await storeA.remove(removedId, prefs: prefsA1);
      final tombstoneMirror = AssetExpectedInflowStore.encodeDeletedIdsMirror(
        await storeA.loadDeletedIds(prefs: prefsA1),
      );
      // A の削除後スナップショット (items + tombstone) を控える。
      final aSnapshot = <String, Object>{
        _inflowItemsKey: prefsA1.getString(_inflowItemsKey)!,
        _inflowDeletedIdsKey: prefsA1.getString(_inflowDeletedIdsKey)!,
      };

      // 端末B: 削除前にサーバ同期済 (I1,I2) の状態を作る。
      final prefsB = await _switchClient();
      final storeB = AssetExpectedInflowStore(
        nowProvider: () => DateTime(2026, 6, 14, 9),
      );
      await storeB.restoreFromMirrorRows(serverInitial, prefs: prefsB);
      expect(await storeB.loadAll(prefs: prefsB), hasLength(2));

      // 端末B: A のトゥームストーンミラーを decode→適用 → I2 が消える。
      final incoming = AssetExpectedInflowStore.decodeDeletedIdsMirror(
        tombstoneMirror,
      );
      final removedOnB = await storeB.applyRemoteDeletedIds(
        incoming,
        prefs: prefsB,
      );
      expect(removedOnB, 1);

      // 端末B: I4(臨時) を追加して再アップロード。
      await storeB.add(
        date: DateTime(2026, 7, 5),
        amount: 30000,
        label: '臨時収入',
        prefs: prefsB,
      );
      final serverFromB = _uploadInflows(
        await storeB.loadAll(prefs: prefsB),
        const <AssetExpectedInflowRule>[],
      );
      expect(serverFromB.map((row) => row['label']), isNot(contains('フリマ売上')));

      // 端末Aへ戻り、B 由来のサーバ行をマージ → I2 は復活せず I4 が増える。
      final prefsA2 = await _switchClient(aSnapshot);
      final added =
          await storeA.mergeFromMirrorRows(serverFromB, prefs: prefsA2);
      final mergedA = await storeA.loadAll(prefs: prefsA2);

      expect(added, 1); // I4 のみ (I1 は既知 / I2 はトゥームストーン)
      expect(mergedA.map((e) => e.label), containsAll(<String>['給料', '臨時収入']));
      expect(mergedA.map((e) => e.id), isNot(contains(removedId)));
    });

    test(
        'section override full round trip: A deletes → mirror → B reflects → '
        'B re-uploads → A keeps deletion', () async {
      const display = AssetManagementDisplayModeStore();

      // 端末A: chart=hidden + flow=pinned を設定 → chart を自動へ戻す(削除)。
      final prefsA1 = await _switchClient();
      await display.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.hidden,
        prefs: prefsA1,
      );
      await display.saveOverride(
        AssetManagementSectionId.flow,
        AssetManagementSectionVisibilityOverride.pinned,
        prefs: prefsA1,
      );
      await display.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.auto,
        prefs: prefsA1,
      );
      final aDeletedMirror = await display.encodeDeletedSectionIdsMirror(
        prefs: prefsA1,
      );
      expect(
        aDeletedMirror['ids'],
        contains(AssetManagementSectionId.chart.storageId),
      );
      final aSnapshot = <String, Object>{
        _sectionOverridesKey: prefsA1.getString(_sectionOverridesKey)!,
        _sectionOverrideDeletedKey:
            prefsA1.getString(_sectionOverrideDeletedKey)!,
      };

      // 端末B: 削除前の {chart:hidden, flow:pinned} を保持 → A の削除を取込む。
      final prefsB = await _switchClient();
      await display.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.hidden,
        prefs: prefsB,
      );
      await display.saveOverride(
        AssetManagementSectionId.flow,
        AssetManagementSectionVisibilityOverride.pinned,
        prefs: prefsB,
      );
      final removedOnB = await display.applyRemoteDeletedSectionIds(
        AssetManagementDisplayModeStore.decodeDeletedSectionIdsMirror(
          aDeletedMirror,
        ),
        prefs: prefsB,
      );
      expect(removedOnB, 1);
      // 端末B が新たに calendar=hidden を追加して再アップロード。
      await display.saveOverride(
        AssetManagementSectionId.calendar,
        AssetManagementSectionVisibilityOverride.hidden,
        prefs: prefsB,
      );
      final overridesB = await display.loadOverrides(prefs: prefsB);
      expect(overridesB.containsKey(AssetManagementSectionId.chart), isFalse);

      // 端末Aへ戻る。サーバには stale な chart=hidden が残っていても、A の
      // トゥームストーンが復活を防ぎ、B 由来の calendar のみ取り込む。
      final prefsA2 = await _switchClient(aSnapshot);
      final updatedAt = DateTime(2026, 6, 13, 12).toUtc().toIso8601String();
      final serverRows = <Map<String, dynamic>>[
        <String, dynamic>{
          'pref_key': 'section_overrides',
          'value': <String, dynamic>{
            'chart': 'hidden', // stale
            'flow': 'pinned',
            'calendar': 'hidden', // B の新規
          },
          'updated_at': updatedAt,
        },
      ];
      final diff = AssetManagementDisplayModeStore.evaluateMirrorPrefRows(
        rows: serverRows,
        currentMode: await display.load(prefs: prefsA2),
        currentOverrides: await display.loadOverrides(prefs: prefsA2),
        localChangedAt: DateTime(2026, 6, 13, 8),
        deletedSectionIds: await display.loadDeletedSectionIds(prefs: prefsA2),
      );

      expect(
        diff.overrides?.containsKey(AssetManagementSectionId.chart),
        isFalse,
      );
      expect(
        diff.overrides?[AssetManagementSectionId.calendar],
        AssetManagementSectionVisibilityOverride.hidden,
      );
      expect(
        diff.overrides?[AssetManagementSectionId.flow],
        AssetManagementSectionVisibilityOverride.pinned,
      );
    });

    test('debt payment day override deletion propagates A → mirror → B',
        () async {
      // #part294: 支払日上書き削除トゥームストーンのミラー往復(page と同型ロジック)。
      const key = 'debt_payment_day_override_deleted_v1';

      // 端末A: debt_1 の支払日上書きを削除 → トゥームストーン化 → mirror へ encode。
      final prefsA = await _switchClient();
      const storeA = MirrorTombstoneStore(storageKey: key);
      await storeA.addId(prefsA, 'debt_1');
      final mirror = MirrorTombstoneStore.encodeMirror(
        storeA.activeIds(prefsA),
      );
      expect(MirrorTombstoneStore.decodeMirror(mirror), contains('debt_1'));

      // 端末B: debt_1 と debt_2 の上書きを保持。mirror を取り込むと debt_1 が消える。
      final prefsB = await _switchClient();
      const storeB = MirrorTombstoneStore(storageKey: key);
      final overridesB = <String, int>{'debt_1': 27, 'debt_2': 5};
      final incoming = await storeB.mergeRemoteIds(
        prefsB,
        MirrorTombstoneStore.decodeMirror(mirror),
      );
      overridesB.removeWhere((id, _) => incoming.contains(id));

      expect(overridesB.containsKey('debt_1'), isFalse);
      expect(overridesB['debt_2'], 5);
      expect(storeB.activeIds(prefsB), contains('debt_1'));
    });
  });
}
