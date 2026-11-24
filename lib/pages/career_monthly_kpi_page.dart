import 'package:flutter/material.dart';

import '../services/career_monthly_kpi_service.dart';
import '../services/self_mental_health_risk_service.dart';
import '../services/self_skill_asset_service.dart';
import '../widgets/career_monthly_kpi_panel.dart';
import '../widgets/self_mental_health_risk_panel.dart';
import '../widgets/self_skill_asset_portfolio_panel.dart';

class CareerMonthlyKpiPage extends StatelessWidget {
  final List<Map<String, dynamic>> lifeGoals;
  final CareerMonthlyKpiService? kpiService;
  final SelfSkillAssetService? skillAssetService;
  final SelfMentalHealthRiskService? mentalHealthService;
  final DateTime? debugNow;

  const CareerMonthlyKpiPage({
    super.key,
    this.lifeGoals = const <Map<String, dynamic>>[],
    this.kpiService,
    this.skillAssetService,
    this.mentalHealthService,
    this.debugNow,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Career KPI Ledger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          CareerMonthlyKpiPanel(
            lifeGoals: lifeGoals,
            service: kpiService,
            debugNow: debugNow,
          ),
          const SizedBox(height: 16),
          SelfSkillAssetPortfolioPanel(service: skillAssetService),
          const SizedBox(height: 16),
          SelfMentalHealthRiskPanel(
            service: mentalHealthService,
            debugNow: debugNow,
          ),
        ],
      ),
    );
  }
}
