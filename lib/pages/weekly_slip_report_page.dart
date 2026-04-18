import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 週次 slip パターンレポートページ (#78+ T2拡張)
/// abstinence_slips テーブルの過去30日データを集計・可視化
class WeeklySlipReportPage extends StatefulWidget {
  const WeeklySlipReportPage({super.key});

  @override
  State<WeeklySlipReportPage> createState() => _WeeklySlipReportPageState();
}

class _WeeklySlipReportPageState extends State<WeeklySlipReportPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  // 集計データ
  int _totalSlips = 0;
  int _thisWeekSlips = 0;
  int _lastWeekSlips = 0;
  int _currentStreak = 0;
  List<_DayCount> _byDayOfWeek = [];
  List<_HourCount> _byHour = [];
  List<_ItemCount> _byItem = [];
  List<Map<String, dynamic>> _recentSlips = [];

  static const _primaryColor = Color(0xFF6366F1);

  static const Map<String, String> _itemLabels = {
    'sns': 'SNS',
    'mobile_games': 'スマホゲーム',
    'alcohol': '酒',
    'smoking': '煙草',
    'gambling': 'ギャンブル',
    'lust': '性欲',
    'smartphone': 'スマホ',
    'video': '動画',
    'manga': '漫画',
    'touch_hair': '髪をさわる',
    'touch_beard': '髭をさわる',
    'eating_out': '外食',
    'masturbation': 'オナニー',
    'dating_apps': '出会いアプリ',
  };

  static const List<String> _dayNames = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final thisWeekStart = now.subtract(Duration(days: now.weekday % 7));
      final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

      // 過去30日の全slip取得
      final slips = await _supabase
          .from('abstinence_slips')
          .select('item_id, slipped_at, day_of_week, hour_of_day, trigger_note')
          .eq('user_id', userId)
          .gte('slipped_at', thirtyDaysAgo.toIso8601String())
          .order('slipped_at', ascending: false);

      final List<Map<String, dynamic>> allSlips =
          List<Map<String, dynamic>>.from(slips);

      // 今週・先週カウント
      int thisWeek = 0;
      int lastWeek = 0;
      for (final s in allSlips) {
        final t = DateTime.parse(s['slipped_at'].toString());
        if (t.isAfter(thisWeekStart)) {
          thisWeek++;
        } else if (t.isAfter(lastWeekStart)) {
          lastWeek++;
        }
      }

      // 曜日別集計 (0=日, 6=土)
      final Map<int, int> dayMap = {};
      for (int i = 0; i < 7; i++) {
        dayMap[i] = 0;
      }
      for (final s in allSlips) {
        final dow = s['day_of_week'] as int? ?? 0;
        dayMap[dow] = (dayMap[dow] ?? 0) + 1;
      }
      final byDay = dayMap.entries
          .map((e) => _DayCount(day: e.key, count: e.value))
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));

      // 時間帯別集計 (4区間: 深夜0-5, 朝6-11, 昼12-17, 夜18-23)
      final Map<int, int> hourMap = {0: 0, 6: 0, 12: 0, 18: 0};
      for (final s in allSlips) {
        final h = s['hour_of_day'] as int? ?? 0;
        final bucket = h < 6
            ? 0
            : h < 12
                ? 6
                : h < 18
                    ? 12
                    : 18;
        hourMap[bucket] = (hourMap[bucket] ?? 0) + 1;
      }
      final byHour = [
        _HourCount(startHour: 0, label: '深夜 (0-5時)', count: hourMap[0]!),
        _HourCount(startHour: 6, label: '朝 (6-11時)', count: hourMap[6]!),
        _HourCount(startHour: 12, label: '昼 (12-17時)', count: hourMap[12]!),
        _HourCount(startHour: 18, label: '夜 (18-23時)', count: hourMap[18]!),
      ];

      // アイテム別集計
      final Map<String, int> itemMap = {};
      for (final s in allSlips) {
        final id = s['item_id'].toString();
        itemMap[id] = (itemMap[id] ?? 0) + 1;
      }
      final byItem = itemMap.entries
          .map(
            (e) => _ItemCount(
              id: e.key,
              label: _itemLabels[e.key] ?? e.key,
              count: e.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));

      // ストリーク計算: 今日を含む連続 slip なし日数
      final Set<String> slipDays = {};
      for (final s in allSlips) {
        final t = DateTime.parse(s['slipped_at'].toString()).toLocal();
        slipDays.add('${t.year}-${t.month}-${t.day}');
      }
      int streak = 0;
      for (int i = 0; i < 30; i++) {
        final d = now.subtract(Duration(days: i));
        final key = '${d.year}-${d.month}-${d.day}';
        if (slipDays.contains(key)) break;
        streak++;
      }

      setState(() {
        _totalSlips = allSlips.length;
        _thisWeekSlips = thisWeek;
        _lastWeekSlips = lastWeek;
        _currentStreak = streak;
        _byDayOfWeek = byDay;
        _byHour = byHour;
        _byItem = byItem;
        _recentSlips = allSlips.take(10).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('週次 Slip レポート'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _loadData,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null) _buildError(),
                  _buildKpiRow(),
                  const SizedBox(height: 16),
                  _buildDayOfWeekCard(),
                  const SizedBox(height: 12),
                  _buildTimeSlotCard(),
                  const SizedBox(height: 12),
                  _buildItemRankingCard(),
                  if (_recentSlips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildRecentCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildKpiRow() {
    final trend = _lastWeekSlips == 0
        ? null
        : (_thisWeekSlips - _lastWeekSlips) / _lastWeekSlips;
    final trendText = trend == null
        ? ''
        : trend <= 0
            ? '▼${(trend.abs() * 100).round()}%改善'
            : '▲${(trend * 100).round()}%悪化';
    final trendColor =
        trend == null || trend <= 0 ? Colors.green : Colors.orange;

    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: '現在ストリーク',
            value: '$_currentStreak日',
            icon: Icons.local_fire_department,
            color: _currentStreak >= 7
                ? Colors.deepOrange
                : _currentStreak >= 3
                    ? Colors.orange
                    : Color(0xFFB0B0B0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: '今週 slip 数',
            value: '$_thisWeekSlips回',
            subtitle: trendText,
            subtitleColor: trendColor,
            icon: Icons.bar_chart,
            color: _primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: '30日合計',
            value: '$_totalSlips回',
            icon: Icons.calendar_month,
            color: Colors.blueGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildDayOfWeekCard() {
    final maxCount = _byDayOfWeek.isEmpty
        ? 1
        : _byDayOfWeek.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '曜日別 slip 数 (過去30日)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_byDayOfWeek.isEmpty)
              const Text('データなし', style: TextStyle(color: Colors.black45))
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _byDayOfWeek.map((d) {
                  final ratio = maxCount == 0 ? 0.0 : d.count / maxCount;
                  final isWorst = d.count == maxCount && maxCount > 0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        children: [
                          Text(
                            '${d.count}',
                            style: TextStyle(
                              fontSize: 10,
                              color: isWorst ? Colors.red : Colors.black54,
                              fontWeight:
                                  isWorst ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 60 * ratio + 4,
                            decoration: BoxDecoration(
                              color: isWorst
                                  ? Colors.red.shade400
                                  : _primaryColor.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dayNames[d.day],
                            style: TextStyle(
                              fontSize: 11,
                              color: isWorst ? Colors.red : Colors.black54,
                              fontWeight:
                                  isWorst ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotCard() {
    final maxCount = _byHour.isEmpty
        ? 1
        : _byHour.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '時間帯別 slip 数 (過去30日)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_byHour.every((e) => e.count == 0))
              const Text('データなし', style: TextStyle(color: Colors.black45))
            else
              ..._byHour.map((h) {
                final ratio = maxCount == 0 ? 0.0 : h.count / maxCount;
                final isWorst = h.count == maxCount && maxCount > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          h.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isWorst ? Colors.red : Colors.black54,
                            fontWeight:
                                isWorst ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: Color(0xFFB0B0B0).shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: ratio,
                              child: Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isWorst
                                      ? Colors.red.shade400
                                      : _primaryColor.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${h.count}回',
                        style: TextStyle(
                          fontSize: 12,
                          color: isWorst ? Colors.red : Colors.black54,
                          fontWeight:
                              isWorst ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRankingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '妨害要因ランキング (過去30日)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_byItem.isEmpty)
              const Text('データなし', style: TextStyle(color: Colors.black45))
            else
              ..._byItem.take(5).toList().asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final item = entry.value;
                final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    medals[rank] ?? '$rank',
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(
                    item.label,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: rank == 1
                          ? Colors.red.shade50
                          : _primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${item.count}回',
                      style: TextStyle(
                        color: rank == 1 ? Colors.red.shade700 : _primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '最近の slip 履歴',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._recentSlips.map((s) {
              final itemId = s['item_id']?.toString() ?? '';
              final label = _itemLabels[itemId] ?? itemId;
              final slippedAt = s['slipped_at']?.toString() ?? '';
              final note = s['trigger_note']?.toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
                title: Text(label, style: const TextStyle(fontSize: 13)),
                subtitle: note != null && note.isNotEmpty
                    ? Text(note, style: const TextStyle(fontSize: 11))
                    : null,
                trailing: Text(
                  slippedAt.length >= 10
                      ? slippedAt.substring(0, 10)
                      : slippedAt,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DayCount {
  const _DayCount({required this.day, required this.count});
  final int day;
  final int count;
}

class _HourCount {
  const _HourCount({
    required this.startHour,
    required this.label,
    required this.count,
  });
  final int startHour;
  final String label;
  final int count;
}

class _ItemCount {
  const _ItemCount({
    required this.id,
    required this.label,
    required this.count,
  });
  final String id;
  final String label;
  final int count;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.subtitleColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
                color: subtitleColor ?? Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
