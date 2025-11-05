import 'package:flutter/material.dart';
import '../main.dart';
import '../services/gamification_service.dart';
import '../models/leaderboard_entry.dart';
import '../models/user_stats.dart';

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
    _loadLeaderboard();
    _loadUserStats();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final entries = await _gamificationService.getLeaderboard(
        limit: 100,
        orderBy: _orderBy,
      );
      final rank = await _gamificationService.getUserRank(
        supabase.auth.currentUser!.id,
        orderBy: _orderBy,
      );

      if (mounted) {
        setState(() {
          _entries = entries;
          _userRank = rank;
          _isLoading = false;
        });
      }
    } catch (error) {
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
    final currentUserId = supabase.auth.currentUser!.id;

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
          // ユーザーの順位表示
          if (_userStats != null && _userRank != null)
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
                          final isCurrentUser = entry.userId == currentUserId;
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
