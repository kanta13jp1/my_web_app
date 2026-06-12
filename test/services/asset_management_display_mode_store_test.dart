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
  });
}
