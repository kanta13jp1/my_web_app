import 'package:flutter/material.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/pages/budget_financial_planner_page.dart';
import 'package:my_web_app/pages/financial_report_page.dart';
import 'package:my_web_app/pages/monthly_kpi_dashboard_page.dart';
import 'package:my_web_app/pages/payment_channel_ledger_page.dart';

import '../models/agent_task.dart';
import '../services/agent_org_service.dart';
import '../widgets/agent_workspace_panel.dart';

class CfoOfficePage extends StatefulWidget {
  const CfoOfficePage({super.key});

  @override
  State<CfoOfficePage> createState() => _CfoOfficePageState();
}

class _CfoOfficePageState extends State<CfoOfficePage> {
  final AgentOrgService _agentOrgService = AgentOrgService();
  AgentWorkspaceSnapshot? _workspace;
  bool _isLoadingWorkspace = true;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  Future<void> _loadWorkspace() async {
    try {
      final workspace = await _agentOrgService.loadWorkspaceBySlug('cfo');
      if (!mounted) {
        return;
      }
      setState(() {
        _workspace = workspace;
        _isLoadingWorkspace = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingWorkspace = false);
    }
  }

  Future<void> _processTask(AgentTask task, String status) async {
    try {
      await _agentOrgService.processTask(task: task, status: status);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CFOタスクを $status に更新しました。')),
      );
      await _loadWorkspace();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CFOタスクの更新に失敗しました: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CFO OFFICE (財務)'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadWorkspace,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AgentWorkspacePanel(
              officeLabel: 'CFO',
              accentColor: Colors.green,
              isLoading: _isLoadingWorkspace,
              workspace: _workspace,
              onProcessTask: _processTask,
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              '月次 KPI レポート',
              'LifeGoals から目標値・実績値・進捗率・前月比を自動集計し、AI 達成アドバイスを確認します。',
              Icons.insights,
              const MonthlyKpiDashboardPage(),
            ),
            _buildMenuCard(
              context,
              'コスト・予算管理',
              '月次予算の設定・カテゴリ別支出入力・AI節約アドバイス・将来シミュレーション。',
              Icons.account_balance_wallet,
              const BudgetFinancialPlannerPage(),
            ),
            _buildMenuCard(
              context,
              '資産管理闘争',
              '資産推移、戦況記録、サブスク管理を統合した前線基地。',
              Icons.monetization_on,
              const AssetManagementPage(),
            ),
            _buildMenuCard(
              context,
              '決済チャネル台帳',
              'クレジットカードや銀行口座の連携状況を確認します。',
              Icons.account_balance,
              const PaymentChannelLedgerPage(),
            ),
            _buildMenuCard(
              context,
              '決算レポート',
              '日次・週次・月次の収支状況を分析します。',
              Icons.summarize,
              const FinancialReportPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget? page,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(icon, color: Colors.green[800]),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: page != null
            ? () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => page))
            : () => ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('準備中です'))),
      ),
    );
  }
}
