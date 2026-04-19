import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/growth_mission_service.dart';

class LiveGrowthBanner extends StatefulWidget {
  final GrowthMissionService growthService;
  final bool compact;
  final String title;
  final String subtitle;

  const LiveGrowthBanner({
    super.key,
    this.growthService = const GrowthMissionService(),
    this.compact = false,
    this.title = 'ライブ成長メーター',
    this.subtitle = '登録者数・閲覧者数・流入を更新しながら確認できます。',
  });

  @override
  State<LiveGrowthBanner> createState() => _LiveGrowthBannerState();
}

class _LiveGrowthBannerState extends State<LiveGrowthBanner> {
  GrowthMissionDashboard _dashboard = GrowthMissionDashboard.empty();
  Timer? _refreshTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final nextDashboard = await widget.growthService.loadDashboard();
    if (!mounted) {
      return;
    }
    setState(() {
      _dashboard = nextDashboard;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numberFormat = NumberFormat.decimalPattern('ja');
    final compact = widget.compact;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _isLoading ? '更新中' : 'Live',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricChip(
                  label: '登録者数',
                  value: numberFormat.format(_dashboard.totalRegisteredUsers),
                  icon: Icons.group,
                ),
                _MetricChip(
                  label: '現在の閲覧者',
                  value: numberFormat.format(_dashboard.liveViewers),
                  icon: Icons.visibility,
                ),
                _MetricChip(
                  label: 'ログイン中',
                  value: numberFormat.format(_dashboard.liveRegisteredUsers),
                  icon: Icons.verified_user,
                ),
                _MetricChip(
                  label: 'ゲスト閲覧',
                  value: numberFormat.format(_dashboard.liveGuestViewers),
                  icon: Icons.people_alt_outlined,
                ),
                _MetricChip(
                  label: '今日の登録',
                  value: numberFormat.format(_dashboard.todayRegistrations),
                  icon: Icons.person_add_alt_1,
                ),
                _MetricChip(
                  label: '今日のLP閲覧',
                  value: numberFormat.format(_dashboard.todayLandingViews),
                  icon: Icons.insights,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CompetitorGapRow(
              label: 'Notion 100M+ 超えまで',
              gap: _dashboard.gapToBeatNotion,
              progress: _dashboard.progressToBeatNotion,
            ),
            const SizedBox(height: 10),
            _CompetitorGapRow(
              label: 'Evernote 250M+ 超えまで',
              gap: _dashboard.gapToBeatEvernote,
              progress: _dashboard.progressToBeatEvernote,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CompetitorGapRow extends StatelessWidget {
  final String label;
  final int gap;
  final double progress;

  const _CompetitorGapRow({
    required this.label,
    required this.gap,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern('ja');
    final clampedProgress = progress.clamp(0, 1).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '残り ${numberFormat.format(gap)} 人',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clampedProgress,
            minHeight: 10,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
