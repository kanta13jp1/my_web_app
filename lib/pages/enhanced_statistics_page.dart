import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user_stats.dart';
import '../services/gamification_service.dart';
import '../widgets/page_view_stats.dart';
import '../utils/app_logger.dart';

class EnhancedStatisticsPage extends StatefulWidget {
  const EnhancedStatisticsPage({super.key});

  @override
  State<EnhancedStatisticsPage> createState() => _EnhancedStatisticsPageState();
}

class _EnhancedStatisticsPageState extends State<EnhancedStatisticsPage> {
  late final GamificationService _gamificationService;
  UserStats? _userStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 既存のPresenceServiceではなく、個人の成長を扱うGamificationServiceを使用
    _gamificationService = GamificationService(supabase);
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // ユーザー自身の統計データを取得
      var stats = await _gamificationService.getUserStats(userId);
      stats ??= await _gamificationService.initializeUserStats(userId);

      if (mounted) {
        setState(() {
          _userStats = stats;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading stats', error: e, stackTrace: stackTrace);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title:
            const Text('統計・実績', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserStats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. レベル・経験値カード (一番目立つヘッダー)
                  if (_userStats != null) _buildLevelHeader(theme, _userStats!),

                  const SizedBox(height: 24),

                  // 2. 今日のミッション (訪問者数カウンター)
                  // ここを「ミッション」として見せることで、毎日見に来る理由を作る
                  const Text(
                    '🔥 今日のミッション',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'このページへの訪問者数に応じてボーナス獲得！',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      // pagePathを '/statistics' に設定し、このページ専用のカウントを行う
                      child: const PageViewStats(pagePath: '/statistics'),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. 詳細統計グリッド (個人の成果)
                  const Text(
                    '📊 活動データ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_userStats != null) _buildStatsGrid(_userStats!),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // レベル表示ヘッダー
  Widget _buildLevelHeader(ThemeData theme, UserStats stats) {
    // 次のレベルまでの進捗計算 (仮: 1レベル = 1000pt)
    const int pointsPerLevel = 1000;
    final int nextLevelPoints = (stats.currentLevel + 1) * pointsPerLevel;
    final int currentLevelBasePoints = stats.currentLevel * pointsPerLevel;
    // 現在のレベル内での進捗ポイント
    final int progressPoints = stats.totalPoints - currentLevelBasePoints;
    // 進捗率 (0.0 - 1.0)
    final double progress = (progressPoints / pointsPerLevel).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor,
            theme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '現在のレベル',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${stats.currentLevel}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LEVEL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '次のレベルまで',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12),
                  ),
                  Text(
                    'あと ${pointsPerLevel - progressPoints} pt',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 進捗バー
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 統計グリッド
  Widget _buildStatsGrid(UserStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: Icons.note_alt,
          color: Colors.blue,
          label: '作成したメモ',
          value: '${stats.notesCreated}',
        ),
        _buildStatCard(
          icon: Icons.local_fire_department,
          color: Colors.orange,
          label: '連続記録',
          value: '${stats.currentStreak}日',
        ),
        _buildStatCard(
          icon: Icons.folder,
          color: Colors.amber,
          label: '総ポイント',
          value: '${stats.totalPoints}',
        ),
        // 将来的にシェア数などをUserStatsに追加した際にここを更新
        _buildStatCard(
          icon: Icons.share,
          color: Colors.green,
          label: 'シェア回数',
          value: 'Check!',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
