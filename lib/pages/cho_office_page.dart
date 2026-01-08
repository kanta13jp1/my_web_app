import 'package:flutter/material.dart';
import 'health_page.dart';

class ChoOfficePage extends StatelessWidget {
  const ChoOfficePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHO OFFICE (健康)'),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuCard(
            context,
            '健康管理室 (Health Log)',
            '食事、運動、睡眠などの健康活動を記録します。',
            Icons.favorite,
            const HealthPage(),
          ),
          _buildMenuCard(
            context,
            'メンタルチェック',
            'ストレスレベルを測定し、AIカウンセラーに相談します。(準備中)',
            Icons.psychology,
            null,
          ),
          _buildMenuCard(
            context,
            '定期健康診断',
            '健康診断の結果を記録し、経年変化を分析します。(準備中)',
            Icons.medical_services,
            null,
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
          backgroundColor: Colors.teal[100],
          child: Icon(icon, color: Colors.teal[800]),
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
