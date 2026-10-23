import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/asset_payment_calendar_service.dart';
import '../../lib/services/behavior_review_service.dart';

void main() {
  final receipt = <String, dynamic>{
    'id': 1,
    'action_type': 'borrowing',
    'amount': 10000,
    'description': '合成の借入受取',
    'occurred_at': '2026-10-14T12:00:00',
  };

  test('calendar shows financing without changing earned totals or cash', () {
    final calendar = AssetPaymentCalendarService.buildRange(
      start: DateTime(2026, 10, 14),
      endExclusive: DateTime(2026, 10, 15),
      flows: [receipt],
      subscriptions: [],
      debts: [],
      startingCashBalance: 40000,
    );
    final day = calendar.dayFor(DateTime(2026, 10, 14))!;
    expect(day.incomeTotal, 0);
    expect(day.expenseTotal, 0);
    expect(day.projectedBalance, 40000);
    expect(day.hasBorrowing, isTrue);
    expect(day.events, hasLength(1));
    expect(day.events.single.kind, AssetCalendarEventKind.borrowing);
    expect(day.events.single.amount, 10000);
    expect(day.events.single.label, contains('収入集計外'));
  });

  test('behavior history does not call a borrowing receipt spending', () {
    final entry = BehaviorReviewService.mapWealthStruggle(receipt)!;
    expect(entry.title, startsWith('借入受取'));
    expect(entry.title, isNot(contains('支出')));
    expect(entry.detail, '合成の借入受取');
  });
}
