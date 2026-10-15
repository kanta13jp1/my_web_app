import 'package:flutter/material.dart';
import '../services/asset_payroll_deductions.dart';

/// Uses already authorized payslip rows; never uploads or modifies a payslip.
class AssetPayrollDeductionsCard extends StatelessWidget {
  const AssetPayrollDeductionsCard({
    super.key,
    required this.ownerId,
    required this.year,
    required this.rows,
  });

  final String ownerId;
  final int year;
  final List<Map<String, dynamic>> rows;

  static String amount(int? value) => value == null ? '未取得' : '$value円';

  static const labels = {
    'income_tax': '所得税',
    'resident_tax': '住民税',
    'health_insurance': '健康保険',
    'pension': '厚生年金',
    'employment_insurance': '雇用保険',
    'long_term_care_insurance': '介護保険',
    'employees_pension_fund_contribution': '厚生年金基金掛金',
    'ideco': 'iDeCo（その他控除）',
  };

  @override
  Widget build(BuildContext context) {
    final months = AssetPayrollDeductions.months(
      ownerId: ownerId,
      year: year,
      rows: rows,
    );
    final taxMonths = months.where((m) => m.confirmedTaxYen != null).toList();
    final socialMonths =
        months.where((m) => m.confirmedSocialYen != null).toList();
    final taxSum = taxMonths.fold<int>(
      0,
      (sum, m) => sum + m.confirmedTaxYen!,
    );
    final socialSum = socialMonths.fold<int>(
      0,
      (sum, m) => sum + m.confirmedSocialYen!,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$year年 給与の税金・社会保険料',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('給与明細の支給日が属する月で表示します。控除を家計簿の支出へ重ねて追加しません。'),
            Text(
              '税金の確認済み分：${taxMonths.isEmpty ? '確定累計対象なし' : '$taxSum円'}（${taxMonths.length}/12か月）',
            ),
            Text(
              '社会保険料の確認済み分：${socialMonths.isEmpty ? '確定累計対象なし' : '$socialSum円'}（${socialMonths.length}/12か月）',
            ),
            Text('明細取得済み ${months.where((m) => m.statements.isNotEmpty).length}/12か月・本人未確認 ${months.where((m) => m.statements.isNotEmpty && !m.confirmed && !m.conflicting).length}か月'),
            const Text('取得済みでも本人未確認・項目不足・競合・内訳不一致の額は確定累計に含めません。'),
            for (final month in months.where((m) => m.statements.isNotEmpty &&
                (m.confirmedTaxYen == null || m.confirmedSocialYen == null)))
              Text('${month.month.month}月の累計対象外理由：税 ${month.summaryStatus(social: false)} / 社会保険 ${month.summaryStatus(social: true)}'),
            const Text('空欄は0円ではありません。自動読取は本人確認済みの合計に含めません。'),
            for (final month in months)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('${month.month.month}月'),
                subtitle: Text(
                  month.conflicting
                      ? '同じ明細の内容が競合・要確認'
                      : month.statements.isEmpty
                          ? '明細なし'
                          : '税 ${month.confirmedTaxYen == null ? month.summaryStatus(social: false) : amount(month.confirmedTaxYen)} / 社会保険 ${month.confirmedSocialYen == null ? month.summaryStatus(social: true) : amount(month.confirmedSocialYen)}',
                ),
                children: [
                  for (var index = 0; index < month.statements.length; index++)
                    _statement(context, month.statements[index], index),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statement(BuildContext context, PayrollDeductions row, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '明細${index + 1}・${row.payDate.month}/${row.payDate.day}支給・${row.confirmed ? '本人確認済み' : '読取内容は未確認'}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text('総支給 ${amount(row.grossYen)} / 手取り ${amount(row.netYen)}'),
          for (final entry in labels.entries)
            Text('${entry.value}：${amount(row.items[entry.key])}'),
          Text('税金合計：${amount(row.taxTotalYen)}'),
          Text('社会保険合計：${amount(row.socialTotalYen)}'),
          if (row.socialMismatchYen != null && row.socialMismatchYen != 0)
            Text('社会保険の記載合計と内訳に差：${amount(row.socialMismatchYen)}・要確認'),
          if (row.conflictingPensionAliases)
            const Text('厚生年金の項目名違いで金額が競合・要確認（累計から除外）'),
          Text('内訳の分類状態：未分類 ${row.unclassified.length}項目'),
          for (final entry in row.unclassified.entries)
            Text('未分類控除（${entry.key}）：${amount(entry.value)}'),
          Text('総支給−手取り（計算値）：${amount(row.derivedDeductionTotalYen)}'),
          Text('記載済み控除小計との差：${amount(row.unidentifiedDifferenceYen)}'),
          const Text('小計は社会保険の記載合計を優先し、内訳を重ねて足しません。'),
          if (row.unclassified.isNotEmpty)
            const Text('差が0円でも内訳の分類完了を意味しません。未分類項目が記載合計に含まれる場合があります。'),
          const Text('差がある場合は未取得・未分類項目や読取内容を確認してください。還付などの負数は符号を保持します。'),
        ],
      ),
    );
  }
}
