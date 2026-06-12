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
  List<Map<String, dynamic>> _weekly = const <Map<String, dynamic>>[];
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
            if (_summaryLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                _summaryLabel!,
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
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
  const _TrendBars({required this.weekly});

  final List<Map<String, dynamic>> weekly;

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
    return SizedBox(
      height: 60,
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
                          30 *
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
                          30 *
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
