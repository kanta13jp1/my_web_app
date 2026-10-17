import 'package:my_web_app/services/waste_tracking_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_flow_description_service.dart';
import 'package:my_web_app/services/asset_waste_training_snapshot_inputs.dart';
void main() {
  test('component reconciliation preserves legacy and invalid cases', () {
    expect(WasteTrackingService.reconciledWasteAmount('食品116円、たばこ620円', 736), 620);
    expect(WasteTrackingService.reconciledWasteAmount('ドーナツ税込116円、マールボロBOX620円（たばこ代）', 736), 620);
    expect(WasteTrackingService.reconciledWasteAmount('食品116円、たばこ620円', 800), 800);
    expect(WasteTrackingService.reconciledWasteAmount('たばこ620円', 620), 620);
    expect(WasteTrackingService.reconciledWasteAmount('食品116円、たばこ620円 [浪費:飲酒]', 736), 736);
    expect(WasteTrackingService.reconciledWasteAmount('食品116円、たばこ620円、たばこ100円', 836), 836);
    expect(WasteTrackingService.reconciledWasteAmount('食品116円、たばこ不明', 736), 736);
  });

  test('mixed receipt keeps food out of smoking amount', () {
    final snapshot = AssetWasteTrainingSnapshotInputs.build(
      monthFlows: <Map<String, dynamic>>[<String, dynamic>{
        'action_type': 'expense', 'amount': 736,
        'description': '[cash] ドーナツ税込116円、マールボロBOX620円（たばこ代）',
        'occurred_at': '2026-10-09T10:47:00',
      }],
      now: DateTime(2026, 10, 17),
      isExpense: (type) => type == 'expense',
      wasteCategoryOf: (description, type) => AssetFlowDescriptionService.parse(description, actionType: type).wasteCategory,
      ruleCompletedCount: 0, ruleTargetCount: 5,
      todayViolationCount: 0, compliantStreakDays: 0, lockdownActive: false,
    );
    expect(snapshot.totalExpense, 736);
    expect(snapshot.wasteExpense, 620, reason: 'A mixed receipt must not count its food amount as smoking. Exact components need explicit reconciliation.',);
  });
}
