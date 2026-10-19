import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/receipt_category_allocation.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  const mixed = 'セブン 酒購入602円・たばこ620円。内訳:食品429円・飲酒602円・喫煙620円。飲酒・喫煙実施は未確認。';
  test('three components reconcile without adding another expense', () {
    expect(ReceiptCategoryAllocation.parse(mixed, 1651), {'食品': 429.0, '飲酒': 602.0, '喫煙': 620.0});
    expect(ReceiptCategoryAllocation.parse(mixed, 1650), isNull);
    expect(ReceiptCategoryAllocation.parse('内訳:食品429円・食品602円・喫煙620円。', 1651), isNull);
    expect(ReceiptCategoryAllocation.parse('食品429円・酒602円・たばこ620円', 1651), isNull);
  });
  test('tobacco only convenience purchase is not food', () {
    const service = SalarySpendingBreakdownService();
    expect(service.categorize('セブン マールボロBOX（たばこ購入）。QUICPay620円。喫煙実施・本数は未確認。'), '娯楽・浪費');
    expect(service.categorize('セブン 食品 ドーナツ360円'), '食費');
    expect(service.categorize('Amazon 書籍 たばこの本'), '書籍');
  });
  test('salary allocation preserves total and separates three components', () {
    const service = SalarySpendingBreakdownService();
    final result = service.build(referenceDate: DateTime(2026, 9, 20), expenses: [SalarySpendingEntry(date: DateTime(2026, 9, 12), amount: 1651, description: mixed, sourceLabel: '現金')], incomes: const []);
    expect(result.totalExpense, 1651);
    expect(result.sections.singleWhere((s) => s.category == '食費').amount, 429);
    expect(result.sections.singleWhere((s) => s.category == '娯楽・浪費').amount, 1222);
  });
  test('calendar alcohol is a component, total remains 1651', () {
    final events = AssetCalendarReflection.fromFlows([{'id': '123', 'action_type': 'expense', 'occurred_at': '2026-09-12T23:53:00', 'description': mixed, 'amount': 1651}]);
    expect(events.single.verifiedAmount, 1651);
    expect(events.single.alcoholAmount, 602);
    expect(AssetCalendarReflection.fromFlows([{'id': '124', 'action_type': 'expense', 'occurred_at': '2026-09-12T23:53:00', 'description': '酒購入、酒代未確認', 'amount': 1651}]).single.alcoholAmount, isNull);
  });
}
