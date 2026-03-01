import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  const AdminAnalyticsPage({super.key, this.supabaseClient});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  List<Map<String, dynamic>> _dailyStats = [];
  int _actualUserCount = 0;
  bool _isLoading = true;
  late final SupabaseClient _supabase;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(_startOfDay(date));

  String? _normalizeDateKey(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return _dateKey(parsed.toLocal());
    }

    // Keep plain yyyy-MM-dd values as-is if parsing fails.
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  void _mergeSourceCounts(Map<String, int> target, dynamic rawSourceDetails) {
    if (rawSourceDetails is! Map) return;
    rawSourceDetails.forEach((key, value) {
      final sourceKey = key.toString();
      final count = _toInt(value);
      if (sourceKey.isEmpty || count <= 0) return;
      target.update(
        sourceKey,
        (current) => current + count,
        ifAbsent: () => count,
      );
    });
  }

  List<Map<String, dynamic>> _buildMergedDailyStats({
    required List<dynamic> analyticsRows,
    required List<dynamic> profileRows,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final statsByDate = <String, Map<String, dynamic>>{};

    Map<String, dynamic> ensureDay(String dateKey) {
      return statsByDate.putIfAbsent(
        dateKey,
        () => <String, dynamic>{
          'date': dateKey,
          'landing_views': 0,
          'conversions': 0,
          'share_count': 0,
          'source_details': <String, int>{},
        },
      );
    }

    for (final row in analyticsRows.whereType<Map>()) {
      final dateKey = _normalizeDateKey(row['date']);
      if (dateKey == null) continue;
      final day = ensureDay(dateKey);
      day['landing_views'] =
          _toInt(day['landing_views']) + _toInt(row['landing_views']);
      day['share_count'] =
          _toInt(day['share_count']) + _toInt(row['share_count']);
      final mergedSources = Map<String, int>.from(day['source_details'] as Map);
      _mergeSourceCounts(mergedSources, row['source_details']);
      day['source_details'] = mergedSources;
    }

    for (final row in profileRows.whereType<Map>()) {
      final createdAtRaw = row['created_at'];
      final createdAt = createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw.toString())?.toLocal();
      if (createdAt == null) continue;

      final dateKey = _dateKey(createdAt);
      final day = ensureDay(dateKey);
      day['conversions'] = _toInt(day['conversions']) + 1;
    }

    for (DateTime day = _startOfDay(startDate);
        !day.isAfter(_startOfDay(endDate));
        day = day.add(const Duration(days: 1))) {
      ensureDay(_dateKey(day));
    }

    final merged = statsByDate.values.toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return merged;
  }

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final today = _startOfDay(DateTime.now());
      final startDate = today.subtract(const Duration(days: 29));
      final startDateKey = _dateKey(startDate);
      final endDateKey = _dateKey(today);

      final results = await Future.wait<dynamic>([
        _supabase
            .from('app_analytics')
            .select()
            .gte('date', startDateKey)
            .lte('date', endDateKey)
            .order('date', ascending: false),
        _supabase
            .from('user_profiles')
            .select('created_at')
            .gte('created_at', startDate.toIso8601String()),
        _supabase
            .from('user_profiles')
            .select('user_id')
            .count(CountOption.exact),
      ]);

      final statsResponse = results[0] as List<dynamic>;
      final profileResponse = results[1] as List<dynamic>;
      final userCountResponse = results[2];
      final mergedDailyStats = _buildMergedDailyStats(
        analyticsRows: statsResponse,
        profileRows: profileResponse,
        startDate: startDate,
        endDate: today,
      );
      final totalUsers =
          userCountResponse is PostgrestResponse ? userCountResponse.count : 0;

      if (mounted) {
        setState(() {
          _dailyStats = mergedDailyStats;
          _actualUserCount = totalUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★追加: データリセット処理
  Future<void> _resetAnalyticsData() async {
    // 確認ダイアログを表示
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データのリセット'),
        content: const Text(
          '分析データ(app_analytics)をすべて削除します。\nこの操作は元に戻せません。\n本当によろしいですか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('リセット実行'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // app_analytics には id 列がないため、日付キー単位で全件削除する。
      final rows = await _supabase.from('app_analytics').select('date');
      final dateKeys = rows
          .whereType<Map>()
          .map((row) => row['date']?.toString())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      for (final dateKey in dateKeys) {
        await _supabase.from('app_analytics').delete().eq('date', dateKey);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分析データをリセットしました')),
        );
        // 再読み込み
        await _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // データ集計
    int totalViews = 0;
    int totalConversions = 0;
    int totalShares = 0;
    final Map<String, int> sourceBreakdown = {};

    int maxDailyViews = 0;

    for (var stat in _dailyStats) {
      final views = _toInt(stat['landing_views']);
      final conv = _toInt(stat['conversions']);

      totalViews += views;
      totalConversions += conv;
      totalShares += _toInt(stat['share_count']);

      if (views > maxDailyViews) maxDailyViews = views;

      final sources = stat['source_details'];
      if (sources != null && sources is Map) {
        sources.forEach((key, value) {
          final count = value as int? ?? 0;
          if (count > 0) {
            sourceBreakdown[key.toString()] =
                (sourceBreakdown[key.toString()] ?? 0) + count;
          }
        });
      }
    }

    final chartData = _dailyStats.reversed.toList();
    final double totalCvr =
        totalViews == 0 ? 0 : (totalConversions / totalViews * 100);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          '経営分析ダッシュボード',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // ★追加: リセットボタン（ゴミ箱アイコン）
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _resetAnalyticsData,
            tooltip: 'データをリセット',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadStats();
            },
            tooltip: 'データを更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildKpiSummaryCard(
                      totalCvr,
                      totalViews,
                      totalConversions,
                      _actualUserCount,
                      totalShares,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '過去30日間の推移 (閲覧 vs 実登録)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildTrendChart(chartData, maxDailyViews),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '流入元チャネル (Source Breakdown)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildSourceDistribution(sourceBreakdown),
                    const SizedBox(height: 24),
                    const Text(
                      '日次レポート詳細',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildDailyList(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // --- 以下、既存のウィジェットメソッド ---

  Widget _buildKpiSummaryCard(
    double cvr,
    int views,
    int registrations,
    int users,
    int shares,
  ) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              '直近30日CVR (実登録ベース)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  cvr.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _getCvrColor(cvr),
                    height: 1.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _getCvrColor(cvr),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildStatItem(
                  '30日閲覧',
                  '$views',
                  Icons.visibility,
                  Colors.blue,
                ),
                _buildStatItem(
                  '30日登録',
                  '$registrations',
                  Icons.person_add,
                  Colors.indigo,
                ),
                _buildStatItem(
                  '累計登録者',
                  '$users',
                  Icons.group,
                  Colors.deepPurple,
                ),
                _buildStatItem(
                  '30日シェア',
                  '$shares',
                  Icons.share,
                  Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCvrColor(double cvr) {
    if (cvr >= 10) return Colors.green;
    if (cvr >= 5) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildTrendChart(List<Map<String, dynamic>> data, int maxViews) {
    if (data.isEmpty) {
      return const Center(child: Text('データがありません'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final barWidth = (width / (data.length * 2.5)).clamp(6.0, 16.0);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: data.map((stat) {
            final views = _toInt(stat['landing_views']);
            final conv = _toInt(stat['conversions']);

            final double viewHeightRatio =
                maxViews == 0 ? 0 : (views / maxViews).clamp(0.0, 1.0);
            final double convHeightRatio =
                maxViews == 0 ? 0 : (conv / maxViews).clamp(0.0, 1.0);

            String label = '';
            try {
              final date = DateTime.parse(stat['date'].toString());
              label = '${date.month}/${date.day}';
            } catch (_) {
              label = '';
            }

            final shouldShowLabel = data.length <= 7 ||
                data.indexOf(stat) % (data.length ~/ 5) == 0 ||
                data.indexOf(stat) == data.length - 1;

            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      FractionallySizedBox(
                        heightFactor: viewHeightRatio,
                        child: Container(
                          width: barWidth,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        heightFactor: convHeightRatio,
                        child: Container(
                          width: barWidth,
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  shouldShowLabel ? label : '',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSourceDistribution(Map<String, int> sources) {
    if (sources.isEmpty) {
      return const Card(
        elevation: 0,
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('データなし', style: TextStyle(color: Colors.grey)),
          ),
        ),
      );
    }

    final int total = sources.values.fold(0, (sum, count) => sum + count);

    final sortedEntries = sources.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 24,
                child: Row(
                  children: sortedEntries.map((e) {
                    final double ratio = e.value / total;
                    return Expanded(
                      flex: e.value,
                      child: Tooltip(
                        message:
                            '${_formatSourceName(e.key)}: ${e.value} ($ratio%)',
                        child: Container(color: _getSourceColor(e.key)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: sortedEntries.map((e) {
                final percent = (e.value / total * 100).toStringAsFixed(1);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _getSourceColor(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatSourceName(e.key),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      ' $percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSourceName(String key) {
    switch (key) {
      case 'direct':
        return '直接/その他';
      case 'x_share':
        return 'X (Twitter)';
      case 'qr_scan':
        return 'QRコード';
      case 'facebook':
        return 'Facebook';
      case 'line':
        return 'LINE';
      default:
        return key;
    }
  }

  Color _getSourceColor(String key) {
    switch (key) {
      case 'direct':
        return Colors.grey.shade400;
      case 'x_share':
        return Colors.black;
      case 'qr_scan':
        return Colors.teal;
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'line':
        return const Color(0xFF06C755);
      default:
        return Colors.indigo.shade300;
    }
  }

  Widget _buildDailyList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _dailyStats.length,
      itemBuilder: (context, index) {
        final stat = _dailyStats[index];
        final views = _toInt(stat['landing_views']);
        final conv = _toInt(stat['conversions']);
        final cvr = views == 0 ? 0.0 : (conv / views * 100);

        String dateStr = stat['date'].toString();
        try {
          final d = DateTime.parse(dateStr);
          dateStr = DateFormat('yyyy/MM/dd').format(d);
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            title: Text(
              dateStr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Row(
              children: [
                _miniStat(Icons.visibility, '$views', Colors.blue),
                const SizedBox(width: 12),
                _miniStat(Icons.person_add, '$conv', Colors.indigo),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getCvrColor(cvr).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${cvr.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _getCvrColor(cvr),
                    ),
                  ),
                  Text(
                    'CVR',
                    style: TextStyle(fontSize: 10, color: _getCvrColor(cvr)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(IconData icon, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
