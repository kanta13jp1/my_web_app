import 'package:flutter/material.dart';

import '../services/self_skill_asset_service.dart';
import '../widgets/career_monthly_kpi_panel.dart';
import '../widgets/self_skill_asset_portfolio_panel.dart';

class CareerMonthlyKpiPage extends StatelessWidget {
  final List<Map<String, dynamic>> lifeGoals;
  final SelfSkillAssetService? skillAssetService;

  const CareerMonthlyKpiPage({
    super.key,
    this.lifeGoals = const <Map<String, dynamic>>[],
    this.skillAssetService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Career KPI Ledger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          CareerMonthlyKpiPanel(lifeGoals: lifeGoals),
          const SizedBox(height: 16),
          SelfSkillAssetPortfolioPanel(service: skillAssetService),
        ],
      ),
    );
  }
}
