import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/agent_task.dart';
import '../services/agent_org_service.dart';
import '../widgets/agent_workspace_panel.dart';
import 'admin_analytics_page.dart';
import 'feedback_page.dart';

class CmoOfficePage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  final AgentOrgService? agentOrgService;

  const CmoOfficePage({
    super.key,
    this.supabaseClient,
    this.agentOrgService,
  });

  @override
  State<CmoOfficePage> createState() => _CmoOfficePageState();
}

class _CmoOfficePageState extends State<CmoOfficePage> {
  late final SupabaseClient _supabase;
  late final AgentOrgService _agentOrgService;

  bool _isLoading = true;
  Map<String, dynamic>? _userStats;
  AgentWorkspaceSnapshot? _workspace;

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _agentOrgService = widget.agentOrgService ?? AgentOrgService();
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

      final results = await Future.wait<dynamic>([
        _supabase
            .from('user_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        _agentOrgService.loadWorkspaceBySlug('cmo'),
      ]);

      if (!mounted) return;
      setState(() {
        _userStats = results[0] as Map<String, dynamic>?;
        _workspace = results[1] as AgentWorkspaceSnapshot?;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Error fetching CMO workspace: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processTask(AgentTask task, String status) async {
    try {
      await _agentOrgService.processTask(task: task, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CMOタスクを $status に更新しました。')),
      );
      await _fetchStats();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CMOタスクの更新に失敗しました: $error')),
      );
    }
  }

  String _buildShareText() {
    return '今日の記録を続けるほど、AIと習慣形成で1日が整う。\n'
        '自分株式会社を使って、行動を前に進めよう。\n'
        'https://my-web-app-b67f4.web.app/';
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
      if (launched) {
        return;
      }
    } catch (error) {
      debugPrint('Direct X share failed: $error');
    }

    await SharePlus.instance.share(ShareParams(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('X を直接開けなかったため、共有シートを表示しました。'),
      ),
    );
  }

  Future<void> _openFeedbackPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FeedbackPage(),
      ),
    );
    if (!mounted) return;
    await _fetchStats();
  }

  @override
  Widget build(BuildContext context) {
    final streak = _userStats?['current_streak'] ?? 0;
    final points = _userStats?['total_points'] ?? 0;
    final level = _userStats?['current_level'] ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CMO OFFICE (マーケティング)'),
        backgroundColor: const Color(0xFFC2185B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AgentWorkspacePanel(
                    officeLabel: 'CMO',
                    accentColor: const Color(0xFFFF6B35),
                    isLoading: false,
                    workspace: _workspace,
                    onProcessTask: _processTask,
                  ),
                  const SizedBox(height: 16),
                  _buildKpiCard(
                    '継続エンゲージメント日数',
                    '$streak日',
                    Icons.local_fire_department,
                    const Color(0xFFFF6B35),
                  ),
                  _buildKpiCard(
                    '累計 LTV 指標 (獲得ポイント)',
                    '$points pt',
                    Icons.monetization_on,
                    const Color(0xFFFF8F00),
                  ),
                  _buildKpiCard(
                    'ブランドランク (レベル)',
                    'Lv.$level',
                    Icons.stars,
                    const Color(0xFF3D5AFE),
                  ),
                  const SizedBox(height: 24),
                  _buildActionCard(
                    context,
                    '導線分析ダッシュボード',
                    'LP View・訪問数・CVR などの指標を確認できます。',
                    Icons.bar_chart,
                    const Color(0xFF3D5AFE),
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminAnalyticsPage(),
                      ),
                    ),
                  ),
                  _buildActionCard(
                    context,
                    '発信テンプレを共有する (SNSシェア)',
                    'X の投稿画面を開いて、訴求文をそのまま共有できます。',
                    Icons.share,
                    const Color(0xFFFF6B35),
                    _shareToX,
                  ),
                  _buildActionCard(
                    context,
                    'マーケフィードバック',
                    '要望や改善案を集めて、次の改善サイクルへつなげます。',
                    Icons.feedback,
                    const Color(0xFF4CAF50),
                    _openFeedbackPage,
                    tileKey: const Key('cmo_office_feedback_action'),
                  ),
                ],
              ),
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    height: 1.5,
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
    VoidCallback onTap, {
    Key? tileKey,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        key: tileKey,
        leading: Icon(icon, color: color, size: 32),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
