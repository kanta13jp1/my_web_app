import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'rewards_page.dart'; // 福利厚生
import 'stats_page.dart'; // 人事評価

class ChroOfficePage extends StatelessWidget {
  const ChroOfficePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHRO OFFICE (人事厚生)'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            '福利厚生課 (Rewards)',
            '獲得したポイントを報酬アイテムと交換します。',
            Icons.card_giftcard,
            const RewardsPage(),
          ),
          _buildMenuCard(
            context,
            '人事評価室 (Stats)',
            '社員ランク(レベル)や実績の進捗を確認します。',
            Icons.bar_chart,
            const StatsPage(),
          ),
          _buildMenuCard(
            context,
            '社員研修センター (Help)',
            '業務マニュアル(使い方)を確認します。(準備中)',
            Icons.menu_book,
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle,
      IconData icon, Widget? page) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo[100],
          child: Icon(icon, color: Colors.indigo[800]),
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
