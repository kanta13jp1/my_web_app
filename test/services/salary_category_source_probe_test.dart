import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/salary_spending_breakdown_service.dart';

void main() {
  test('source account does not turn utilities into debt repayment', () {
    const service = SalarySpendingBreakdownService();
    expect(service.categorize('水道料'), '光熱費');
    expect(service.categorize('三井住友銀行 ・ 水道料'), '光熱費');
  });
  test('explicit debt and bank fees keep their existing categories', () {
    const service = SalarySpendingBreakdownService();
    expect(service.categorize('ローン返済'), '借入返済');
    expect(service.categorize('三井住友銀行 ・ ATM手数料'), '手数料・税金');
  });
}
