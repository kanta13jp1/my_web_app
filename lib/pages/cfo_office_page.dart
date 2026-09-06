import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/pages/budget_financial_planner_page.dart';
import 'package:my_web_app/pages/financial_report_page.dart';
import 'package:my_web_app/pages/monthly_kpi_dashboard_page.dart';
import 'package:my_web_app/pages/payment_channel_ledger_page.dart';

import '../models/agent_task.dart';
import '../services/agent_org_service.dart';
import '../services/department_finance_summary_repository.dart';
import '../view_models/cfo_asset_summary_view_model.dart';
import '../widgets/agent_workspace_panel.dart';
import '../widgets/cfo_asset_summary_card.dart';
import '../widgets/cfo_cost_summary_card.dart';
import '../widgets/display_mode_experiment_card.dart';
import 'cfo_cost_ledger_page.dart';

class CfoOfficePage extends StatefulWidget {
  const CfoOfficePage({super.key, this.financeSummaryRepository});

  final DepartmentFinanceSummaryRepository? financeSummaryRepository;

  @override
  State<CfoOfficePage> createState() => _CfoOfficePageState();
}

class _CfoOfficePageState extends State<CfoOfficePage> {
  final AgentOrgService _agentOrgService = AgentOrgService();
  late final CfoAssetSummaryViewModel _assetSummaryViewModel;
  AgentWorkspaceSnapshot? _workspace;
  bool _isLoadingWorkspace = true;
  int _summaryReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _assetSummaryViewModel = CfoAssetSummaryViewModel(
      repository: widget.financeSummaryRepository ??
          SupabaseDepartmentFinanceSummaryRepository(),
    );
    unawaited(_assetSummaryViewModel.load());
    _loadWorkspace();
  }

  @override
  void dispose() {
    _assetSummaryViewModel.dispose();
    super.dispose();
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

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      _loadWorkspace(),
      _assetSummaryViewModel.load(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() => _summaryReloadToken += 1);
  }

  Future<void> _processTask(AgentTask task, String status) async {
    try {
      await _agentOrgService.processTask(task: task, status: status);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CFOタスクを $status に更新しました。')));
      await _loadWorkspace();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CFOタスクの更新に失敗しました: $error')));
    }
  }

  Future<void> _openCostLedger() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/cfo-cost-ledger'),
        builder: (_) => const CfoCostLedgerPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _summaryReloadToken += 1);
  }

  Future<void> _openAssetManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/asset-management'),
        builder: (_) => const AssetManagementPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _assetSummaryViewModel.load();
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
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            AgentWorkspacePanel(
              officeLabel: 'CFO',
              accentColor: Colors.green,
              isLoading: _isLoadingWorkspace,
              workspace: _workspace,
              onProcessTask: _processTask,
            ),
            const SizedBox(height: 16),
            const DisplayModeExperimentCard(),
            const SizedBox(height: 16),
            CfoCostSummaryCard(
              key: ValueKey<int>(_summaryReloadToken),
              onOpenLedger: _openCostLedger,
            ),
            const SizedBox(height: 16),
            CfoAssetSummaryCard(
              viewModel: _assetSummaryViewModel,
              onOpenDetails: _openAssetManagement,
            ),
            const SizedBox(height: 16),
            _buildMenuCard(
              context,
              '月次 KPI レポート',
              'LifeGoals から目標値・実績値・進捗率・前月比を自動集計し、AI 達成アドバイスを確認します。',
              Icons.insights,
              const MonthlyKpiDashboardPage(),
              '/monthly-kpi-dashboard',
            ),
            _buildMenuCard(
              context,
              'コスト・予算管理',
              '月次予算の設定・カテゴリ別支出入力・AI節約アドバイス・将来シミュレーション。',
              Icons.account_balance_wallet,
              const BudgetFinancialPlannerPage(),
              '/budget-financial-planner',
            ),
            _buildMenuCard(
              context,
              'コスト入力台帳',
              '固定費・変動費・月次予算差分を構造化して記録します。',
              Icons.receipt_long,
              const CfoCostLedgerPage(),
              '/cfo-cost-ledger',
            ),
            _buildMenuCard(
              context,
              '資産管理闘争',
              '資産推移、戦況記録、サブスク管理を統合した前線基地。',
              Icons.monetization_on,
              const AssetManagementPage(),
              '/asset-management',
            ),
            _buildMenuCard(
              context,
              '決済チャネル台帳',
              'クレジットカードや銀行口座の連携状況を確認します。',
              Icons.account_balance,
              const PaymentChannelLedgerPage(),
              '/payment-channel-ledger',
            ),
            _buildMenuCard(
              context,
              '決算レポート',
              '日次・週次・月次の収支状況を分析します。',
              Icons.summarize,
              const FinancialReportPage(),
              '/financial-report',
            ),
          ],
        ),
      ),
    );
  }

  /// [routeName] は遷移先画面の URL。`RouteSettings.name` を付けないと
  /// Flutter Web でブラウザの URL が更新されないため必須にしている。
  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget? page,
    String routeName,
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
          style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: page != null
            ? () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: RouteSettings(name: routeName),
                    builder: (_) => page,
                  ),
                );
                if (mounted && page is CfoCostLedgerPage) {
                  setState(() => _summaryReloadToken += 1);
                }
              }
            : () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('準備中です'))),
      ),
    );
  }
}
