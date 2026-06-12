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
  });
}
