import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 習慣ゲーミフィケーションページ
/// habit-gamification Edge Function と連携
/// Duolingo / Forest / Habitica 競合
class HabitGamificationPage extends StatefulWidget {
  const HabitGamificationPage({super.key});

  @override
  State<HabitGamificationPage> createState() => _HabitGamificationPageState();
}

class _HabitGamificationPageState extends State<HabitGamificationPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['challenges', 'badges', 'leaderboard'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _profile = {};
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'habit.gamification.profile'},
        ),
        _supabase.functions
            .invoke('tools-hub', body: {'action': 'habit.gamification.badges'}),
        _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'habit.gamification.challenges'},
        ),
        _supabase.functions.invoke(
          'tools-hub',
          body: {'action': 'habit.gamification.leaderboard'},
        ),
      ]);
      setState(() {
        final profileData = results[0].data;
        if (profileData is Map<String, dynamic>) {
          _profile = (profileData['profile'] as Map<String, dynamic>?) ?? {};
        }
        final badgesData = results[1].data;
        if (badgesData is Map<String, dynamic>) {
          final list = badgesData['badges'];
          if (list is List) {
            _badges = list.map((b) => b as Map<String, dynamic>).toList();
          }
        }
        final challengesData = results[2].data;
        if (challengesData is Map<String, dynamic>) {
          final list = challengesData['challenges'];
          if (list is List) {
            _challenges = list.map((c) => c as Map<String, dynamic>).toList();
          }
        }
        final leaderboardData = results[3].data;
        if (leaderboardData is Map<String, dynamic>) {
          final list = leaderboardData['leaderboard'];
          if (list is List) {
            _leaderboard = list.map((l) => l as Map<String, dynamic>).toList();
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _completeChallenge(String type) async {
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'habit.gamification.award', 'badge_type': type},
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        final xp = data['xpEarned'] as int? ?? 0;
        final newBadges = data['newBadges'] as List? ?? [];
        if (mounted) {
          String msg = '+${xp}XP 獲得！';
          if (newBadges.isNotEmpty) msg += ' バッジ解除: ${newBadges.join(', ')}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
          _fetchAll();
        }
      } else if (data is Map<String, dynamic>) {
        final err = data['error'] as String? ?? '不明なエラー';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: const Color(0xFFFF6B35),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  IconData _badgeIcon(String icon) {
    switch (icon) {
      case 'star':
        return Icons.star;
      case 'fire':
        return Icons.local_fire_department;
      case 'trophy':
        return Icons.emoji_events;
      case 'crown':
        return Icons.workspace_premium;
      case 'shield':
        return Icons.shield;
      case 'check':
        return Icons.check_circle;
      case 'medal':
        return Icons.military_tech;
      case 'sun':
        return Icons.wb_sunny;
      case 'moon':
        return Icons.nightlight;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = _profile['level'] as int? ?? 1;
    final totalXp = _profile['total_xp'] as int? ?? 0;
    final currentXp = _profile['currentXp'] as int? ?? 0;
    final nextLevelXp = _profile['nextLevelXp'] as int? ?? 100;
    final streak = _profile['streak_days'] as int? ?? 0;
    final totalTasks = _profile['total_tasks'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('習慣ゲーミフィケーション'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'デイリー'),
            Tab(icon: Icon(Icons.military_tech), text: 'バッジ'),
            Tab(icon: Icon(Icons.leaderboard), text: 'ランキング'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _fetchAll,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      TextButton(
                        onPressed: _fetchAll,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildProfileCard(
                      level,
                      totalXp,
                      currentXp,
                      nextLevelXp,
                      streak,
                      totalTasks,
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildChallengesTab(),
                          _buildBadgesTab(),
                          _buildLeaderboardTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildProfileCard(
    int level,
    int totalXp,
    int currentXp,
    int nextLevelXp,
    int streak,
    int totalTasks,
  ) {
    final progress = nextLevelXp > 0 ? currentXp / nextLevelXp : 0.0;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFF311B92)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFFFC107),
                child: Text(
                  'Lv$level',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '総XP: $totalXp',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFC107),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currentXp / $nextLevelXp XP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip(
                Icons.local_fire_department,
                '$streak日連続',
                const Color(0xFFFF6B35),
              ),
              _statChip(
                Icons.check_circle,
                '$totalTasks タスク',
                const Color(0xFF4CAF50),
              ),
              _statChip(
                Icons.stars,
                '${_badges.where((b) => b['earned'] == true).length}バッジ',
                const Color(0xFFFFC107),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildChallengesTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completedCount =
        _challenges.where((c) => c['completed'] == true).length;
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'デイリーチャレンジ: $completedCount / ${_challenges.length} 完了',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          ..._challenges.map((c) {
            final completed = c['completed'] == true;
            final xp = c['xp'] as int? ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: completed
                  ? (isDark ? const Color(0xFF0A1A0A) : const Color(0xFFE8F5E9))
                  : null,
              child: ListTile(
                leading: Icon(
                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: completed
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFF9CA3AF),
                ),
                title: Text(
                  c['title'] as String? ?? '',
                  style: TextStyle(
                    decoration: completed ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                subtitle: Text(c['description'] as String? ?? ''),
                trailing: completed
                    ? Chip(
                        label: Text('+${xp}XP'),
                        backgroundColor: isDark
                            ? const Color(0xFF0A2A0A)
                            : const Color(0xFFC8E6C9),
                        labelStyle: const TextStyle(
                          color: Color(0xFF4CAF50),
                          height: 1.5,
                        ),
                      )
                    : FilledButton.tonal(
                        onPressed: () =>
                            _completeChallenge(c['type'] as String? ?? ''),
                        child: Text('+${xp}XP'),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBadgesTab() {
    final earnedBadges = _badges.where((b) => b['earned'] == true).toList();
    final unearnedBadges = _badges.where((b) => b['earned'] != true).toList();
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '獲得済み: ${earnedBadges.length} / ${_badges.length}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (earnedBadges.isNotEmpty) ...[
            const Text(
              '🏆 獲得済みバッジ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: earnedBadges
                  .map((b) => _buildBadgeChip(b, earned: true))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            '🔒 未獲得バッジ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: unearnedBadges
                .map((b) => _buildBadgeChip(b, earned: false))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(Map<String, dynamic> badge, {required bool earned}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = badge['icon'] as String? ?? 'star';
    final name = badge['name'] as String? ?? '';
    final desc = badge['description'] as String? ?? '';
    final xp = badge['xp'] as int? ?? 0;
    return Tooltip(
      message: '$desc (+${xp}XP)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: earned
              ? (isDark ? const Color(0xFF2A1800) : const Color(0xFFFFECB3))
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: earned
                ? const Color(0xFFFFC107)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _badgeIcon(icon),
              size: 18,
              color: earned ? const Color(0xFFFFA000) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                color:
                    earned ? const Color(0xFFFF6F00) : const Color(0xFF9CA3AF),
                fontWeight: earned ? FontWeight.bold : FontWeight.normal,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _leaderboard.length,
        itemBuilder: (context, i) {
          final entry = _leaderboard[i];
          final rank = entry['rank'] as int? ?? i + 1;
          final xp = entry['totalXp'] as int? ?? 0;
          final level = entry['level'] as int? ?? 1;
          final streak = entry['streakDays'] as int? ?? 0;
          Color rankColor = const Color(0xFF9CA3AF);
          if (rank == 1) {
            rankColor = const Color(0xFFFFC107);
          } else if (rank == 2) {
            rankColor = const Color(0xFF607D8B);
          } else if (rank == 3) {
            rankColor = const Color(0xFF795548);
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: rankColor.withValues(alpha: 0.15),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              title: Text(
                'Lv$level ユーザー',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              subtitle: Text('🔥 $streak日連続'),
              trailing: Text(
                '${xp}XP',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
