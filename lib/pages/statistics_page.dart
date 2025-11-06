import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/presence_service.dart';
import '../models/site_statistics.dart';
import '../utils/app_logger.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final _supabase = Supabase.instance.client;
  late PresenceService _presenceService;

  SiteStatistics? _siteStats;
  int _onlineUsers = 0;
  int _onlineGuests = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _presenceService = PresenceService(_supabase);
    _loadStatistics();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    _presenceService.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      // Update statistics first
      await _presenceService.updateSiteStatistics();

      // Load statistics
      final stats = await _presenceService.getSiteStatistics();
      final onlineUsers = await _presenceService.getOnlineUsersCount();
      final onlineGuests = await _presenceService.getOnlineGuestsCount();

      setState(() {
        _siteStats = stats;
        _onlineUsers = onlineUsers;
        _onlineGuests = onlineGuests;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load statistics', error: e, stackTrace: stackTrace);
      setState(() => _isLoading = false);
    }
  }

  void _startRealTimeUpdates() {
    // Update online counts every 10 seconds
    Stream.periodic(const Duration(seconds: 10), (_) async {
      final onlineUsers = await _presenceService.getOnlineUsersCount();
      final onlineGuests = await _presenceService.getOnlineGuestsCount();

      if (mounted) {
        setState(() {
          _onlineUsers = onlineUsers;
          _onlineGuests = onlineGuests;
        });
      }
    }).listen((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('サイト統計'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Real-time section
                    Text(
                      'リアルタイム',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRealTimeCards(),
                    const SizedBox(height: 32),

                    // Today's statistics
                    Text(
                      '今日の統計',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTodayStatsCards(),
                    const SizedBox(height: 32),

                    // Overall statistics
                    Text(
                      '全体統計',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildOverallStatsCards(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRealTimeCards() {
    final totalOnline = _onlineUsers + _onlineGuests;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'オンライン',
                value: totalOnline.toString(),
                icon: Icons.circle,
                iconColor: Colors.green,
                subtitle: '合計',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: '登録ユーザー',
                value: _onlineUsers.toString(),
                icon: Icons.person,
                iconColor: Colors.blue,
                subtitle: 'オンライン',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'ゲスト',
                value: _onlineGuests.toString(),
                icon: Icons.visibility,
                iconColor: Colors.orange,
                subtitle: '閲覧中',
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()), // Spacer
          ],
        ),
      ],
    );
  }

  Widget _buildTodayStatsCards() {
    if (_siteStats == null) {
      return const Center(child: Text('統計データがありません'));
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: '新規登録',
                value: _siteStats!.newUsersToday.toString(),
                icon: Icons.person_add,
                iconColor: Colors.purple,
                subtitle: '人',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'アクティブ',
                value: _siteStats!.activeUsersToday.toString(),
                icon: Icons.trending_up,
                iconColor: Colors.teal,
                subtitle: '人',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverallStatsCards() {
    if (_siteStats == null) {
      return const Center(child: Text('統計データがありません'));
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: '総登録者数',
                value: _siteStats!.totalUsers.toString(),
                icon: Icons.people,
                iconColor: Colors.blue,
                subtitle: '人',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: '総メモ数',
                value: _siteStats!.totalNotesCreated.toString(),
                icon: Icons.note,
                iconColor: Colors.amber,
                subtitle: '件',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: '総共有数',
                value: _siteStats!.totalShares.toString(),
                icon: Icons.share,
                iconColor: Colors.green,
                subtitle: '回',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: '解除実績',
                value: _siteStats!.totalAchievementsUnlocked.toString(),
                icon: Icons.emoji_events,
                iconColor: Colors.orange,
                subtitle: '個',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required String subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
