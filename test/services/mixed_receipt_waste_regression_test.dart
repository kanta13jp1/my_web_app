import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_flow_description_service.dart';
import 'package:my_web_app/services/asset_waste_training_snapshot_inputs.dart';
void main() {
  test('mixed receipt keeps food out of smoking amount', () {
    final snapshot = AssetWasteTrainingSnapshotInputs.build(
      monthFlows: <Map<String, dynamic>>[<String, dynamic>{
        'action_type': 'expense', 'amount': 736,
        'description': '[cash] food116yen tobacco620yen (たばこ代)',
        'occurred_at': '2026-10-09T10:47:00',
      }],
      now: DateTime(2026, 10, 17),
      isExpense: (type) => type == 'expense',
      wasteCategoryOf: (description, type) => AssetFlowDescriptionService.parse(description, actionType: type).wasteCategory,
      ruleCompletedCount: 0, ruleTargetCount: 5,
      todayViolationCount: 0, compliantStreakDays: 0, lockdownActive: false,
    );
    expect(snapshot.totalExpense, 736);
    expect(snapshot.wasteExpense, lessThan(736), reason: 'A mixed receipt must not count its food amount as smoking. Exact components need explicit reconciliation.');
  });
}
