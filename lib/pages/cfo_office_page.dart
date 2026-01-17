import 'package:flutter/material.dart';
import 'package:my_web_app/pages/cash_management_page.dart';
import 'package:my_web_app/pages/monthly_closing_report_page.dart';
import 'package:my_web_app/pages/payment_channel_ledger_page.dart';
import 'package:my_web_app/pages/subscription_page.dart';

class CfoOfficePage extends StatelessWidget {
  const CfoOfficePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CFO OFFICE (財務)'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            '現金管理',
            '毎日の現金残高を記録し、推移を可視化します。',
            Icons.wallet,
            const CashManagementPage(),
          ),
          _buildMenuCard(
            context,
            '固定費削減室 (サブスク管理)',
            '毎月の固定費を見直し、無駄な支出を削減します。',
            Icons.credit_card_off,
            const SubscriptionPage(),
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
            '月次決算レポート',
            '今月の収支状況を分析します。',
            Icons.summarize,
            const MonthlyClosingReportPage(),
          ),
        ],
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
