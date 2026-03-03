import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'ai_secretary_page.dart';
import 'cmo_page.dart';
import 'note_list_page.dart';

class AdminAnalyticsPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  const AdminAnalyticsPage({super.key, this.supabaseClient});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  List<Map<String, dynamic>> _dailyStats = [];
  int _actualUserCount = 0;
  int _lpTodayViews = 0;
  int _lpTotalViews = 0;
  bool _hasLpViewStats = false;
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

  void _overlayLandingPageViewSeries({
    required List<Map<String, dynamic>> dailyStats,
    required dynamic rawLpStats,
  }) {
    if (rawLpStats is! Map) return;

    final lpStats = Map<String, dynamic>.from(rawLpStats);
    final rawSeries = lpStats['series'];
    if (rawSeries is! List) return;

    final lpViewsByDate = <String, int>{};
    for (final row in rawSeries.whereType<Map>()) {
      final dateKey = _normalizeDateKey(row['date']);
      if (dateKey == null) continue;
      lpViewsByDate[dateKey] = _toInt(row['count']);
    }

    if (lpViewsByDate.isEmpty) return;

    for (final day in dailyStats) {
      final dateKey = _normalizeDateKey(day['date']);
      if (dateKey == null) continue;
      final lpViews = lpViewsByDate[dateKey];
      if (lpViews != null) {
        day['landing_views'] = lpViews;
      }
    }
  }

  String _resolvePriorityAcquisitionChannel(Map<String, int> sources) {
    final actionableEntries = sources.entries
        .where((entry) => entry.key != 'direct' && entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (actionableEntries.isEmpty) return 'x_share';
    return actionableEntries.first.key;
  }

  String _buildAcquisitionButtonLabel(
    String? channelKey,
    String? channelLabel,
  ) {
    switch (channelKey) {
      case 'x_share':
        return 'X投稿を作る';
      case 'line':
        return 'LINE導線を作る';
      case 'qr_scan':
        return 'QR導線を作る';
      case 'facebook':
        return 'Facebook投稿を作る';
      case 'direct':
        return '導線文を見直す';
      default:
        return '${channelLabel ?? '流入'}を強化';
    }
  }

  Widget _buildAcquisitionTargetPage(String? channelKey) {
    switch (channelKey) {
      case 'x_share':
      case 'facebook':
        return CmoPage(
          initialChannel: channelKey,
          autoGenerateOnOpen: true,
        );
      case 'line':
        return const AISecretaryPage(
          initialStrategyType: 'now',
          autoRunOnOpen: true,
        );
      case 'qr_scan':
        return const NoteListPage(prioritizeShareCandidates: true);
      default:
        return CmoPage(
          initialChannel: channelKey,
          autoGenerateOnOpen: true,
        );
    }
  }

  void _openGrowthAction({
    required bool isAcquisitionAction,
    String? priorityChannelKey,
    String? priorityChannelLabel,
  }) {
    final targetPage = isAcquisitionAction
        ? _buildAcquisitionTargetPage(priorityChannelKey)
        : const AISecretaryPage(
            initialStrategyType: 'now',
            autoRunOnOpen: true,
          );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => targetPage),
    );

    final hint = isAcquisitionAction
        ? switch (priorityChannelKey) {
            'line' => 'AI秘書を開きました。LINE向けの短文導線を先に作ってください。',
            'qr_scan' => 'ノート一覧を開きました。QR遷移先に使うコンテンツを先に整えてください。',
            'facebook' => 'Facebook向け草案を起案します。投稿文を先に作ってください。',
            _ => '${priorityChannelLabel ?? '最優先チャネル'}で最初の流入を作る導線を先に実行してください。',
          }
        : 'AI秘書を導線改善モードで開きました。訴求文と導線文言を先に整えてください。';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hint)),
    );
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
        _supabase.rpc('get_lp_view_stats'),
      ]);

      final statsResponse = results[0] as List<dynamic>;
      final profileResponse = results[1] as List<dynamic>;
      final userCountResponse = results[2];
      final lpStatsResponse = results[3];
      final mergedDailyStats = _buildMergedDailyStats(
        analyticsRows: statsResponse,
        profileRows: profileResponse,
        startDate: startDate,
        endDate: today,
      );
      _overlayLandingPageViewSeries(
        dailyStats: mergedDailyStats,
        rawLpStats: lpStatsResponse,
      );
      final totalUsers =
          userCountResponse is PostgrestResponse ? userCountResponse.count : 0;
      final lpStats = lpStatsResponse is Map
          ? Map<String, dynamic>.from(lpStatsResponse)
          : <String, dynamic>{};
      final hasLpViewStats = lpStats.isNotEmpty;

      if (mounted) {
        setState(() {
          _dailyStats = mergedDailyStats;
          _actualUserCount = totalUsers;
          _lpTodayViews = _toInt(lpStats['today']);
          _lpTotalViews = _toInt(lpStats['total']);
          _hasLpViewStats = hasLpViewStats;
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
    int analyticsViews = 0;
    int totalShares = 0;
    final Map<String, int> sourceBreakdown = {};
    final Map<String, int> shareChannelBreakdown = {};
    final todayKey = _dateKey(DateTime.now());
    var todayViews = 0;
    var todayRegistrations = 0;

    int maxDailyViews = 0;

    for (var stat in _dailyStats) {
      final views = _toInt(stat['landing_views']);
      final conv = _toInt(stat['conversions']);
      final statDateKey = _normalizeDateKey(stat['date']);

      analyticsViews += views;
      totalShares += _toInt(stat['share_count']);

      if (statDateKey == todayKey) {
        todayViews = views;
        todayRegistrations = conv;
      }
      if (views > maxDailyViews) maxDailyViews = views;

      final sources = stat['source_details'];
      if (sources != null && sources is Map) {
        sources.forEach((key, value) {
          final count = _toInt(value);
          if (count > 0) {
            final sourceKey = key.toString();
            final target = _isShareActionKey(sourceKey)
                ? shareChannelBreakdown
                : sourceBreakdown;
            target[sourceKey] = (target[sourceKey] ?? 0) + count;
          }
        });
      }
    }

    final chartData = _dailyStats.reversed.toList();
    final effectiveTodayViews = _hasLpViewStats ? _lpTodayViews : todayViews;
    final effectiveTotalLpViews =
        _hasLpViewStats ? _lpTotalViews : analyticsViews;
    final double todaySummaryCvr = effectiveTodayViews == 0
        ? 0
        : (todayRegistrations / effectiveTodayViews * 100);

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
                    _buildTodayRegistrationGoalCard(
                      todayViews: effectiveTodayViews,
                      todayRegistrations: todayRegistrations,
                      sourceBreakdown: sourceBreakdown,
                    ),
                    const SizedBox(height: 16),
                    _buildKpiSummaryCard(
                      todaySummaryCvr,
                      effectiveTodayViews,
                      todayRegistrations,
                      _actualUserCount,
                      totalShares,
                      effectiveTotalLpViews,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '過去30日間の推移 (LP View vs 実登録)',
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
                      'シェアチャネル (Share Actions)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildSourceDistribution(shareChannelBreakdown),
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

  Widget _buildTodayRegistrationGoalCard({
    required int todayViews,
    required int todayRegistrations,
    required Map<String, int> sourceBreakdown,
  }) {
    const dailyTarget = 1;
    final achieved = todayRegistrations >= dailyTarget;
    final remaining = achieved ? 0 : dailyTarget - todayRegistrations;
    final progress = (todayRegistrations / dailyTarget).clamp(0.0, 1.0);
    final accentColor = achieved ? Colors.green : Colors.redAccent;
    final todayCvr =
        todayViews == 0 ? 0.0 : (todayRegistrations / todayViews * 100);
    final diagnosisLabel = achieved
        ? '登録発生'
        : todayViews == 0
            ? '流入不足'
            : '登録率低下';
    final diagnosisColor = achieved
        ? Colors.green
        : todayViews == 0
            ? Colors.orange
            : Colors.redAccent;
    final priorityChannelKey = achieved || todayViews > 0
        ? null
        : _resolvePriorityAcquisitionChannel(sourceBreakdown);
    final priorityChannelLabel = priorityChannelKey == null
        ? null
        : _formatSourceName(priorityChannelKey);
    final actionTitle = achieved
        ? null
        : todayViews == 0
            ? '今やる集客アクション'
            : '今やる単独改善アクション';
    final actionDetail = achieved
        ? null
        : todayViews == 0
            ? '${priorityChannelLabel ?? 'X (Twitter)'}を最優先チャネルにして、投稿・共有・導線更新のうち1つだけ今すぐ実行する。'
            : '登録ボタン付近の文言を1つ減らし、最初の画面で「登録する理由」が分かる形に書き直します。';
    final actionIcon = achieved
        ? null
        : todayViews == 0
            ? Icons.campaign
            : Icons.alt_route;
    final actionButtonLabel = achieved
        ? null
        : todayViews == 0
            ? _buildAcquisitionButtonLabel(
                priorityChannelKey,
                priorityChannelLabel,
              )
            : 'AI改善で導線改善';
    final statusText = achieved
        ? '今日の登録目標は達成済みです。次は流入改善で上振れを狙う。'
        : todayViews == 0
            ? '今日の流入がありません。まずは露出導線を1つ増やして、訪問者を作ってください。'
            : '流れ込みはありますが登録が出ていません。登録率が著しく低下しています。';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: achieved
              ? const [Color(0xFFE8F5E9), Color(0xFFF6FFF7)]
              : const [Color(0xFFFFEBEE), Color(0xFFFFF8F8)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  achieved ? Icons.check_circle : Icons.track_changes,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今日の登録目標',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$todayRegistrations / $dailyTarget',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  achieved ? '達成' : '未達',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniKpiChip(
                label: '今日のLP View数',
                value: '$todayViews',
                color: Colors.blue,
              ),
              _buildMiniKpiChip(
                label: '今日のCVR',
                value: '${todayCvr.toStringAsFixed(1)}%',
                color: diagnosisColor,
              ),
              _buildMiniKpiChip(
                label: '登録率',
                value: diagnosisLabel,
                color: diagnosisColor,
              ),
              if (priorityChannelLabel != null)
                _buildMiniKpiChip(
                  label: '最優先チャネル',
                  value: priorityChannelLabel,
                  color: Colors.blueGrey,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            achieved ? statusText : '$statusText あと$remaining人の登録が必要です。',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          if (actionTitle != null &&
              actionDetail != null &&
              actionIcon != null &&
              actionButtonLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: diagnosisColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: diagnosisColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: diagnosisColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      actionIcon,
                      color: diagnosisColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: diagnosisColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          actionDetail,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: diagnosisColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () {
                            _openGrowthAction(
                              isAcquisitionAction: todayViews == 0,
                              priorityChannelKey: priorityChannelKey,
                              priorityChannelLabel: priorityChannelLabel,
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text(actionButtonLabel),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniKpiChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 以下、既存のウィジェットメソッド ---

  Widget _buildKpiSummaryCard(
    double cvr,
    int todayViews,
    int todayRegistrations,
    int totalRegistrations,
    int shares,
    int totalLpViews,
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
              '今日CVR (実登録ベース)',
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
                  '今日のLP View',
                  '$todayViews',
                  Icons.visibility,
                  Colors.blue,
                ),
                _buildStatItem(
                  '今日登録',
                  '$todayRegistrations',
                  Icons.person_add,
                  Colors.indigo,
                ),
                _buildStatItem(
                  '累計登録',
                  '$totalRegistrations',
                  Icons.group,
                  Colors.deepPurple,
                ),
                _buildStatItem(
                  '30日シェア',
                  '$shares',
                  Icons.share,
                  Colors.orange,
                ),
                _buildStatItem(
                  '累計LP View',
                  '$totalLpViews',
                  Icons.analytics,
                  Colors.teal,
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
                    final percent = (ratio * 100).toStringAsFixed(1);
                    return Expanded(
                      flex: e.value,
                      child: Tooltip(
                        message:
                            '${_formatSourceName(e.key)}: ${e.value} ($percent%)',
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

  bool _isShareActionKey(String key) {
    switch (key) {
      case 'share_x':
      case 'share_line':
      case 'share_facebook':
      case 'share_copy':
        return true;
      default:
        return false;
    }
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
      case 'copy_link':
        return 'リンクコピー';
      case 'share_x':
        return 'X シェア';
      case 'share_line':
        return 'LINE シェア';
      case 'share_facebook':
        return 'Facebook シェア';
      case 'share_copy':
        return 'リンクコピー';
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
      case 'copy_link':
        return Colors.deepPurple.shade300;
      case 'share_x':
        return Colors.black87;
      case 'share_line':
        return const Color(0xFF06C755);
      case 'share_facebook':
        return const Color(0xFF1877F2);
      case 'share_copy':
        return Colors.deepPurple.shade300;
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
