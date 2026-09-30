enum BudgetBalanceField {
  income,
  essential,
  annual,
  reserve,
  enjoyment,
  investment
}

class BudgetBalanceResult {
  const BudgetBalanceResult({
    required this.monthlyAnnualProvision,
    required this.allocated,
    required this.remaining,
  });

  final int monthlyAnnualProvision;
  final int allocated;
  final int remaining;
}

/// A cash-allocation check, not an investment-return or affordability forecast.
class BudgetBalanceCalculator {
  const BudgetBalanceCalculator();

  static const maxAmount = 1000000000;

  String? validate(String input) {
    final text = input.trim();
    if (text.isEmpty) return '未確認です。金額を確認し、支出がない場合は0を入力してください';
    if (!RegExp(r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)$').hasMatch(text)) {
      return '0以上の整数で入力してください（例：230000）';
    }
    final amount = int.tryParse(text.replaceAll(',', ''));
    if (amount == null || amount > maxAmount) return '10億円以下で入力してください';
    return null;
  }

  BudgetBalanceResult? calculate(Map<BudgetBalanceField, String> inputs) {
    final amounts = <BudgetBalanceField, int>{};
    for (final field in BudgetBalanceField.values) {
      final input = inputs[field] ?? '';
      if (validate(input) != null) return null;
      amounts[field] = int.parse(input.trim().replaceAll(',', ''));
    }
    final annual = (amounts[BudgetBalanceField.annual]! + 11) ~/ 12;
    final allocated = amounts[BudgetBalanceField.essential]! +
        annual +
        amounts[BudgetBalanceField.reserve]! +
        amounts[BudgetBalanceField.enjoyment]! +
        amounts[BudgetBalanceField.investment]!;
    return BudgetBalanceResult(
      monthlyAnnualProvision: annual,
      allocated: allocated,
      remaining: amounts[BudgetBalanceField.income]! - allocated,
    );
  }
}
