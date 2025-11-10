import 'package:flutter/material.dart';
import '../main.dart';
import '../services/gamification_service.dart';
import '../models/leaderboard_entry.dart';
import '../models/user_stats.dart';
import 'auth_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late final GamificationService _gamificationService;
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;
  String _orderBy = 'total_points';
  int? _userRank;
  UserStats? _userStats;
  bool _isAuthenticated = false;

  final Map<String, String> _orderByLabels = {
    'total_points': '総ポイント',
    'current_level': 'レベル',
    'notes_created': 'メモ数',
    'current_streak': '連続記録',
  };

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService();
    _isAuthenticated = supabase.auth.currentUser != null;
    _loadLeaderboard();
    if (_isAuthenticated) {
      _loadUserStats();
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🏆 [LeaderboardPage] Loading leaderboard...');
      print('🏆 [LeaderboardPage] Order by: $_orderBy');
      print('🏆 [LeaderboardPage] Is authenticated: $_isAuthenticated');

      final entries = await _gamificationService.getLeaderboard(
        limit: 100,
        orderBy: _orderBy,
      );

      print('✅ [LeaderboardPage] Leaderboard loaded: ${entries.length} entries');
      if (entries.isEmpty) {
        print('⚠️ [LeaderboardPage] No entries found - this could be a RLS policy issue');
      }

      // 認証済みユーザーの場合のみランクを取得
      int? rank;
      if (_isAuthenticated) {
        print('🏆 [LeaderboardPage] Getting user rank...');
        final userId = supabase.auth.currentUser!.id;
        print('🏆 [LeaderboardPage] User ID: $userId');

        rank = await _gamificationService.getUserRank(
          userId,
          orderBy: _orderBy,
        );
        print('✅ [LeaderboardPage] User rank: $rank');
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _userRank = rank;
          _isLoading = false;
        });
      }
    } catch (error, stackTrace) {
      print('❌ [LeaderboardPage] Failed to load leaderboard');
      print('❌ [LeaderboardPage] Error: $error');
      print('❌ [LeaderboardPage] Error type: ${error.runtimeType}');
      print('❌ [LeaderboardPage] Stack trace: $stackTrace');

      if (error.toString().contains('row level security')) {
        print('🔒 [LeaderboardPage] RLS policy error detected');
        print('🔒 [LeaderboardPage] Check user_stats table RLS policies');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error')),
        );
      }
    }
  }

  Future<void> _loadUserStats() async {
    if (!_isAuthenticated) return;

    try {
      final stats = await _gamificationService.getUserStats(
        supabase.auth.currentUser!.id,
      );
      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    } catch (error) {
      // エラーは無視（ランキング表示には影響しない）
    }
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _isAuthenticated ? supabase.auth.currentUser!.id : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('リーダーボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 未認証ユーザー向けバナー
          if (!_isAuthenticated)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ランキングに参加しよう！',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'アカウントを作成してメモを書き始めると\nリーダーボードに参加できます',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthPage(initialMode: AuthMode.signUp),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          '無料で始める',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthPage(initialMode: AuthMode.signIn),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text(
                          'ログイン',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ユーザーの順位表示（認証済みのみ）
          if (_isAuthenticated && _userStats != null && _userRank != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _userRank.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'あなたの順位',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${_userRank}位',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Lv.${_userStats!.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_userStats!.totalPoints}pt',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ソート選択
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'ランキング:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: _orderByLabels.entries.map((entry) {
                      return ButtonSegment(
                        value: entry.key,
                        label: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    selected: {_orderBy},
                    onSelectionChanged: (Set<String> selected) {
                      setState(() {
                        _orderBy = selected.first;
                      });
                      _loadLeaderboard();
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ランキングリスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? const Center(
                        child: Text(
                          'まだランキングがありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final isCurrentUser = _isAuthenticated && entry.userId == currentUserId;
                          final rankEmoji = _getRankEmoji(entry.rank);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            color: isCurrentUser
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)
                                : null,
                            child: ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _getRankColor(entry.rank)
                                      .withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _getRankColor(entry.rank),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    rankEmoji.isNotEmpty
                                        ? rankEmoji
                                        : '${entry.rank}',
                                    style: TextStyle(
                                      fontSize: rankEmoji.isNotEmpty ? 24 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: rankEmoji.isEmpty
                                          ? _getRankColor(entry.rank)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    entry.userName ?? 'ユーザー',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrentUser
                                          ? Theme.of(context).primaryColor
                                          : null,
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'あなた',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                'Lv.${entry.currentLevel} • ${entry.notesCreated}メモ • ${entry.currentStreak}日連続',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _getDisplayValue(entry),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _getRankColor(entry.rank),
                                    ),
                                  ),
                                  Text(
                                    _getDisplayLabel(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _getDisplayValue(LeaderboardEntry entry) {
    switch (_orderBy) {
      case 'total_points':
        return '${entry.totalPoints}pt';
      case 'current_level':
        return 'Lv.${entry.currentLevel}';
      case 'notes_created':
        return '${entry.notesCreated}個';
      case 'current_streak':
        return '${entry.currentStreak}日';
      default:
        return '';
    }
  }

  String _getDisplayLabel() {
    return _orderByLabels[_orderBy] ?? '';
  }
}
