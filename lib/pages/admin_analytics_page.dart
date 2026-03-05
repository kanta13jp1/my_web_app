import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'ai_secretary_page.dart';
import 'cmo_page.dart';
import 'note_list_page.dart';

class _FunnelMetrics {
  final int trialRuns;
  final int saveClicks;
  final int magicLinkSends;
  final int inboxOpens;

  const _FunnelMetrics({
    required this.trialRuns,
    required this.saveClicks,
    required this.magicLinkSends,
    required this.inboxOpens,
  });
}

class _GrowthActionPlan {
  final String bottleneckLabel;
  final String title;
  final String detail;
  final IconData icon;
  final String buttonLabel;
  final bool isAcquisitionAction;

  const _GrowthActionPlan({
    required this.bottleneckLabel,
    required this.title,
    required this.detail,
    required this.icon,
    required this.buttonLabel,
    required this.isAcquisitionAction,
  });
}

class AdminAnalyticsPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  const AdminAnalyticsPage({super.key, this.supabaseClient});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  List<Map<String, dynamic>> _dailyStats = [];
  List<Map<String, dynamic>> _toolExecutionLogs = [];
  Map<String, int> _blockedReasonBreakdown = {};
  int _actualUserCount = 0;
  int _lpTodayViews = 0;
  int _lpTotalViews = 0;
  int _allowedToolExecutionCount = 0;
  int _blockedToolExecutionCount = 0;
  bool _hasLpViewStats = false;
  bool _isLoading = true;
  late final SupabaseClient _supabase;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return false;
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

  _FunnelMetrics _extractFunnelMetrics(Map<String, int> sources) {
    return _FunnelMetrics(
      trialRuns: sources['funnel_trial_run'] ?? 0,
      saveClicks: sources['funnel_save_cta'] ?? 0,
      magicLinkSends: sources['funnel_magic_link_send'] ?? 0,
      inboxOpens: sources['funnel_inbox_open'] ?? 0,
    );
  }

  Map<String, int> _extractSourceCounts(dynamic rawSourceDetails) {
    final counts = <String, int>{};
    _mergeSourceCounts(counts, rawSourceDetails);
    return counts;
  }

  String _formatRate(int numerator, int denominator) {
    if (denominator <= 0) {
      return '--';
    }
    return '${(numerator / denominator * 100).toStringAsFixed(1)}%';
  }

  int _estimateNeededMagicLinks({
    required int remainingRegistrations,
    required int todayRegistrations,
    required int todayMagicLinkSends,
  }) {
    if (remainingRegistrations <= 0) {
      return 0;
    }
    if (todayRegistrations <= 0 || todayMagicLinkSends <= 0) {
      return remainingRegistrations;
    }

    final completionRate = todayRegistrations / todayMagicLinkSends;
    if (completionRate <= 0) {
      return remainingRegistrations;
    }
    return (remainingRegistrations / completionRate).ceil();
  }

  int _countConsecutiveNoRegistrationDays(List<Map<String, dynamic>> stats) {
    var streak = 0;
    for (final stat in stats) {
      if (_toInt(stat['conversions']) > 0) {
        break;
      }
      streak += 1;
    }
    return streak;
  }

  double _averageViews(List<Map<String, dynamic>> stats, {int days = 7}) {
    final window = stats.take(days).toList();
    if (window.isEmpty) {
      return 0;
    }
    final total = window.fold<int>(
      0,
      (sum, stat) => sum + _toInt(stat['landing_views']),
    );
    return total / window.length;
  }

  _GrowthActionPlan _buildGrowthActionPlan({
    required bool achieved,
    required int todayViews,
    required int todayRegistrations,
    required _FunnelMetrics todayFunnel,
    required String? priorityChannelKey,
    required String? priorityChannelLabel,
  }) {
    if (achieved) {
      return const _GrowthActionPlan(
        bottleneckLabel: '達成済み',
        title: '',
        detail: '',
        icon: Icons.check_circle,
        buttonLabel: '',
        isAcquisitionAction: false,
      );
    }

    if (todayViews == 0) {
      return _GrowthActionPlan(
        bottleneckLabel: '流入不足',
        title: '今やる流入改善アクション',
        detail:
            '${priorityChannelLabel ?? 'X (Twitter)'}を最優先チャネルにして、共有・投稿・再配布のいずれか1件だけ先に実行してください。',
        icon: Icons.campaign,
        buttonLabel: _buildAcquisitionButtonLabel(
          priorityChannelKey,
          priorityChannelLabel,
        ),
        isAcquisitionAction: true,
      );
    }

    if (todayFunnel.trialRuns == 0) {
      return const _GrowthActionPlan(
        bottleneckLabel: '体験未実行',
        title: '今やる単独改善アクション',
        detail:
            '流入はありますが無料体験の開始が0件です。ファーストビューのCTAを体験直行に寄せ、最初の1画面で得られる結果を明示してください。',
        icon: Icons.play_circle_outline,
        buttonLabel: 'AI改善で体験導線改善',
        isAcquisitionAction: false,
      );
    }

    if (todayFunnel.saveClicks == 0) {
      return const _GrowthActionPlan(
        bottleneckLabel: '保存未押下',
        title: '今やる単独改善アクション',
        detail:
            '体験は実行されていますが保存CTAが押されていません。結果直下の保存メリットを1行で伝え、ボタン文言を保存ベースに揃えてください。',
        icon: Icons.save_alt,
        buttonLabel: 'AI改善で保存訴求改善',
        isAcquisitionAction: false,
      );
    }

    if (todayFunnel.magicLinkSends == 0) {
      return const _GrowthActionPlan(
        bottleneckLabel: '送信未実施',
        title: '今やる単独改善アクション',
        detail:
            '保存CTAまでは到達していますがMagic Link送信が0件です。メール入力前で「保存すると何が残るか」を再提示し、入力負荷を下げてください。',
        icon: Icons.mail_outline,
        buttonLabel: 'AI改善で認証導線改善',
        isAcquisitionAction: false,
      );
    }

    if (todayFunnel.inboxOpens == 0) {
      return const _GrowthActionPlan(
        bottleneckLabel: '受信箱未確認',
        title: '今やる単独改善アクション',
        detail:
            'Magic Link送信後の受信箱オープンが0件です。送信完了メッセージと「メールを開く」導線をより強く目立たせてください。',
        icon: Icons.mark_email_read_outlined,
        buttonLabel: 'AI改善で受信箱誘導改善',
        isAcquisitionAction: false,
      );
    }

    if (todayRegistrations == 0) {
      return const _GrowthActionPlan(
        bottleneckLabel: '登録完了待ち',
        title: '今やる単独改善アクション',
        detail: '送信までは進んでいますが登録完了が出ていません。メール本文、迷惑メール案内、再送導線を見直して完了率を上げてください。',
        icon: Icons.checklist_rtl,
        buttonLabel: 'AI改善で完了率改善',
        isAcquisitionAction: false,
      );
    }

    return const _GrowthActionPlan(
      bottleneckLabel: '導線再点検',
      title: '今やる単独改善アクション',
      detail: '登録完了までの流れを見直し、最も弱い導線を1つだけ改善してください。',
      icon: Icons.alt_route,
      buttonLabel: 'AI改善で導線改善',
      isAcquisitionAction: false,
    );
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

      final toolExecutionLogs = <Map<String, dynamic>>[];
      final blockedReasonCounts = <String, int>{};
      var allowedExecutionCount = 0;
      var blockedExecutionCount = 0;

      try {
        final dynamic rawToolLogs = await _supabase
            .from('agent_tool_execution_logs')
            .select('tool_name, allowed, blocked_reason, created_at')
            .order('created_at', ascending: false)
            .limit(80);

        if (rawToolLogs is List) {
          for (final row in rawToolLogs.whereType<Map>()) {
            final log = Map<String, dynamic>.from(row);
            final allowed = _toBool(log['allowed']);
            if (allowed) {
              allowedExecutionCount += 1;
            } else {
              blockedExecutionCount += 1;
              final rawReason = log['blocked_reason']?.toString().trim() ?? '';
              final reason =
                  rawReason.isEmpty ? 'Unknown blocked reason' : rawReason;
              blockedReasonCounts.update(
                reason,
                (current) => current + 1,
                ifAbsent: () => 1,
              );
            }
            toolExecutionLogs.add(log);
          }
        }
      } catch (error) {
        debugPrint('agent_tool_execution_logs is unavailable: $error');
      }

      final sortedBlockedReasons = blockedReasonCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final normalizedBlockedReasons = <String, int>{
        for (final entry in sortedBlockedReasons) entry.key: entry.value,
      };

      if (mounted) {
        setState(() {
          _dailyStats = mergedDailyStats;
          _actualUserCount = totalUsers;
          _lpTodayViews = _toInt(lpStats['today']);
          _lpTotalViews = _toInt(lpStats['total']);
          _hasLpViewStats = hasLpViewStats;
          _toolExecutionLogs = toolExecutionLogs;
          _blockedReasonBreakdown = normalizedBlockedReasons;
          _allowedToolExecutionCount = allowedExecutionCount;
          _blockedToolExecutionCount = blockedExecutionCount;
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
    final Map<String, int> funnelBreakdown = {};
    final Map<String, int> todaySourceDetails = {};
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
            if (statDateKey == todayKey) {
              todaySourceDetails[sourceKey] =
                  (todaySourceDetails[sourceKey] ?? 0) + count;
            }
            final target = _isFunnelEventKey(sourceKey)
                ? funnelBreakdown
                : _isShareActionKey(sourceKey)
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
    final todayFunnel = _extractFunnelMetrics(todaySourceDetails);
    final totalFunnel = _extractFunnelMetrics(funnelBreakdown);
    final total30DayRegistrations = _dailyStats.fold<int>(
      0,
      (sum, stat) => sum + _toInt(stat['conversions']),
    );
    final todayDropBeforeTrial = effectiveTodayViews > todayFunnel.trialRuns
        ? effectiveTodayViews - todayFunnel.trialRuns
        : 0;
    final totalDropBeforeTrial = effectiveTotalLpViews > totalFunnel.trialRuns
        ? effectiveTotalLpViews - totalFunnel.trialRuns
        : 0;
    final zeroRegistrationStreakDays =
        _countConsecutiveNoRegistrationDays(_dailyStats);
    final averageViewsLast7Days = _averageViews(_dailyStats);

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
                      todayFunnel: todayFunnel,
                    ),
                    const SizedBox(height: 16),
                    _buildFunnelOverviewCard(
                      title: '今日の登録ファネル',
                      lpViews: effectiveTodayViews,
                      registrations: todayRegistrations,
                      funnel: todayFunnel,
                      remainingRegistrations:
                          todayRegistrations >= 1 ? 0 : 1 - todayRegistrations,
                    ),
                    const SizedBox(height: 16),
                    _buildKpiSummaryCard(
                      todaySummaryCvr,
                      effectiveTodayViews,
                      todayRegistrations,
                      _actualUserCount,
                      totalShares,
                      effectiveTotalLpViews,
                      todayFunnel,
                    ),
                    const SizedBox(height: 16),
                    _buildRegistrationOpsCard(
                      todayDropBeforeTrial: todayDropBeforeTrial,
                      totalDropBeforeTrial: totalDropBeforeTrial,
                      zeroRegistrationStreakDays: zeroRegistrationStreakDays,
                      averageViewsLast7Days: averageViewsLast7Days,
                      totalTrialRate: _formatRate(
                        totalFunnel.trialRuns,
                        effectiveTotalLpViews,
                      ),
                      registrationsPerLpView: total30DayRegistrations > 0
                          ? (effectiveTotalLpViews / total30DayRegistrations)
                              .toStringAsFixed(1)
                          : null,
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
                    _buildFunnelOverviewCard(
                      title: '過去30日の登録ファネル',
                      lpViews: effectiveTotalLpViews,
                      registrations: total30DayRegistrations,
                      funnel: totalFunnel,
                      remainingRegistrations: 0,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Agent Tool Guard (Fail-close)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildToolExecutionGuardCard(),
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
    required _FunnelMetrics todayFunnel,
  }) {
    const dailyTarget = 1;
    final achieved = todayRegistrations >= dailyTarget;
    final remaining = achieved ? 0 : dailyTarget - todayRegistrations;
    final progress = (todayRegistrations / dailyTarget).clamp(0.0, 1.0);
    final priorityChannelKey = achieved || todayViews > 0
        ? null
        : _resolvePriorityAcquisitionChannel(sourceBreakdown);
    final priorityChannelLabel = priorityChannelKey == null
        ? null
        : _formatSourceName(priorityChannelKey);
    final growthAction = _buildGrowthActionPlan(
      achieved: achieved,
      todayViews: todayViews,
      todayRegistrations: todayRegistrations,
      todayFunnel: todayFunnel,
      priorityChannelKey: priorityChannelKey,
      priorityChannelLabel: priorityChannelLabel,
    );
    final accentColor = achieved ? Colors.green : Colors.redAccent;
    final todayCvr =
        todayViews == 0 ? 0.0 : (todayRegistrations / todayViews * 100);
    final diagnosisLabel = achieved
        ? '登録発生'
        : todayViews == 0
            ? '流入不足'
            : growthAction.bottleneckLabel;
    final diagnosisColor = achieved
        ? Colors.green
        : todayViews == 0
            ? Colors.orange
            : todayFunnel.trialRuns == 0
                ? Colors.cyan
                : todayFunnel.saveClicks == 0
                    ? Colors.indigo
                    : todayFunnel.magicLinkSends == 0
                        ? Colors.deepOrange
                        : todayFunnel.inboxOpens == 0
                            ? Colors.amber.shade800
                            : Colors.redAccent;
    final actionTitle = achieved ? null : growthAction.title;
    final actionDetail = achieved ? null : growthAction.detail;
    final actionIcon = achieved ? null : growthAction.icon;
    final actionButtonLabel = achieved ? null : growthAction.buttonLabel;
    final statusText = achieved
        ? '今日の登録目標は達成済みです。次は流入改善で上振れを狙う。'
        : todayViews == 0
            ? '今日の流入がありません。まずは露出導線を1つ増やして、訪問者を作ってください。'
            : todayFunnel.trialRuns == 0
                ? '流れ込みはありますが、無料体験がまだ1回も実行されていません。最初の一手を試したくなる導線を最優先で短くしてください。'
                : todayFunnel.saveClicks == 0
                    ? '無料体験の実行はありますが、保存CTAが押されていません。体験直後に「保存すると残る価値」を再提示する必要があります。'
                    : todayFunnel.magicLinkSends == 0
                        ? '保存CTAまでは到達していますが、Magic Link送信が0件です。メール入力前の不安を減らす必要があります。'
                        : todayFunnel.inboxOpens == 0
                            ? 'Magic Link送信はありますが、受信箱が開かれていません。送信後の次の行動をさらに明確にしてください。'
                            : '流れ込みはありますが登録が出ていません。登録完了直前での離脱が発生しています。';

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
              if (todayViews > 0)
                _buildMiniKpiChip(
                  label: '今日体験',
                  value: '${todayFunnel.trialRuns}',
                  color: Colors.cyan,
                ),
              if (todayViews > 0)
                _buildMiniKpiChip(
                  label: '今日送信',
                  value: '${todayFunnel.magicLinkSends}',
                  color: Colors.deepOrange,
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
                              isAcquisitionAction:
                                  growthAction.isAcquisitionAction,
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

  Widget _buildFunnelOverviewCard({
    required String title,
    required int lpViews,
    required int registrations,
    required _FunnelMetrics funnel,
    required int remainingRegistrations,
  }) {
    final neededMagicLinks = _estimateNeededMagicLinks(
      remainingRegistrations: remainingRegistrations,
      todayRegistrations: registrations,
      todayMagicLinkSends: funnel.magicLinkSends,
    );
    final funnelAction = _buildGrowthActionPlan(
      achieved: remainingRegistrations <= 0,
      todayViews: lpViews,
      todayRegistrations: registrations,
      todayFunnel: funnel,
      priorityChannelKey: null,
      priorityChannelLabel: null,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'LP流入後の途中離脱を切り分けるためのファネルです。どこで止まっているかを先に確認します。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildFunnelStepItem(
                  label: 'LP View',
                  value: '$lpViews',
                  icon: Icons.visibility,
                  color: Colors.blue,
                ),
                _buildFunnelStepItem(
                  label: '体験実行',
                  value: '${funnel.trialRuns}',
                  icon: Icons.play_circle_outline,
                  color: Colors.cyan,
                ),
                _buildFunnelStepItem(
                  label: '保存CTA',
                  value: '${funnel.saveClicks}',
                  icon: Icons.save_outlined,
                  color: Colors.indigo,
                ),
                _buildFunnelStepItem(
                  label: 'Magic Link送信',
                  value: '${funnel.magicLinkSends}',
                  icon: Icons.mail_outline,
                  color: Colors.deepPurple,
                ),
                _buildFunnelStepItem(
                  label: '受信箱を開く',
                  value: '${funnel.inboxOpens}',
                  icon: Icons.mark_email_read_outlined,
                  color: Colors.orange,
                ),
                _buildFunnelStepItem(
                  label: '実登録',
                  value: '$registrations',
                  icon: Icons.person_add,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniKpiChip(
                  label: 'LP→体験率',
                  value: _formatRate(funnel.trialRuns, lpViews),
                  color: Colors.cyan,
                ),
                _buildMiniKpiChip(
                  label: '体験→保存率',
                  value: _formatRate(funnel.saveClicks, funnel.trialRuns),
                  color: Colors.indigo,
                ),
                _buildMiniKpiChip(
                  label: '保存→送信率',
                  value: _formatRate(funnel.magicLinkSends, funnel.saveClicks),
                  color: Colors.deepPurple,
                ),
                _buildMiniKpiChip(
                  label: '送信→登録率',
                  value: _formatRate(registrations, funnel.magicLinkSends),
                  color: Colors.green,
                ),
                if (remainingRegistrations > 0)
                  _buildMiniKpiChip(
                    label: '最大ボトルネック',
                    value: funnelAction.bottleneckLabel,
                    color: Colors.blueGrey,
                  ),
                if (remainingRegistrations > 0)
                  _buildMiniKpiChip(
                    label: '目標達成に必要な送信',
                    value: '$neededMagicLinks件',
                    color: Colors.redAccent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunnelStepItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryCard(
    double cvr,
    int todayViews,
    int todayRegistrations,
    int totalRegistrations,
    int shares,
    int totalLpViews,
    _FunnelMetrics todayFunnel,
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
                  '今日体験',
                  '${todayFunnel.trialRuns}',
                  Icons.play_circle_outline,
                  Colors.cyan,
                ),
                _buildStatItem(
                  '今日Magic Link送信',
                  '${todayFunnel.magicLinkSends}',
                  Icons.mail_outline,
                  Colors.deepPurple,
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

  Widget _buildRegistrationOpsCard({
    required int todayDropBeforeTrial,
    required int totalDropBeforeTrial,
    required int zeroRegistrationStreakDays,
    required double averageViewsLast7Days,
    required String totalTrialRate,
    required String? registrationsPerLpView,
  }) {
    final alertText = zeroRegistrationStreakDays >= 3
        ? '登録ゼロが$zeroRegistrationStreakDays日連続です。流入ではなく、体験開始と認証前の離脱を最優先で潰してください。'
        : todayDropBeforeTrial > 0
            ? '今日は流入がありますが、体験前に$todayDropBeforeTrial件が離脱しています。無料体験の訴求を最優先で確認してください。'
            : '直近の登録導線は動いています。次は送信後の完了率を維持できているかを確認してください。';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '登録管理の追加指標',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'LP View以外に、体験前離脱・継続未達・直近流量をまとめて確認します。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniKpiChip(
                  label: '今日の体験前離脱',
                  value: '$todayDropBeforeTrial',
                  color: Colors.cyan,
                ),
                _buildMiniKpiChip(
                  label: '30日体験前離脱',
                  value: '$totalDropBeforeTrial',
                  color: Colors.blueGrey,
                ),
                _buildMiniKpiChip(
                  label: '連続登録ゼロ日',
                  value: '$zeroRegistrationStreakDays日',
                  color: Colors.redAccent,
                ),
                _buildMiniKpiChip(
                  label: '直近7日平均LP',
                  value: averageViewsLast7Days.toStringAsFixed(1),
                  color: Colors.blue,
                ),
                _buildMiniKpiChip(
                  label: '30日体験率',
                  value: totalTrialRate,
                  color: Colors.teal,
                ),
                _buildMiniKpiChip(
                  label: '直近登録効率',
                  value: registrationsPerLpView == null
                      ? '登録未発生'
                      : '$registrationsPerLpView LP/登録',
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                alertText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolExecutionGuardCard() {
    if (_toolExecutionLogs.isEmpty) {
      return const Card(
        elevation: 1,
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'agent_tool_execution_logs のデータがありません。マイグレーション適用後に表示されます。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      );
    }

    final totalExecutions =
        _allowedToolExecutionCount + _blockedToolExecutionCount;
    final blockedRate = totalExecutions == 0
        ? 0.0
        : (_blockedToolExecutionCount / totalExecutions * 100);
    final recentLogs = _toolExecutionLogs.take(12).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniKpiChip(
                  label: 'Allowed',
                  value: '$_allowedToolExecutionCount',
                  color: Colors.green,
                ),
                _buildMiniKpiChip(
                  label: 'Blocked',
                  value: '$_blockedToolExecutionCount',
                  color: Colors.redAccent,
                ),
                _buildMiniKpiChip(
                  label: 'Blocked Rate',
                  value: '${blockedRate.toStringAsFixed(1)}%',
                  color: Colors.deepOrange,
                ),
              ],
            ),
            if (_blockedReasonBreakdown.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Blocked Reasons',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ..._blockedReasonBreakdown.entries.take(6).map((entry) {
                final ratio = _blockedToolExecutionCount == 0
                    ? 0.0
                    : (entry.value / _blockedToolExecutionCount)
                        .clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: ratio,
                          backgroundColor: Colors.redAccent.withValues(
                            alpha: 0.08,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            const Text(
              'Recent Tool Executions',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...recentLogs.map((log) {
              final allowed = _toBool(log['allowed']);
              final rawReason = log['blocked_reason']?.toString().trim() ?? '';
              final reasonText =
                  rawReason.isEmpty ? 'No block reason' : rawReason;
              final toolName = _formatToolName(log['tool_name']?.toString());
              final createdAt = _formatTimestamp(log['created_at']);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: allowed
                      ? Colors.green.withValues(alpha: 0.05)
                      : Colors.redAccent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allowed
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.redAccent.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          allowed ? Icons.check_circle : Icons.block,
                          size: 16,
                          color: allowed ? Colors.green : Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            toolName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          createdAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    if (!allowed) ...[
                      const SizedBox(height: 6),
                      Text(
                        reasonText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatToolName(String? raw) {
    switch (raw) {
      case 'delegate_task':
        return 'delegate_task';
      case 'process_task':
        return 'process_task';
      case 'update_task_status':
        return 'update_task_status';
      case 'send_message':
        return 'send_message';
      case 'append_memory':
        return 'append_memory';
      case 'set_agent_status':
        return 'set_agent_status';
      case 'run_heartbeat':
        return 'run_heartbeat';
      case 'run_nightly_consolidation':
        return 'run_nightly_consolidation';
      case 'run_forgetting':
        return 'run_forgetting';
      case 'run_runtime_cycle':
        return 'run_runtime_cycle';
      default:
        return raw == null || raw.trim().isEmpty ? 'unknown_tool' : raw;
    }
  }

  String _formatTimestamp(dynamic rawValue) {
    if (rawValue == null) {
      return '--';
    }
    final parsed = DateTime.tryParse(rawValue.toString())?.toLocal();
    if (parsed == null) {
      return '--';
    }
    return DateFormat('MM/dd HH:mm:ss').format(parsed);
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

  bool _isFunnelEventKey(String key) {
    switch (key) {
      case 'funnel_trial_run':
      case 'funnel_save_cta':
      case 'funnel_magic_link_send':
      case 'funnel_inbox_open':
        return true;
      default:
        return false;
    }
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
        final dayFunnel = _extractFunnelMetrics(
          _extractSourceCounts(stat['source_details']),
        );

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
            subtitle: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _miniStat(Icons.visibility, '$views', Colors.blue),
                _miniStat(
                  Icons.play_circle_outline,
                  '${dayFunnel.trialRuns}',
                  Colors.cyan,
                ),
                _miniStat(
                  Icons.mail_outline,
                  '${dayFunnel.magicLinkSends}',
                  Colors.deepPurple,
                ),
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
