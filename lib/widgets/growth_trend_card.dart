import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// ホーム画面用の成長トレンドミニカード。
/// growth_metrics テーブルから直近14日のユーザー数推移を取得し、
/// ミニラインチャートで表示する。
class GrowthTrendCard extends StatefulWidget {
  const GrowthTrendCard({super.key});

  @override
  State<GrowthTrendCard> createState() => _GrowthTrendCardState();
}

class _GrowthTrendCardState extends State<GrowthTrendCard> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<_DayMetric> _metrics = [];
  int _currentUsers = 0;
  int _growthDiff = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 14));
      final sinceStr = DateFormat('yyyy-MM-dd').format(since);

      final data = await _supabase
          .from('growth_metrics')
          .select('metric_date, total_users, new_users')
          .gte('metric_date', sinceStr)
          .order('metric_date', ascending: true)
          .limit(14);

      if (!mounted) return;

      if ((data as List).isEmpty) {
        // growth_metrics が空なら user_profiles から現在値だけ取得
        final countRes = await _supabase
            .from('user_profiles')
            .select('user_id')
            .count(CountOption.exact);
        if (mounted) {
          setState(() {
            _currentUsers = countRes.count;
            _loading = false;
          });
        }
        return;
      }

      final metrics = data
          .map(
            (d) => _DayMetric(
              date: DateTime.tryParse(d['metric_date']?.toString() ?? '') ??
                  DateTime.now(),
              totalUsers: (d['total_users'] as num?)?.toInt() ?? 0,
              newUsers: (d['new_users'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList();

      final latestUsers = metrics.last.totalUsers;
      final firstUsers = metrics.first.totalUsers;

      setState(() {
        _metrics = metrics;
        _currentUsers = latestUsers;
        _growthDiff = latestUsers - firstUsers;
        _loading = false;
      });
    } catch (_) {
      // growth_metrics テーブルが空 or エラー時はユーザー数だけ表示
      try {
        final countRes = await _supabase
            .from('user_profiles')
            .select('user_id')
            .count(CountOption.exact);
        if (mounted) {
          setState(() {
            _currentUsers = countRes.count;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_currentUsers == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasChart = _metrics.length >= 2;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF6366F1).withAlpha(40)
              : const Color(0xFFDDD6FE),
        ),
      ),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.trending_up,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 6),
                Text(
                  'ユーザー成長グラフ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_currentUsers人',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    if (_growthDiff > 0)
                      Text(
                        '+$_growthDiff (14日間)',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (hasChart) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 18,
                          interval: (_metrics.length / 4).ceilToDouble(),
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= _metrics.length) {
                              return const Text('');
                            }
                            return Text(
                              DateFormat('M/d').format(_metrics[idx].date),
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFFBDBDBD),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _metrics.asMap().entries.map((e) {
                          return FlSpot(
                            e.key.toDouble(),
                            e.value.totalUsers.toDouble(),
                          );
                        }).toList(),
                        isCurved: true,
                        color: const Color(0xFF6366F1),
                        barWidth: 2.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF6366F1).withAlpha(30),
                        ),
                      ),
                    ],
                    minX: 0,
                    maxX: (_metrics.length - 1).toDouble(),
                    lineTouchData: const LineTouchData(enabled: false),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                '毎日のアクセスでグラフが描かれていきます',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF9E9E9E)
                      : const Color(0xFFBDBDBD),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayMetric {
  final DateTime date;
  final int totalUsers;
  final int newUsers;

  const _DayMetric({
    required this.date,
    required this.totalUsers,
    required this.newUsers,
  });
}
