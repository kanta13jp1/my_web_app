import 'package:flutter/material.dart';
import '../main.dart';
import '../services/gamification_service.dart';
import '../models/reward.dart';
import '../models/user_stats.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  late final GamificationService _gamificationService;
  List<Reward> _rewards = [];
  UserStats? _userStats;
  bool _isLoading = true;
  RewardType? _filterType;

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService();
    _loadRewards();
    _loadUserStats();
  }

  Future<void> _loadRewards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rewards = await _gamificationService.getUserRewards(
        supabase.auth.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          _rewards = rewards;
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
      // エラーは無視
    }
  }

  List<Reward> get _filteredRewards {
    if (_filterType == null) return _rewards;
    return _rewards.where((r) => r.type == _filterType).toList();
  }

  int get _unlockedCount => _filteredRewards.where((r) => r.isUnlocked).length;
  int get _totalCount => _filteredRewards.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('報酬'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRewards,
            tooltip: '更新',
          ),
        ],
      ),
      body: Column(
        children: [
          // 統計表示
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple,
                  Colors.deepPurple.withOpacity(0.7),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      '🏆',
                      '$_unlockedCount',
                      'アンロック済み',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      '🎁',
                      '$_totalCount',
                      '全報酬',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      '⭐',
                      '${((_unlockedCount / _totalCount) * 100).toStringAsFixed(0)}%',
                      '達成率',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // フィルター
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(null, 'すべて', Icons.grid_view),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                      RewardType.theme, 'テーマ', Icons.palette),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                      RewardType.badge, 'バッジ', Icons.military_tech),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                      RewardType.feature, '機能', Icons.star),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // 報酬リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRewards.isEmpty
                    ? const Center(
                        child: Text(
                          '報酬がありません',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filteredRewards.length,
                        itemBuilder: (context, index) {
                          final reward = _filteredRewards[index];
                          return _buildRewardCard(reward);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String icon, String value, String label) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(RewardType? type, String label, IconData icon) {
    final isSelected = _filterType == type;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _filterType = selected ? type : null;
        });
      },
    );
  }

  Widget _buildRewardCard(Reward reward) {
    return Card(
      elevation: reward.isUnlocked ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: reward.isUnlocked
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getRewardColor(reward.type).withOpacity(0.3),
                    _getRewardColor(reward.type).withOpacity(0.1),
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // アイコン
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: reward.isUnlocked
                          ? _getRewardColor(reward.type).withOpacity(0.2)
                          : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: reward.isUnlocked
                            ? _getRewardColor(reward.type)
                            : Colors.grey,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        reward.icon,
                        style: TextStyle(
                          fontSize: 36,
                          color: reward.isUnlocked ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  if (!reward.isUnlocked)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // タイトル
              Text(
                reward.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: reward.isUnlocked ? null : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // 説明
              Text(
                reward.description,
                style: TextStyle(
                  fontSize: 11,
                  color: reward.isUnlocked
                      ? Colors.grey[600]
                      : Colors.grey[400],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),

              // 要件
              if (!reward.isUnlocked) ...[
                const Divider(),
                Text(
                  _getRequirementText(reward),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getRewardColor(RewardType type) {
    switch (type) {
      case RewardType.theme:
        return Colors.purple;
      case RewardType.badge:
        return Colors.amber;
      case RewardType.feature:
        return Colors.blue;
      case RewardType.icon:
        return Colors.green;
    }
  }

  String _getRequirementText(Reward reward) {
    final requirements = <String>[];

    if (reward.requiredLevel > 0) {
      final currentLevel = _userStats?.currentLevel ?? 1;
      requirements.add('Lv.${reward.requiredLevel} (現在: Lv.$currentLevel)');
    }

    if (reward.requiredPoints != null) {
      final currentPoints = _userStats?.totalPoints ?? 0;
      requirements
          .add('${reward.requiredPoints}pt (現在: ${currentPoints}pt)');
    }

    if (reward.requiredAchievementId != null) {
      requirements.add('特定の実績が必要');
    }

    return requirements.join('\n');
  }
}
