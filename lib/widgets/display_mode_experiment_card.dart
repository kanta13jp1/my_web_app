import 'package:flutter/material.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 表示モード実験(新規=標準既定)の全体集計カード。CFO 室向け。
/// rpc display_mode_experiment_summary を取得し、標準維持率と
/// 週次トレンド(初期解決=藍 / 切替=橙)を表示する。
class DisplayModeExperimentCard extends StatefulWidget {
  const DisplayModeExperimentCard({super.key});

  @override
  State<DisplayModeExperimentCard> createState() =>
      _DisplayModeExperimentCardState();
}

class _DisplayModeExperimentCardState extends State<DisplayModeExperimentCard> {
  String? _summaryLabel;
  String? _progressLabel;
  List<Map<String, dynamic>> _weekly = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _weeklyRetention = const <Map<String, dynamic>>[];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() {
        _error = 'ログインすると全体集計を表示できます';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic result = await Supabase.instance.client.rpc(
        'display_mode_experiment_summary',
      );
      if (!mounted || result is! Map) {
        return;
      }
      final parsed = AssetManagementDisplayModeStore.parseServerSummary(
        Map<String, dynamic>.from(result),
      );
      setState(() {
        _summaryLabel = parsed.summaryLabel;
        _weekly = parsed.weekly;
        _weeklyRetention = parsed.weeklyRetention;
        _progressLabel = _buildProgressLabel(parsed);
      });
    } catch (e) {
      debugPrint('experiment card fetch failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '取得に失敗しました(再試行できます)';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 「開始から N日・直近週 初期X(±Δ)/切替Y(±Δ)」を組み立てる。
  /// weekly は新しい週が先頭 (rpc 側で desc ソート済み)。
  String? _buildProgressLabel(AssetDisplayModeServerSummary parsed) {
    final parts = <String>[];
    final firstEventAt = parsed.firstEventAt;
    if (firstEventAt != null) {
      final days = DateTime.now().difference(firstEventAt).inDays + 1;
      parts.add('開始から $days日目');
    }
    if (parsed.weekly.isNotEmpty) {
      int countOf(Map<String, dynamic> week, String key) =>
          (week[key] as num?)?.toInt() ?? 0;
      String delta(int current, int previous) {
        final diff = current - previous;
        if (diff > 0) {
          return '+$diff';
        }
        return diff == 0 ? '±0' : '$diff';
      }

      final latest = parsed.weekly.first;
      final previous =
          parsed.weekly.length >= 2 ? parsed.weekly[1] : <String, dynamic>{};
      final initials = countOf(latest, 'initials');
      final switches = countOf(latest, 'switches');
      parts.add(
        '直近週 初期$initials(${delta(initials, countOf(previous, 'initials'))})'
        '/切替$switches(${delta(switches, countOf(previous, 'switches'))})',
      );
    }
    return parts.isEmpty ? null : parts.join('・');
  }

  /// タップ拡大: 大きいグラフ+週次の数値表を出す。
  Future<void> _showExpandedCharts() async {
    final retentionByWeek = <String, dynamic>{
      for (final week in _weeklyRetention)
        week['week_start']?.toString() ?? '': week['rate'],
    };
    String cell(Object? value) => value?.toString() ?? '-';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('表示モード実験 詳細グラフ'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_weeklyRetention.isNotEmpty) ...[
                  const Text(
                    '標準維持率%の推移(週末時点)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _RetentionBars(retention: _weeklyRetention, expanded: true),
                  const SizedBox(height: 12),
                ],
                if (_weekly.isNotEmpty) ...[
                  const Text(
                    '週次イベント(初期解決=藍 / 切替=橙)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _TrendBars(weekly: _weekly, expanded: true),
                  const SizedBox(height: 12),
                  const Text(
                    '週次の数値',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final week in _weekly)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '${cell(week['week_start'])}週: '
                        '初期${cell(week['initials'])}'
                        '(std${cell(week['initial_standard'])}) / '
                        '切替${cell(week['switches'])} / '
                        '維持率${cell(retentionByWeek[week['week_start']?.toString() ?? ''])}%',
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '表示モード実験(標準既定)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('display_mode_experiment_expand'),
                  tooltip: 'グラフを拡大',
                  icon: const Icon(Icons.zoom_out_map, size: 18),
                  onPressed: _weekly.isEmpty && _weeklyRetention.isEmpty
                      ? null
                      : _showExpandedCharts,
                ),
                IconButton(
                  key: const Key('display_mode_experiment_refresh'),
                  tooltip: '再取得',
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _loading ? null : _fetch,
                ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (_progressLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                _progressLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ],
            if (_summaryLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                _summaryLabel!,
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ],
            if (_weeklyRetention.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '標準維持率%の推移(週末時点)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              _RetentionBars(retention: _weeklyRetention),
            ],
            if (_weekly.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TrendBars(weekly: _weekly),
              const SizedBox(height: 4),
              const Wrap(
                spacing: 10,
                children: [
                  _LegendDot(color: Color(0xFF6366F1), label: '初期解決'),
                  _LegendDot(color: Color(0xFFF97316), label: '切替'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.weekly, this.expanded = false});

  final List<Map<String, dynamic>> weekly;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final weeks = weekly.reversed.toList(growable: false);
    var maxTotal = 1;
    for (final week in weeks) {
      final initials = (week['initials'] as num?)?.toInt() ?? 0;
      final switches = (week['switches'] as num?)?.toInt() ?? 0;
      if (initials + switches > maxTotal) {
        maxTotal = initials + switches;
      }
    }
    final barScale = expanded ? 100.0 : 30.0;
    return SizedBox(
      height: expanded ? 160 : 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final week in weeks)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(week['initials'] as num?)?.toInt() ?? 0}/${(week['switches'] as num?)?.toInt() ?? 0}',
                      style: const TextStyle(fontSize: 8, height: 1.2),
                    ),
                    Container(
                      height: 2 +
                          barScale *
                              ((week['switches'] as num?)?.toInt() ?? 0) /
                              maxTotal,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      height: 2 +
                          barScale *
                              ((week['initials'] as num?)?.toInt() ?? 0) /
                              maxTotal,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (week['week_start']?.toString() ?? '').length >= 10
                          ? week['week_start'].toString().substring(5, 10)
                          : '',
                      style: const TextStyle(fontSize: 7, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RetentionBars extends StatelessWidget {
  const _RetentionBars({required this.retention, this.expanded = false});

  final List<Map<String, dynamic>> retention;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final weeks = retention.reversed.toList(growable: false);
    final barScale = expanded ? 110.0 : 30.0;
    return SizedBox(
      height: expanded ? 170 : 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final week in weeks)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      week['rate'] == null
                          ? '-'
                          : '${(week['rate'] as num).toInt()}%',
                      style: const TextStyle(fontSize: 8, height: 1.2),
                    ),
                    Container(
                      height: 2 +
                          barScale *
                              ((week['rate'] as num?)?.toDouble() ?? 0) /
                              100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (week['week_start']?.toString() ?? '').length >= 10
                          ? week['week_start'].toString().substring(5, 10)
                          : '',
                      style: const TextStyle(fontSize: 7, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
