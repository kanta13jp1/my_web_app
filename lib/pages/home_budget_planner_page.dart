import 'package:flutter/material.dart';

import 'asset_management_page.dart';

/// Legacy route kept for backward compatibility.
/// Monthly budgeting now starts from the unified asset management surface.
class HomeBudgetPlannerPage extends StatelessWidget {
  const HomeBudgetPlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AssetManagementPage(
      initialFocus: AssetManagementInitialFocus.flow,
      emphasizeMonthlyFlow: true,
      entryLabel: '家計・予算プランナー',
      entryDescription:
          '家計簿、月次予算、固定費、借金ロックダウンは資産管理に統合しました。お金の判断を一画面に集約して、時間と集中力の浪費も減らします。',
    );
  }
}
