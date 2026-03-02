import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_analytics_page.dart';

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
      if (userId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final data = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _userStats = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _buildShareText() {
    return '今日のやるべきことをAIと運営導線で1件に絞る。'
        '\n「自分株式会社」を使って人生を経営中。'
        '\n今すぐ試す → https://my-web-app-b67f4.web.app/';
  }

  Future<void> _shareToX() async {
    final text = _buildShareText();
    final intentUri = Uri.https(
      'twitter.com',
      '/intent/tweet',
      <String, String>{'text': text},
    );

    try {
      final launched = await launchUrl(
        intentUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (e) {
      debugPrint('Direct X share failed: $e');
    }

    await SharePlus.instance.share(ShareParams(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Xを直接開けなかったため、共有シートを開きました。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final streak = _userStats?['current_streak'] ?? 0;
    final points = _userStats?['total_points'] ?? 0;
    final level = _userStats?['current_level'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CMO OFFICE (広報室)'),
        backgroundColor: Colors.pink[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildKpiCard(
                  '連続エンゲージメント日数',
                  '$streak日',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                _buildKpiCard(
                  '累計LTV (行動価値ポイント)',
                  '$points pt',
                  Icons.monetization_on,
                  Colors.amber.shade800,
                ),
                _buildKpiCard(
                  'ブランドランク (レベル)',
                  'Lv.$level',
                  Icons.stars,
                  Colors.blue,
                ),
                const SizedBox(height: 24),
                _buildActionCard(
                  context,
                  '経営分析ダッシュボード',
                  'LP View・登録数・CVR などの集計を確認します。',
                  Icons.bar_chart,
                  Colors.purple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminAnalyticsPage(),
                    ),
                  ),
                ),
                _buildActionCard(
                  context,
                  '株主総会へ報告 (SNSシェア)',
                  'X の投稿画面を直接開いて、近況をそのまま共有します。',
                  Icons.share,
                  Colors.pink,
                  () {
                    _shareToX();
                  },
                ),
                _buildActionCard(
                  context,
                  '広報フィードバック',
                  '反応や導線の弱点を確認し、次の改善に使います。',
                  Icons.feedback,
                  Colors.green,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('フィードバック収集は準備中です。'),
                    ),
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
        padding: const EdgeInsets.all(16),
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
