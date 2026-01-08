import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

class CmoOfficePage extends StatefulWidget {
  const CmoOfficePage({super.key});

  @override
  State<CmoOfficePage> createState() => _CmoOfficePageState();
}

class _CmoOfficePageState extends State<CmoOfficePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _userStats;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('user_stats')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userStats = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _shareApp() {
    Share.share('「自分株式会社」で人生経営中！ #MeInc');
  }

  @override
  Widget build(BuildContext context) {
    final streak = _userStats?['current_streak'] ?? 0;
    final points = _userStats?['total_points'] ?? 0;
    final level = _userStats?['current_level'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CMO OFFICE (市場広報)'),
        backgroundColor: Colors.pink[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildKpiCard(
                  '顧客エンゲージメント (継続日数)',
                  '{streak}日',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                _buildKpiCard(
                  '顧客LTV (総獲得ポイント)',
                  '{points} pt',
                  Icons.monetization_on,
                  Colors.yellow[800]!,
                ),
                _buildKpiCard(
                  'ブランドランク (レベル)',
                  'Lv.{level}',
                  Icons.stars,
                  Colors.blue,
                ),
                const SizedBox(height: 24),
                _buildActionCard(
                  context,
                  '株主総会へ報告 (SNSシェア)',
                  '現在の経営状況を外部ステークホルダーに共有します。',
                  Icons.share,
                  Colors.pink,
                  _shareApp,
                ),
                _buildActionCard(
                  context,
                  '市場調査 (フィードバック)',
                  'アプリ開発者へ機能要望やバグ報告を送ります。',
                  Icons.feedback,
                  Colors.green,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('フィードバック機能は準備中です')),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
