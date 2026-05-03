import 'package:flutter/material.dart';

import '../widgets/career_monthly_kpi_panel.dart';

class CareerMonthlyKpiPage extends StatelessWidget {
  final List<Map<String, dynamic>> lifeGoals;

  const CareerMonthlyKpiPage({
    super.key,
    this.lifeGoals = const <Map<String, dynamic>>[],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Career KPI Ledger')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [CareerMonthlyKpiPanel(lifeGoals: lifeGoals)],
      ),
    );
  }
}
