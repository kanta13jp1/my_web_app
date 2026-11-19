import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:my_web_app/services/savings_life_plan_store.dart';
import 'package:my_web_app/models/savings_life_plan.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final mode in AssetManagementDisplayMode.values) {
    for (final override in AssetManagementSectionVisibilityOverride.values) {
      test('savings plan visibility $mode / $override', () {
        final expected = switch (override) {
          AssetManagementSectionVisibilityOverride.hidden => false,
          AssetManagementSectionVisibilityOverride.pinned => true,
          AssetManagementSectionVisibilityOverride.auto =>
            mode != AssetManagementDisplayMode.minimum,
        };
        expect(
          AssetManagementDisplayModeStore.isSectionVisible(
            section: AssetManagementSectionId.savingsPlan,
            mode: mode,
            override: override,
          ),
          expected,
        );
      });
    }
  }
  test('new section is appended and old preference keys survive hide/reset',
      () async {
    const planKey = 'savings_life_plan_v1:synthetic-owner';
    SharedPreferences.setMockInitialValues({
      'asset_management_section_overrides_v1':
          jsonEncode({'flow': 'hidden', 'chart': 'pinned'}),
    });
    final planStore = SavingsLifePlanStore('synthetic-owner');
    await planStore.save(
      SavingsLifePlan(
        start: DateTime(2026, 10, 15),
        targetDate: DateTime(2027, 10, 15),
        cashBalance: 12345,
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    final savedPlan = prefs.getString(planKey);
    const store = AssetManagementDisplayModeStore();
    expect(
      AssetManagementSectionId.values.last,
      AssetManagementSectionId.savingsPlan,
    );
    expect(AssetManagementSectionId.savingsPlan.storageId, 'savingsPlan');
    final hidden = await store.saveOverride(
      AssetManagementSectionId.savingsPlan,
      AssetManagementSectionVisibilityOverride.hidden,
    );
    expect(
      hidden[AssetManagementSectionId.flow],
      AssetManagementSectionVisibilityOverride.hidden,
    );
    expect(
      hidden[AssetManagementSectionId.chart],
      AssetManagementSectionVisibilityOverride.pinned,
    );
    expect(
      (await store.loadOverrides())[AssetManagementSectionId.savingsPlan],
      AssetManagementSectionVisibilityOverride.hidden,
    );
    await store.saveOverride(
      AssetManagementSectionId.savingsPlan,
      AssetManagementSectionVisibilityOverride.auto,
    );
    expect(
      (await store.loadOverrides()).containsKey(
        AssetManagementSectionId.savingsPlan,
      ),
      isFalse,
    );
    expect(prefs.getString(planKey), savedPlan);
    expect((await planStore.load())!.cashBalance, 12345);
  });
}
