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
  });
}
