import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_stats.dart';
import '../models/achievement.dart';
import '../services/gamification_service.dart';
import '../widgets/level_display_widget.dart';
import '../widgets/stats_overview_widget.dart';
import '../widgets/achievement_card_widget.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late final GamificationService _gamificationService;
  UserStats? _stats;
  List<Achievement> _achievements = [];
  bool _isLoading = true;
  String? _error;
  AchievementCategory _selectedCategory = AchievementCategory.general;

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService(Supabase.instance.client);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Load stats
      var stats = await _gamificationService.getUserStats(userId);
      if (stats == null) {
        // Initialize stats if not found
        stats = await _gamificationService.initializeUserStats(userId);
      }

      // Load achievements
      final achievements = await _gamificationService.getUserAchievements(userId);

      setState(() {
        _stats = stats;
        _achievements = achievements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Achievement> get _filteredAchievements {
    if (_selectedCategory == AchievementCategory.general) {
      return _achievements;
    }
    return _achievements
        .where((a) => a.category == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統計・実績'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('エラーが発生しました'),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _stats == null
                  ? const Center(child: Text('統計データがありません'))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Level display
                            LevelDisplayWidget(stats: _stats!),
                            const SizedBox(height: 16),

                            // Stats overview
                            StatsOverviewWidget(stats: _stats!),
                            const SizedBox(height: 24),

                            // Achievements section
                            Text(
                              '実績',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),

                            // Achievement category filter
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildCategoryChip(
                                    context,
                                    '全て',
                                    AchievementCategory.general,
                                    Icons.grid_view,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    context,
                                    'メモ',
                                    AchievementCategory.notes,
                                    Icons.note_alt,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    context,
                                    'カテゴリ',
                                    AchievementCategory.categories,
                                    Icons.folder,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    context,
                                    '共有',
                                    AchievementCategory.sharing,
                                    Icons.share,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    context,
                                    '整理',
                                    AchievementCategory.organization,
                                    Icons.star,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildCategoryChip(
                                    context,
                                    '連続',
                                    AchievementCategory.streak,
                                    Icons.local_fire_department,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Achievement progress summary
                            _buildAchievementSummary(),
                            const SizedBox(height: 16),

                            // Achievement cards
                            if (_filteredAchievements.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text('このカテゴリに実績はありません'),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredAchievements.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return AchievementCardWidget(
                                    achievement: _filteredAchievements[index],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    AchievementCategory category,
    IconData icon,
  ) {
    final isSelected = _selectedCategory == category;
    final theme = Theme.of(context);

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? theme.colorScheme.onSecondaryContainer
                : theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = category;
        });
      },
      selectedColor: theme.colorScheme.secondaryContainer,
      checkmarkColor: theme.colorScheme.onSecondaryContainer,
    );
  }

  Widget _buildAchievementSummary() {
    final unlockedCount =
        _achievements.where((a) => a.isUnlocked).length;
    final totalCount = _achievements.length;
    final percentage = totalCount > 0 ? (unlockedCount / totalCount) : 0.0;

    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '実績進捗',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '$unlockedCount / $totalCount',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 12,
                backgroundColor:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(percentage * 100).toInt()}% 達成',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
