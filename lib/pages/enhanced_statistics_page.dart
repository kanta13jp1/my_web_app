import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../services/presence_service.dart';
import '../models/site_statistics.dart';
import '../models/growth_metrics.dart';
import '../widgets/growth_chart_widget.dart';
import '../utils/app_logger.dart';

class EnhancedStatisticsPage extends StatefulWidget {
  const EnhancedStatisticsPage({super.key});

  @override
  State<EnhancedStatisticsPage> createState() => _EnhancedStatisticsPageState();
}

class _EnhancedStatisticsPageState extends State<EnhancedStatisticsPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late PresenceService _presenceService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  SiteStatistics? _siteStats;
  int _onlineUsers = 0;
  int _onlineGuests = 0;
  List<GrowthMetrics> _growthMetrics = [];
  bool _isLoading = true;
  Timer? _realTimeUpdateTimer;
  String _selectedPeriod = '7days'; // 7days, 30days, 90days, all

  @override
  void initState() {
    super.initState();
    _presenceService = PresenceService(_supabase);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadStatistics();
    _startRealTimeUpdates();
    _animationController.forward();
  }

  @override
  void dispose() {
    _realTimeUpdateTimer?.cancel();
    _animationController.dispose();
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

      // Load growth metrics
      final metrics = await _loadGrowthMetrics(_selectedPeriod);

      setState(() {
        _siteStats = stats;
        _onlineUsers = onlineUsers;
        _onlineGuests = onlineGuests;
        _growthMetrics = metrics;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load statistics', error: e, stackTrace: stackTrace);
      setState(() => _isLoading = false);
    }
  }

  Future<List<GrowthMetrics>> _loadGrowthMetrics(String period) async {
    try {
      DateTime startDate;
      switch (period) {
        case '7days':
          startDate = DateTime.now().subtract(const Duration(days: 7));
          break;
        case '30days':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        case '90days':
          startDate = DateTime.now().subtract(const Duration(days: 90));
          break;
        case 'all':
        default:
          startDate = DateTime(2020, 1, 1); // Far in the past
          break;
      }

      final response = await _supabase
          .from('growth_metrics')
          .select()
          .gte('metric_date', startDate.toIso8601String())
          .order('metric_date', ascending: true);

      return (response as List)
          .map((json) => GrowthMetrics.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load growth metrics', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  void _startRealTimeUpdates() {
    _realTimeUpdateTimer?.cancel();
    _realTimeUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;

      try {
        final onlineUsers = await _presenceService.getOnlineUsersCount();
        final onlineGuests = await _presenceService.getOnlineGuestsCount();

        if (mounted) {
          setState(() {
            _onlineUsers = onlineUsers;
            _onlineGuests = onlineGuests;
          });
        }
      } catch (e) {
        AppLogger.error('Failed to update real-time counts', error: e);
      }
    });
  }

  void _onPeriodChanged(String? period) {
    if (period != null && period != _selectedPeriod) {
      setState(() {
        _selectedPeriod = period;
      });
      _loadStatistics();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('リアルタイム統計'),
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
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadStatistics,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero section with real-time metrics
                      _buildHeroSection(theme),
                      const SizedBox(height: 32),

                      // Real-time online section
                      _buildRealTimeSection(theme),
                      const SizedBox(height: 32),

                      // Period selector
                      _buildPeriodSelector(theme),
                      const SizedBox(height: 16),

                      // Growth charts
                      _buildGrowthCharts(),
                      const SizedBox(height: 32),

                      // Overall statistics
                      _buildOverallSection(theme),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroSection(ThemeData theme) {
    if (_siteStats == null) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.analytics,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            '総登録ユーザー数',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: _siteStats!.totalUsers),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Text(
                value.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 4),
              Text(
                '+${_siteStats!.newUsersToday} 今日',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeSection(ThemeData theme) {
    final totalOnline = _onlineUsers + _onlineGuests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'リアルタイム（5秒ごとに更新）',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAnimatedStatCard(
                title: 'オンライン合計',
                value: totalOnline,
                icon: Icons.circle,
                iconColor: Colors.green,
                gradient: [Colors.green[400]!, Colors.green[600]!],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAnimatedStatCard(
                title: '登録ユーザー',
                value: _onlineUsers,
                icon: Icons.person,
                iconColor: Colors.blue,
                gradient: [Colors.blue[400]!, Colors.blue[600]!],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAnimatedStatCard(
                title: 'ゲスト',
                value: _onlineGuests,
                icon: Icons.visibility,
                iconColor: Colors.orange,
                gradient: [Colors.orange[400]!, Colors.orange[600]!],
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradient,
  }) {
    return TweenAnimationBuilder<int>(
      key: ValueKey('$title-$value'),
      tween: IntTween(begin: value > 10 ? value - 5 : 0, end: value),
      duration: const Duration(milliseconds: 500),
      builder: (context, animatedValue, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 12),
              Text(
                animatedValue.toString(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return Row(
      children: [
        Text(
          '期間: ',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('7日間', '7days'),
                const SizedBox(width: 8),
                _buildPeriodChip('30日間', '30days'),
                const SizedBox(width: 8),
                _buildPeriodChip('90日間', '90days'),
                const SizedBox(width: 8),
                _buildPeriodChip('全期間', 'all'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onPeriodChanged(value),
      selectedColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
      ),
    );
  }

  Widget _buildGrowthCharts() {
    if (_growthMetrics.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('成長データがありません'),
          ),
        ),
      );
    }

    return Column(
      children: [
        GrowthChartWidget(
          metrics: _growthMetrics,
          title: 'ユーザー数の推移',
          valueExtractor: (m) => m.totalUsers.toString(),
          lineColor: Colors.blue,
        ),
        const SizedBox(height: 16),
        GrowthChartWidget(
          metrics: _growthMetrics,
          title: '新規ユーザー数（日次）',
          valueExtractor: (m) => m.newUsers.toString(),
          lineColor: Colors.green,
        ),
        const SizedBox(height: 16),
        GrowthChartWidget(
          metrics: _growthMetrics,
          title: 'メモ数の推移',
          valueExtractor: (m) => m.totalNotes.toString(),
          lineColor: Colors.orange,
        ),
        const SizedBox(height: 16),
        GrowthChartWidget(
          metrics: _growthMetrics,
          title: 'アクティブユーザー数（日次）',
          valueExtractor: (m) => m.activeUsers.toString(),
          lineColor: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildOverallSection(ThemeData theme) {
    if (_siteStats == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '全体統計',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              title: '総メモ数',
              value: _siteStats!.totalNotesCreated.toString(),
              icon: Icons.note,
              iconColor: Colors.amber,
            ),
            _buildStatCard(
              title: '総共有数',
              value: _siteStats!.totalShares.toString(),
              icon: Icons.share,
              iconColor: Colors.green,
            ),
            _buildStatCard(
              title: '解除実績',
              value: _siteStats!.totalAchievementsUnlocked.toString(),
              icon: Icons.emoji_events,
              iconColor: Colors.orange,
            ),
            _buildStatCard(
              title: 'アクティブ（今日）',
              value: _siteStats!.activeUsersToday.toString(),
              icon: Icons.trending_up,
              iconColor: Colors.teal,
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
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
