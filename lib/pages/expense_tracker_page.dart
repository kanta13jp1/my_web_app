import 'package:flutter/material.dart';

import 'asset_management_page.dart';

/// Legacy route kept for backward compatibility.
/// Expense tracking now lives inside the unified asset management surface.
class ExpenseTrackerPage extends StatelessWidget {
  const ExpenseTrackerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AssetManagementPage(
      initialFocus: AssetManagementInitialFocus.flow,
      emphasizeMonthlyFlow: true,
      entryLabel: '支出トラッカー',
      entryDescription:
          '支出記録、浪費カテゴリ、月次収支の確認は資産管理に統合しました。AIが現状を分析し、KGI / CSF / KPI で浪費削減を継続監視します。',
    );
  }
}
