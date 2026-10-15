import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';

Map<String, dynamic> flow(String description, double amount,
        {String action = 'expense',}) =>
    {'description': description, 'amount': amount, 'action_type': action,
      'occurred_at': '2026-06-20T12:00:00',};

AssetCalendarDaySummary summary(List<Map<String, dynamic>> flows) =>
    AssetPaymentCalendarService.buildRange(
      start: DateTime(2026, 6), endExclusive: DateTime(2026, 7),
      asOf: DateTime(2026, 6, 20), flows: flows, debts: const [],
      subscriptions: const [],
    ).dayFor(DateTime(2026, 6, 20))!;

void main() {
  test('explicit unknown expense is a reference subset, never added twice', () {
    final day = summary([
      flow('[現金] 使途不明金（残高差分から自動記録）', 700),
      flow('使途不明金: 本人の未照合記録', 200),
      flow('通常の購入', 100),
    ]);
    expect(day.expenseTotal, 1000);
    expect(day.unreconciledExpenseTotal, 900);
    expect(day.hasUnreconciledExpense, isTrue);
    expect(day.events.where((e) => e.balanceDifferenceAutoRecorded).length, 1);
  });
  test('transfer and income are never unknown expenses', () {
    final day = summary([
      flow('使途不明金（残高差分から自動記録）', 700, action:'transfer'),
      flow('使途不明金: 返金', 200, action:'income'),
    ]);
    expect(day.expenseTotal, 0);
    expect(day.unreconciledExpenseTotal, 0);
    expect(day.hasUnreconciledExpense, isFalse);
    expect(day.incomeTotal, 200);
    expect(day.hasTransfer, isTrue);
  });
  test('mention in a normal purchase is not a classification or auto source', () {
    final day = summary([
      flow('通常の購入（使途不明金の照合用）', 100),
      flow('使途不明金から照合済みの通常購入', 200),
      flow('使途不明金: 手入力のメモ', 300),
    ]);
    expect(day.expenseTotal, 600);
    expect(day.unreconciledExpenseTotal, 300);
    expect(day.events.any((e) => e.balanceDifferenceAutoRecorded), isFalse);
  });
}
