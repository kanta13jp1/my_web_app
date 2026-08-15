import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetManagementDisplayModeStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('minimum mode shows only essential sections', () {
      expect(
        AssetManagementDisplayModeStore.isTierVisible(
          tier: AssetManagementSectionTier.essential,
          mode: AssetManagementDisplayMode.minimum,
        ),
        isTrue,
      );
      expect(
        AssetManagementDisplayModeStore.isTierVisible(
          tier: AssetManagementSectionTier.standard,
          mode: AssetManagementDisplayMode.minimum,
        ),
        isFalse,
      );
      expect(
        AssetManagementDisplayModeStore.isTierVisible(
          tier: AssetManagementSectionTier.full,
          mode: AssetManagementDisplayMode.minimum,
        ),
        isFalse,
      );
    });

    test('standard mode hides only full-tier sections', () {
      expect(
        AssetManagementDisplayModeStore.isTierVisible(
          tier: AssetManagementSectionTier.essential,
          mode: AssetManagementDisplayMode.standard,
        ),
        isTrue,
      );
      expect(
        AssetManagementDisplayModeStore.isTierVisible(
          tier: AssetManagementSectionTier.standard,
          mode: AssetManagementDisplayMode.standard,
        ),
        isTrue,
      );
      expect(
        AssetManagementDisplayModeStore.isTierVisible(
          tier: AssetManagementSectionTier.full,
          mode: AssetManagementDisplayMode.standard,
        ),
        isFalse,
      );
    });

    test('full mode shows every tier', () {
      for (final tier in AssetManagementSectionTier.values) {
        expect(
          AssetManagementDisplayModeStore.isTierVisible(
            tier: tier,
            mode: AssetManagementDisplayMode.full,
          ),
          isTrue,
        );
      }
    });

    test('load falls back to full when nothing is stored', () async {
      const store = AssetManagementDisplayModeStore();

      final mode = await store.load();

      expect(mode, AssetManagementDisplayMode.full);
    });

    test('save and load round-trips every mode', () async {
      const store = AssetManagementDisplayModeStore();

      for (final mode in AssetManagementDisplayMode.values) {
        await store.save(mode);
        expect(await store.load(), mode);
      }
    });

    test('load tolerates an unknown stored value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1': 'galaxy',
      });
      const store = AssetManagementDisplayModeStore();

      final mode = await store.load();

      expect(mode, AssetManagementDisplayMode.full);
    });

    test('section overrides beat tier rules in both directions', () {
      expect(
        AssetManagementDisplayModeStore.isSectionVisible(
          section: AssetManagementSectionId.chart,
          mode: AssetManagementDisplayMode.minimum,
          override: AssetManagementSectionVisibilityOverride.pinned,
        ),
        isTrue,
      );
      expect(
        AssetManagementDisplayModeStore.isSectionVisible(
          section: AssetManagementSectionId.debtPlanner,
          mode: AssetManagementDisplayMode.full,
          override: AssetManagementSectionVisibilityOverride.hidden,
        ),
        isFalse,
      );
      expect(
        AssetManagementDisplayModeStore.isSectionVisible(
          section: AssetManagementSectionId.workbookBoard,
          mode: AssetManagementDisplayMode.minimum,
        ),
        isFalse,
      );
      expect(
        AssetManagementDisplayModeStore.isSectionVisible(
          section: AssetManagementSectionId.calendar,
          mode: AssetManagementDisplayMode.minimum,
        ),
        isTrue,
      );
    });

    test('persists overrides and clears them when reset to auto', () async {
      const store = AssetManagementDisplayModeStore();

      var overrides = await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.pinned,
      );
      overrides = await store.saveOverride(
        AssetManagementSectionId.flow,
        AssetManagementSectionVisibilityOverride.hidden,
      );
      expect(overrides, hasLength(2));

      final loaded = await store.loadOverrides();
      expect(
        loaded[AssetManagementSectionId.chart],
        AssetManagementSectionVisibilityOverride.pinned,
      );
      expect(
        loaded[AssetManagementSectionId.flow],
        AssetManagementSectionVisibilityOverride.hidden,
      );

      final cleared = await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.auto,
      );
      expect(cleared.containsKey(AssetManagementSectionId.chart), isFalse);
      expect(cleared, hasLength(1));
    });

    test(
      'resolveInitialMode picks standard only for brand-new users',
      () async {
        const store = AssetManagementDisplayModeStore();

        final newUserMode = await store.resolveInitialMode(
          hasExistingData: false,
        );
        expect(newUserMode, AssetManagementDisplayMode.standard);
        expect(await store.load(), AssetManagementDisplayMode.standard);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final existingUserMode = await store.resolveInitialMode(
          hasExistingData: true,
        );
        expect(existingUserMode, AssetManagementDisplayMode.full);

        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'minimum',
        });
        final storedWins = await store.resolveInitialMode(
          hasExistingData: false,
        );
        expect(storedWins, AssetManagementDisplayMode.minimum);
      },
    );

    test('records initial resolution and mode switches as local stats',
        () async {
      final store = AssetManagementDisplayModeStore(
        nowProvider: () => DateTime(2026, 6, 12, 10, 0),
      );

      await store.resolveInitialMode(hasExistingData: false);
      await store.save(AssetManagementDisplayMode.full);
      await store.save(AssetManagementDisplayMode.minimum);

      final stats = await store.loadStats();

      expect(stats.initialMode, 'standard');
      expect(stats.initialHadData, isFalse);
      expect(stats.switchCount, 2);
      expect(stats.lastChangedAt, isNotNull);
    });

    test('hasStoredMode distinguishes saved from default', () async {
      const store = AssetManagementDisplayModeStore();

      expect(await store.hasStoredMode(), isFalse);
      await store.save(AssetManagementDisplayMode.full);
      expect(await store.hasStoredMode(), isTrue);
    });

    test('save with recordEvent false keeps experiment stats untouched',
        () async {
      final store = AssetManagementDisplayModeStore(
        nowProvider: () => DateTime(2026, 6, 12, 10, 0),
      );

      await store.save(AssetManagementDisplayMode.minimum, recordEvent: false);

      final stats = await store.loadStats();
      expect(stats.switchCount, 0);
      expect(await store.load(), AssetManagementDisplayMode.minimum);
    });

    test('parseServerSummary builds label and weekly list', () {
      final parsed = AssetManagementDisplayModeStore.parseServerSummary(
        <String, dynamic>{
          'initial_minimum': 1,
          'initial_standard': 4,
          'initial_full': 2,
          'switch_total': 3,
          'standard_retained': 3,
          'weekly': <Map<String, dynamic>>[
            <String, dynamic>{
              'week_start': '2026-06-08',
              'initials': 5,
              'initial_standard': 4,
              'switches': 2,
            },
          ],
        },
      );

      expect(parsed.summaryLabel, contains('標準維持率 75%'));
      expect(parsed.summaryLabel, contains('06-08'));
      expect(parsed.weekly, hasLength(1));
      expect(parsed.firstEventAt, isNull);
    });

    test('parseServerSummary reads first_event_at when provided', () {
      final parsed = AssetManagementDisplayModeStore.parseServerSummary(
        <String, dynamic>{
          'initial_standard': 0,
          'first_event_at': '2026-06-01T00:00:00Z',
          'weekly': <Map<String, dynamic>>[],
        },
      );

      expect(parsed.firstEventAt, isNotNull);
      expect(parsed.firstEventAt!.toUtc(), DateTime.utc(2026, 6, 1));
    });

    test('restore decline flag persists', () async {
      const store = AssetManagementDisplayModeStore();

      expect(await store.isRestoreDeclined(), isFalse);
      await store.markRestoreDeclined();
      expect(await store.isRestoreDeclined(), isTrue);
    });

    test('parseServerSummary reads weekly retention series', () {
      final parsed = AssetManagementDisplayModeStore.parseServerSummary(
        <String, dynamic>{
          'initial_standard': 0,
          'weekly_retention': <Map<String, dynamic>>[
            <String, dynamic>{'week_start': '2026-06-08', 'rate': 75},
            <String, dynamic>{'week_start': '2026-06-01', 'rate': null},
          ],
        },
      );

      expect(parsed.weeklyRetention, hasLength(2));
      expect(parsed.weeklyRetention.first['rate'], 75);
      expect(parsed.weeklyRetention.last['rate'], isNull);
    });

    test('evaluateMirrorPrefRows reports only newer differing prefs', () {
      final local = DateTime(2026, 6, 13, 10, 0);
      final rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'pref_key': 'display_mode',
          'value': <String, dynamic>{'mode': 'standard'},
          'updated_at': DateTime(2026, 6, 13, 11, 0).toUtc().toIso8601String(),
        },
        <String, dynamic>{
          'pref_key': 'section_overrides',
          'value': <String, dynamic>{'chart': 'pinned'},
          'updated_at': DateTime(2026, 6, 13, 11, 0).toUtc().toIso8601String(),
        },
      ];

      final diff = AssetManagementDisplayModeStore.evaluateMirrorPrefRows(
        rows: rows,
        currentMode: AssetManagementDisplayMode.minimum,
        currentOverrides: const <AssetManagementSectionId,
            AssetManagementSectionVisibilityOverride>{},
        localChangedAt: local,
      );

      expect(diff.mode, AssetManagementDisplayMode.standard);
      expect(
        diff.overrides?[AssetManagementSectionId.chart],
        AssetManagementSectionVisibilityOverride.pinned,
      );
    });

    test('evaluateMirrorPrefRows skips self-writes and same content', () {
      final local = DateTime(2026, 6, 13, 10, 0);
      final selfWrite = <String, dynamic>{
        'pref_key': 'display_mode',
        'value': <String, dynamic>{'mode': 'standard'},
        'updated_at': DateTime(2026, 6, 13, 10, 0, 5).toUtc().toIso8601String(),
      };
      final sameContent = <String, dynamic>{
        'pref_key': 'section_overrides',
        'value': <String, dynamic>{'chart': 'pinned'},
        'updated_at': DateTime(2026, 6, 13, 12, 0).toUtc().toIso8601String(),
      };

      final diff = AssetManagementDisplayModeStore.evaluateMirrorPrefRows(
        rows: <Map<String, dynamic>>[selfWrite, sameContent],
        currentMode: AssetManagementDisplayMode.minimum,
        currentOverrides: const <AssetManagementSectionId,
            AssetManagementSectionVisibilityOverride>{
          AssetManagementSectionId.chart:
              AssetManagementSectionVisibilityOverride.pinned,
        },
        localChangedAt: local,
      );

      expect(diff.isEmpty, isTrue);
    });

    test('describeMirrorPrefsDiff renders old → new lines', () {
      const diff = AssetMirrorPrefsDiff(
        mode: AssetManagementDisplayMode.standard,
        overrides: <AssetManagementSectionId,
            AssetManagementSectionVisibilityOverride>{
          AssetManagementSectionId.chart:
              AssetManagementSectionVisibilityOverride.pinned,
        },
      );

      final lines = AssetManagementDisplayModeStore.describeMirrorPrefsDiff(
        currentMode: AssetManagementDisplayMode.minimum,
        currentOverrides: const <AssetManagementSectionId,
            AssetManagementSectionVisibilityOverride>{
          AssetManagementSectionId.calendar:
              AssetManagementSectionVisibilityOverride.pinned,
        },
        diff: diff,
      );

      expect(lines, contains('表示モード: ミニマム → 標準'));
      expect(lines, contains('グラフ: 自動 → 常に表示'));
      expect(lines, contains('マネーカレンダー: 常に表示 → 自動'));
      expect(lines, hasLength(3));
    });

    test('describeMirrorPrefsDiff returns empty when nothing differs', () {
      const overrides =
          <AssetManagementSectionId, AssetManagementSectionVisibilityOverride>{
        AssetManagementSectionId.chart:
            AssetManagementSectionVisibilityOverride.pinned,
      };

      final lines = AssetManagementDisplayModeStore.describeMirrorPrefsDiff(
        currentMode: AssetManagementDisplayMode.standard,
        currentOverrides: overrides,
        diff: const AssetMirrorPrefsDiff(
          mode: AssetManagementDisplayMode.standard,
          overrides: overrides,
        ),
      );

      expect(lines, isEmpty);
    });

    test('resetting an override to auto tombstones the section', () async {
      const store = AssetManagementDisplayModeStore();
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.pinned,
      );
      // 自動へ戻す = 削除 → トゥームストーン化。
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.auto,
      );
      expect(
        await store.loadDeletedSectionIds(),
        contains(AssetManagementSectionId.chart.storageId),
      );

      // 再設定すると意図的なのでトゥームストーン解除。
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.hidden,
      );
      expect(
        await store.loadDeletedSectionIds(),
        isNot(contains(AssetManagementSectionId.chart.storageId)),
      );
    });

    test('evaluateMirrorPrefRows excludes tombstoned sections', () {
      final rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'pref_key': 'section_overrides',
          'value': <String, dynamic>{'chart': 'pinned', 'flow': 'hidden'},
          'updated_at': DateTime(2026, 6, 13, 11).toUtc().toIso8601String(),
        },
      ];

      // chart は削除トゥームストーン済み → 復活させない。flow のみ採用。
      final diff = AssetManagementDisplayModeStore.evaluateMirrorPrefRows(
        rows: rows,
        currentMode: AssetManagementDisplayMode.full,
        currentOverrides: const <AssetManagementSectionId,
            AssetManagementSectionVisibilityOverride>{},
        localChangedAt: DateTime(2026, 6, 13, 9),
        deletedSectionIds: <String>{AssetManagementSectionId.chart.storageId},
      );

      expect(
        diff.overrides?.containsKey(AssetManagementSectionId.chart),
        isFalse,
      );
      expect(
        diff.overrides?[AssetManagementSectionId.flow],
        AssetManagementSectionVisibilityOverride.hidden,
      );
    });

    test('encode/decode deleted section ids mirror round-trips', () async {
      const store = AssetManagementDisplayModeStore();
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.pinned,
      );
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.auto,
      );

      final mirror = await store.encodeDeletedSectionIdsMirror();
      expect(
        mirror['ids'],
        contains(AssetManagementSectionId.chart.storageId),
      );
      expect(
        AssetManagementDisplayModeStore.decodeDeletedSectionIdsMirror(mirror),
        contains(AssetManagementSectionId.chart.storageId),
      );
    });

    test('applyRemoteDeletedSectionIds removes matching local overrides',
        () async {
      const store = AssetManagementDisplayModeStore();
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.hidden,
      );
      await store.saveOverride(
        AssetManagementSectionId.flow,
        AssetManagementSectionVisibilityOverride.pinned,
      );

      // 他端末で chart 上書きが削除された → ローカルからも消える。
      final removed = await store.applyRemoteDeletedSectionIds(
        <String>[AssetManagementSectionId.chart.storageId],
      );
      expect(removed, 1);
      final overrides = await store.loadOverrides();
      expect(overrides.containsKey(AssetManagementSectionId.chart), isFalse);
      expect(
        overrides[AssetManagementSectionId.flow],
        AssetManagementSectionVisibilityOverride.pinned,
      );
      expect(
        await store.loadDeletedSectionIds(),
        contains(AssetManagementSectionId.chart.storageId),
      );

      // 二度目は対象なし。
      expect(
        await store.applyRemoteDeletedSectionIds(
          <String>[AssetManagementSectionId.chart.storageId],
        ),
        0,
      );
    });

    test('pruneDeletedSectionIds clears expired override tombstones', () async {
      var clock = DateTime(2026, 1, 1, 9);
      final store = AssetManagementDisplayModeStore(nowProvider: () => clock);
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.pinned,
      );
      await store.saveOverride(
        AssetManagementSectionId.chart,
        AssetManagementSectionVisibilityOverride.auto,
      );
      expect(await store.pruneDeletedSectionIds(), 0); // 期限内

      clock = DateTime(2027, 6, 1, 9); // 既定 TTL 365 日超過
      expect(await store.pruneDeletedSectionIds(), 1);
      expect(await store.loadDeletedSectionIds(), isEmpty);
    });
  });
}
