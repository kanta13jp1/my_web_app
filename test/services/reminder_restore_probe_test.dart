import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_payment_reminder_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';

void main() {
  const planner = AssetLiabilityPlanningService();
  const reminders = AssetLiabilityPaymentReminderService();
  final now = DateTime(2026, 5, 15);

  test('restoring paid state removes a provisional due reminder', () {
    final pending = planner.buildWorkbook(
      latestSnapshot: const {'財布': 10000.0, 'モビット': -100000.0},
      baseDate: now,
      monthlyPaymentOverrides: const {'モビット': 10000.0},
    );
    final restored = planner.buildWorkbook(
      latestSnapshot: const {'財布': 10000.0, 'モビット': -100000.0},
      baseDate: now,
      monthlyPaymentOverrides: const {'モビット': 10000.0},
      paidAccountNames: const {'モビット'},
    );
    final provisional = reminders.buildCandidates(workbook: pending, now: now);
    expect(provisional, hasLength(1));
    expect(provisional.single.status, AssetLiabilityPaymentReminderStatus.dueToday);
    expect(reminders.buildCandidates(workbook: restored, now: now), isEmpty);
    // The service cannot infer whether an empty paid set is still restoring.
    // This reproduces data sensitivity, not a rendered widget or load failure.
    expect(reminders.buildCandidates(workbook: pending, now: now), hasLength(1));
  });
}
