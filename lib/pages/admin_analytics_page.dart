import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/admin_growth_evidence.dart';
import '../services/growth_mission_service.dart';
import '../widgets/admin_billing_overview.dart';
import '../widgets/admin_growth_evidence_section.dart';
import '../widgets/admin_registration_funnel_card.dart';
import '../widgets/admin_registration_ops_card.dart';
import '../widgets/admin_tool_execution_guard_card.dart';
import '../widgets/admin_today_registration_goal_card.dart';
import '../widgets/structured_field_chips.dart';
import '../widgets/schedule_task_monitor_card.dart';
import '../widgets/competitor_monitoring_card.dart';
import '../widgets/self_devin_control_tower_card.dart';
import 'admin_x_posted_today.dart';
import 'admin_dashboard_signals.dart';
import 'admin_x_candidate_queue.dart';
import 'ai_secretary_page.dart';
import 'admin/feedback_list_page.dart';
import 'admin/quota_dashboard_page.dart';
import 'admin/blog_management_page.dart';
import 'cmo_page.dart';
import 'note_list_page.dart';
import 'voice_ai_governance_page.dart';

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
  // R16: 非 null のとき、ボタンはページ遷移ではなくこの URL を外部起動する
  // (投稿を開く / console.x.com で上限確認 等)。
  final String? launchUrl;

  const _GrowthActionPlan({
    required this.bottleneckLabel,
    required this.title,
    required this.detail,
    required this.icon,
    required this.buttonLabel,
    required this.isAcquisitionAction,
    this.launchUrl,
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
  AdminPaidConversionMetrics _paidConversionMetrics =
      AdminPaidConversionMetrics.empty;
  bool _hasLpViewStats = false;
  // R16: growth-hub x.today_status の結果(今日すでに投稿したか / 最新tweet+初速
  // インプレ / spend-cap ブロック中か)。取得失敗や available:false のときは null
  // に戻し、アクションカードは従来文言(「X投稿を作る」)へ degrade する。
  Map<String, dynamic>? _xTodayStatus;
  // R17: growth-hub x.performance_context の結果(計測済み投稿の variant ランキング
  // / 勝ち型 / winner exemplar)。X 学習ループを意思決定点(ダッシュボード)に露出
  // する。取得失敗時は null → 成長ループ panel は非表示に degrade。
  Map<String, dynamic>? _xPerformanceContext;
  // R26: X投稿候補キュー(HITL 承認待ち)。トラッカー系列の cron が生成した
  // pending_approval 候補をここで承認→投稿する(UUID 手掘り+workflow dispatch
  // の運用ボトルネック解消)。X operator 権限が無い/取得失敗は空=panel 非表示。
  List<XPostCandidateSummary> _xCandidates = const [];
  // R34: edge の total (limit 前の総数) を status 別に保持。空なら「N件以上」表示。
  Map<String, int> _xCandidateTotals = const <String, int>{};
  final Set<String> _xCandidatePublishing = <String>{};
  // #4080: 鮮度切れ一括却下の実行中フラグ (二重送信防止)。
  bool _xCandidateRejecting = false;
  bool _isLoading = true;
  WeeklyDigestSnapshot _weeklyDigest = const WeeklyDigestSnapshot.empty();
  // R18: fetch 完了フラグ。empty() のままか、完了して空かを区別し、静かに失敗/空の
  // 週を無限「読み込み中」ではなく正直な「計測待ち」に落とす。
  bool _weeklyDigestLoaded = false;
  late final SupabaseClient _supabase;
  final _growthService = const GrowthMissionService();
  List<Map<String, dynamic>> _featureRequests = [];
  List<Map<String, dynamic>> _waitlistEmails = [];
  List<Map<String, dynamic>> _adminUsers = [];
  List<Map<String, dynamic>> _automationSupportTickets = [];
  int _adminUsersTotal = 0;
  bool _featureRequestsLoading = false;
  bool _waitlistLoading = false;
  bool _sendingNotification = false;
  bool _adminUsersLoading = false;

  List<Map<String, dynamic>> _appFeedbacks = [];
  bool _appFeedbacksLoading = false;
  bool _automationLoading = false;
  bool _automationPostingX = false;
  Map<String, dynamic>? _automationDigest;
  String? _automationError;

  // admin user search
  String _userSearchQuery = '';

  // growth-achievement-summary
  Map<String, dynamic>? _growthSummary;
  bool _growthSummaryLoading = false;

  // comparison CVR tracking
  Map<String, int> _comparisonTouches = {};
  int _comparisonSignups = 0;
  bool _comparisonCvrLoading = false;

  // R29: 自動エラー報告 (error_reporter が hub_data へ無言送信する caught error)
  // の可視化。管理者自身の直近報告を admin-hub errors.recent で取得する。
  List<AutoErrorReportEntry> _autoErrorReports = const [];
  bool _autoErrorReportsLoading = false;

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

  AdminBillingFunnelMetrics _extractBillingFunnelMetrics(
    Map<String, int> sources,
  ) {
    return AdminBillingFunnelMetrics(
      billingViews: sources['funnel_billing_view'] ?? 0,
      upgradeClicks: sources['funnel_upgrade_click'] ?? 0,
      checkoutSuccesses: sources['funnel_checkout_success'] ?? 0,
      checkoutCancels: sources['funnel_checkout_cancel'] ?? 0,
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

  Map<String, dynamic> _firstMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return <String, dynamic>{};
  }

  AdminPaidConversionMetrics _paidConversionMetricsFromRpc(dynamic value) {
    final row = _firstMap(value);
    if (row.isEmpty) {
      return AdminPaidConversionMetrics.empty;
    }

    return AdminPaidConversionMetrics(
      paidCustomers: _toInt(row['paid_customers']),
      mrrYen: _toInt(row['mrr_yen']),
    );
  }

  Future<AdminPaidConversionMetrics> _loadPaidConversionMetrics() async {
    try {
      final response = await _supabase.rpc(
        'get_billing_paid_conversion_summary',
      );
      return _paidConversionMetricsFromRpc(response);
    } catch (error) {
      debugPrint('billing paid conversion summary is unavailable: $error');
      return AdminPaidConversionMetrics.empty;
    }
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

  /// R16: growth-hub x.today_status を fail-safe に取得する。今日境界はブラウザ
  /// ローカル深夜を UTC ISO(絶対時刻)で渡す(サーバは epoch 比較する)。
  /// 例外・available!=true のときは null を返し、アクションカードは従来動作へ degrade。
  Future<Map<String, dynamic>?> _loadXTodayStatus() async {
    try {
      final startOfDayIso = _startOfDay(
        DateTime.now(),
      ).toUtc().toIso8601String();
      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'x.today_status',
          'startOfDayIso': startOfDayIso,
          'tz': 'Asia/Tokyo',
        },
      );
      final data = res.data;
      if (data is Map && data['available'] == true) {
        return Map<String, dynamic>.from(data);
      }
    } catch (error) {
      debugPrint('x.today_status unavailable: $error');
    }
    return null;
  }

  /// R17: growth-hub x.performance_context を fail-safe に取得する。edge 側に
  /// server-side try/catch が無いため、ここで必ず握りつぶして null に degrade
  /// する(取得失敗で成長ループ panel を消すだけ・ダッシュボードは必ず描画する)。
  Future<Map<String, dynamic>?> _loadXPerformanceContext() async {
    try {
      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {'action': 'x.performance_context', 'limit': 50},
      );
      final data = res.data;
      if (data is Map && data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }
    } catch (error) {
      debugPrint('x.performance_context unavailable: $error');
    }
    return null;
  }

  /// R26: X投稿候補キューを fail-safe に取得する。操作可能な3状態(承認待ち/
  /// 承認済み・投稿未完/投稿失敗)を **status 別クエリ**で取り統合する —
  /// status 無指定の単一クエリだと finalized 行(posted 等)が created_at 降順
  /// window を埋め、古い承認待ちを黙って押し出す(レビュー F2)。
  /// X operator 権限が無いと edge が 403 を返すため、例外/非成功は空リストに
  /// degrade して panel ごと消す(ダッシュボードは必ず描画する)。
  Future<XCandidateQueueSnapshot> _loadXCandidateQueue() async {
    const statuses = ['pending_approval', 'approved', 'publish_failed'];
    // #4080: statuses[] を渡して 1 往復にまとめる (従来は status ごとに 3 往復
    // + それぞれに CORS preflight)。edge 側は per-status limit を維持するので
    // 上記 F2 の窓圧迫は起きない。
    final byStatus = <String, XCandidateStatusPage>{};
    try {
      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'x.candidate.list',
          'statuses': statuses,
          // R32: ヘッダの「N件以上」判定と同じ定数を使う (両者が drift すると
          // 上限到達を検出できず backlog を過小表示する)。
          'limit': kXCandidateStatusFetchLimit,
        },
      );
      final data = res.data;
      if (data is Map && data['success'] == true && data['byStatus'] is Map) {
        final raw = Map<String, dynamic>.from(data['byStatus'] as Map);
        for (final status in statuses) {
          final entry = raw[status];
          if (entry is Map) {
            // R34: edge の total (limit 前の総数) を拾う。返さない場合は null の
            // まま = ヘッダは「N件以上」へ degrade。
            final rawTotal = entry['total'];
            byStatus[status] = XCandidateStatusPage(
              candidates: parseXPostCandidates(entry['candidates']),
              total: rawTotal is num ? rawTotal.toInt() : null,
            );
          }
        }
      }
    } catch (error) {
      debugPrint('x.candidate.list(batch) unavailable: $error');
    }
    final totals = <String, int>{
      for (final entry in byStatus.entries)
        if (entry.value.total != null) entry.key: entry.value.total!,
    };
    return XCandidateQueueSnapshot(
      candidates: mergeCandidateSummaries([
        for (final status in statuses)
          byStatus[status]?.candidates ?? const <XPostCandidateSummary>[],
      ]),
      totalsByStatus: totals,
    );
  }

  /// #4080: 鮮度切れ候補をまとめて却下する。鮮度切れは「承認して投稿」が
  /// 既に無効化されている(古いニュースの誤公開防止)ため、そのままだと
  /// キューに残り続けて本当に見るべき候補を埋没させる。終端 status
  /// 'rejected' へ落として一覧から外す。
  Future<void> _rejectStaleXCandidates(
    List<XPostCandidateSummary> staleCandidates,
  ) async {
    if (staleCandidates.isEmpty || _xCandidateRejecting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('鮮度切れ候補をまとめて却下'),
        content: Text(
          '${staleCandidates.length}件を却下します。'
          '却下した候補は投稿できなくなります(一覧からは消えます)。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('却下する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _xCandidateRejecting = true);
    try {
      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'x.candidate.reject',
          'candidateIds': staleCandidates.map((c) => c.id).toList(),
          'reason': 'freshness_expired',
        },
      );
      final data = res.data;
      final rejected = data is Map && data['rejected'] is List
          ? (data['rejected'] as List).length
          : 0;
      final failures = data is Map && data['failures'] is List
          ? (data['failures'] as List).length
          : 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failures > 0
                ? '$rejected件を却下しました($failures件は失敗)'
                : '$rejected件を却下しました',
          ),
        ),
      );
      final refreshed = await _loadXCandidateQueue();
      if (mounted) {
        setState(() {
          _xCandidates = refreshed.candidates;
          _xCandidateTotals = refreshed.totalsByStatus;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('却下に失敗しました: $error')));
    } finally {
      if (mounted) setState(() => _xCandidateRejecting = false);
    }
  }

  /// R26: 候補を承認→投稿→確定する HITL フロー。無審査自動投稿はしない
  /// (必ず全文確認ダイアログを挟む)。approve が返す postPayload は edge 側で
  /// whitelist 済みの「人間がレビューした本文そのもの」で、それ以外を送らない。
  Future<void> _publishXCandidate(XPostCandidateSummary candidate) async {
    if (_xCandidatePublishing.contains(candidate.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('候補を承認してXへ投稿: ${candidate.seriesLabel}'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'リード全${candidate.text.length}字'
                '${candidate.replyCount > 0 ? ' + リプライ${candidate.replyCount}件(下に全文)' : ''}'
                'を実投稿します(取り消し不可)。',
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  // リード+全リプライ本文。承認者が見ていない文字列は 1 文字も
                  // 投稿されない(レビュー F0: 件数表示のみだとスレッド本文が
                  // 未レビューのまま公開される)。
                  child: Text(
                    candidateFullReviewText(candidate),
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('承認して投稿する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _xCandidatePublishing.add(candidate.id));
    try {
      // approve 段は独立に捕捉する: edge は承認失敗を全て非2xx(404/409 等)で
      // 返し functions_client は非2xx で throw するため、外側 catch に落とすと
      // 「投稿処理でエラー」と誤誘導になる(レビュー F1: この段では何も投稿
      // されていない)。
      Map<String, dynamic> approveData;
      try {
        final approveRes = await _supabase.functions.invoke(
          'growth-hub',
          body: {'action': 'x.candidate.approve', 'candidateId': candidate.id},
        );
        approveData = approveRes.data is Map
            ? Map<String, dynamic>.from(approveRes.data as Map)
            : <String, dynamic>{};
      } catch (approveError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('承認に失敗しました(投稿は行われていません): $approveError')),
        );
        return;
      }
      if (approveData['success'] != true ||
          approveData['postPayload'] is! Map) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('承認に失敗しました: ${approveData['error'] ?? '不明なエラー'}'),
          ),
        );
        return;
      }
      final postPayload = Map<String, dynamic>.from(
        approveData['postPayload'] as Map,
      );
      final postRes = await _supabase.functions.invoke(
        'growth-hub',
        body: postPayload,
      );
      final postData = postRes.data is Map
          ? Map<String, dynamic>.from(postRes.data as Map)
          : <String, dynamic>{};
      // 投稿結果を候補へ確定記録(posted / rejected_duplicate / publish_failed)。
      // finalize 自体の失敗は投稿結果の通知を妨げない(ログのみ)。
      try {
        await _supabase.functions.invoke(
          'growth-hub',
          body: {
            'action': 'x.candidate.finalize',
            'candidateId': candidate.id,
            'result': buildCandidateFinalizeResult(postData),
          },
        );
      } catch (finalizeError) {
        debugPrint('x.candidate.finalize failed: $finalizeError');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(candidatePublishOutcomeMessage(postData))),
      );
      final refreshed = await _loadXCandidateQueue();
      if (mounted) {
        setState(() {
          _xCandidates = refreshed.candidates;
          _xCandidateTotals = refreshed.totalsByStatus;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('候補の投稿処理でエラー: $error')));
    } finally {
      if (mounted) {
        setState(() => _xCandidatePublishing.remove(candidate.id));
      }
    }
  }

  /// R16: 今日すでに X 投稿済みなら「投稿を作れ」ではなく、投稿直後30分は
  /// ゴールデンアワー(手動リプ/poll確認)、以降は計測待ち、spend-cap 中は上限
  /// 確認案内へ切り替える。今日未投稿(または status 未取得)なら null を返し、
  /// 呼び出し側の従来ロジック(流入不足→X投稿を作る)へフォールバックする。
  _GrowthActionPlan? _buildPostedTodayActionPlan() {
    final status = _xTodayStatus;
    if (status == null) return null;
    final cta = adminXPostedTodayCta(status, DateTime.now());

    switch (cta) {
      case AdminXPostedTodayCta.none:
        return null;
      case AdminXPostedTodayCta.blocked:
        final resetAt = status['resetAt']?.toString();
        final resetNote = resetAt != null && resetAt.isNotEmpty
            ? '（$resetAt に自動リセット見込み）'
            : '';
        return _GrowthActionPlan(
          bottleneckLabel: 'X API上限',
          title: 'X APIの支出上限に到達中',
          detail: 'console.x.com の「支出上限を管理」で引き上げると即時解除されます$resetNote。'
              '解除まで自動投稿はスキップされます。再投稿の前に上限を確認してください。',
          icon: Icons.credit_card_off,
          buttonLabel: 'console.x.com で上限を確認',
          isAcquisitionAction: false,
          launchUrl: 'https://console.x.com/',
        );
      case AdminXPostedTodayCta.goldenHour:
      case AdminXPostedTodayCta.measuring:
        final postedCount = _toInt(status['postedTodayCount']);
        final impressions = status['latestImpressions'];
        final imprText = impressions == null ? '計測待ち' : 'インプレ $impressions';
        final tweetId = status['lastTweetId']?.toString();
        final tweetUrl = tweetId != null && tweetId.isNotEmpty
            ? 'https://x.com/i/web/status/$tweetId'
            : null;
        if (cta == AdminXPostedTodayCta.goldenHour) {
          return _GrowthActionPlan(
            bottleneckLabel: 'ゴールデンアワー',
            title: '投稿直後30分: 反応を取りにいく',
            detail: '本日$postedCount件投稿済み。今は新規投稿より、投稿を開いて実際に来た'
                'コメントへ手動で返信し、poll票と初速($imprText)を確認するのが伸びを決めます。',
            icon: Icons.bolt,
            buttonLabel: tweetUrl != null ? '投稿を開く' : '反応を確認',
            isAcquisitionAction: false,
            launchUrl: tweetUrl,
          );
        }
        return _GrowthActionPlan(
          bottleneckLabel: 'リーチ→LP変換待ち',
          title: '本日は投稿済み（計測待ち）',
          detail: '本日$postedCount件投稿済み（$imprText）。再投稿は近似重複ガードに当たるため'
              '避け、bio・固定ツイート導線(X_PROFILE_CONVERSION_KIT)の見直しや大型'
              'アカウントへの手動返信で発見性を上げてください。次の投稿はJST 20-22時が目安です。',
          icon: Icons.hourglass_bottom,
          buttonLabel: tweetUrl != null ? '投稿を開いて確認' : '成長プレイブックを見る',
          isAcquisitionAction: false,
          launchUrl: tweetUrl,
        );
    }
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
      // R16: 今日すでに投稿済みなら「作れ」ではなくゴールデンアワー/計測待ち/上限
      // 確認へ切り替える(再投稿の near-dup ガード踏み+有償生成を防ぐ)。今日未投稿
      // or status 未取得なら null → 従来の「X投稿を作る」へフォールバック。
      final postedTodayPlan = _buildPostedTodayActionPlan();
      if (postedTodayPlan != null) return postedTodayPlan;
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
        .where(
          (entry) => _isAcquisitionSourceKey(entry.key) && entry.value > 0,
        )
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (actionableEntries.isEmpty) return 'x_share';
    return actionableEntries.first.key;
  }

  bool _isAcquisitionSourceKey(String key) {
    switch (key) {
      case 'direct':
      case 'x_share':
      case 'qr_scan':
      case 'facebook':
      case 'line':
      case 'copy_link':
        return true;
      default:
        return false;
    }
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

  /// 遷移先ページと、その画面に対応する URL (= route 名) を必ず対で返す。
  /// route を添えないと Flutter Web でブラウザの URL が更新されない。
  ({Widget page, String route}) _buildAcquisitionTarget(String? channelKey) {
    switch (channelKey) {
      case 'line':
        return (
          page: const AISecretaryPage(
            initialStrategyType: 'now',
            autoRunOnOpen: true,
          ),
          route: '/ai-secretary',
        );
      case 'qr_scan':
        return (
          page: const NoteListPage(prioritizeShareCandidates: true),
          route: '/notes',
        );
      case 'x_share':
      case 'facebook':
      default:
        return (
          page: CmoPage(initialChannel: channelKey, autoGenerateOnOpen: true),
          route: '/cmo',
        );
    }
  }

  void _openGrowthAction({
    required bool isAcquisitionAction,
    String? priorityChannelKey,
    String? priorityChannelLabel,
    String? ctaUrl,
  }) {
    // R16: 投稿済み/上限ブロック状態のボタンはページ遷移ではなく URL を外部起動
    // する(投稿を開く / console.x.com)。CmoPage への遷移(有償生成トリガ)を回避。
    if (ctaUrl != null && ctaUrl.isNotEmpty) {
      final uri = Uri.tryParse(ctaUrl);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final target = isAcquisitionAction
        ? _buildAcquisitionTarget(priorityChannelKey)
        : (
            page: const AISecretaryPage(
              initialStrategyType: 'now',
              autoRunOnOpen: true,
            ),
            route: '/ai-secretary',
          );

    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: target.route),
        builder: (_) => target.page,
      ),
    );

    final hint = isAcquisitionAction
        ? switch (priorityChannelKey) {
            'line' => 'AI秘書を開きました。LINE向けの短文導線を先に作ってください。',
            'qr_scan' => 'ノート一覧を開きました。QR遷移先に使うコンテンツを先に整えてください。',
            'facebook' => 'Facebook向け草案を起案します。投稿文を先に作ってください。',
            _ => '${priorityChannelLabel ?? '最優先チャネル'}で最初の流入を作る導線を先に実行してください。',
          }
        : 'AI秘書を導線改善モードで開きました。訴求文と導線文言を先に整えてください。';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
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
    _loadWeeklyDigest();
    _loadFeatureRequests();
    _loadWaitlist();
    _loadAdminUsers();
    _loadAutomationOps();
    _loadBlogPosts();
    _loadGrowthSummary();
    _loadComparisonCvr();
    _loadAppFeedbacks();
    _loadRecentErrors();
  }

  /// R29: 自動エラー報告を admin-hub errors.recent で取得する。取得失敗や未認証は
  /// 空へ degrade し、カードは「正常」表示 or 非表示になる (ダッシュボードは必ず描画)。
  Future<void> _loadRecentErrors() async {
    if (!mounted) return;
    if (_supabase.auth.currentUser == null) return;
    setState(() => _autoErrorReportsLoading = true);
    try {
      final res = await _supabase.functions.invoke(
        'admin-hub',
        body: const {'action': 'errors.recent', 'limit': 20},
      );
      final data = res.data;
      final entries = data is Map && data['success'] == true
          ? parseAutoErrorReports(data['errors'])
          : const <AutoErrorReportEntry>[];
      if (mounted) {
        setState(() {
          _autoErrorReports = entries;
          _autoErrorReportsLoading = false;
        });
      }
    } catch (error) {
      debugPrint('errors.recent unavailable: $error');
      if (mounted) setState(() => _autoErrorReportsLoading = false);
    }
  }

  Future<void> _loadAppFeedbacks() async {
    setState(() => _appFeedbacksLoading = true);
    try {
      final data = await _supabase
          .from('app_feedback')
          .select(
            'id, category, content, status, user_email, github_issue_url, created_at',
          )
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _appFeedbacks = List<Map<String, dynamic>>.from(data as List);
          _appFeedbacksLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _appFeedbacksLoading = false);
    }
  }

  Future<void> _updateFeedbackStatus(int id, String newStatus) async {
    if (_supabase.auth.currentUser == null) return;
    await _supabase
        .from('app_feedback')
        .update({'status': newStatus}).eq('id', id);
    if (newStatus == 'implemented') {
      try {
        await _supabase.functions.invoke(
          'admin-hub',
          body: {'action': 'admin.notify', 'feedback_id': id},
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        final idx = _appFeedbacks.indexWhere((f) => f['id'] == id);
        if (idx != -1) _appFeedbacks[idx]['status'] = newStatus;
      });
    }
  }

  Future<void> _loadWeeklyDigest() async {
    try {
      final digest = await _growthService.loadWeeklyDigest();
      if (!mounted) return;
      // R18: 完了フラグを立てて loading と loaded-empty を区別する
      // (loadWeeklyDigest は内部で握りつぶし empty() を返すため rethrow しない)。
      setState(() {
        _weeklyDigest = digest;
        _weeklyDigestLoaded = true;
      });
    } catch (e) {
      debugPrint('weekly digest load error: $e');
      if (mounted) setState(() => _weeklyDigestLoaded = true);
    }
  }

  Future<void> _loadFeatureRequests() async {
    if (!mounted) return;
    setState(() => _featureRequestsLoading = true);
    try {
      final data = await _supabase
          .from('feature_requests')
          .select(
            'id, title, description, email, votes, status, created_at, admin_reply, admin_replied_at, priority, effort, target_date',
          )
          .order('votes', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _featureRequests = List<Map<String, dynamic>>.from(data as List);
          _featureRequestsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('feature requests load error: $e');
      if (mounted) setState(() => _featureRequestsLoading = false);
    }
  }

  Future<void> _loadWaitlist() async {
    if (!mounted) return;
    setState(() => _waitlistLoading = true);
    try {
      final data = await _supabase
          .from('newsletter_waitlist')
          .select('id, email, source, created_at')
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() {
          _waitlistEmails = List<Map<String, dynamic>>.from(data as List);
          _waitlistLoading = false;
        });
      }
    } catch (e) {
      debugPrint('waitlist load error: $e');
      if (mounted) setState(() => _waitlistLoading = false);
    }
  }

  Future<void> _loadAdminUsers() async {
    if (!mounted) return;
    if (_supabase.auth.currentUser == null) {
      setState(() => _adminUsersLoading = false);
      return;
    }
    setState(() => _adminUsersLoading = true);
    try {
      final res = await _supabase.functions.invoke(
        'admin-hub',
        body: {'action': 'users.list', 'page': 1, 'perPage': 100},
      );
      final data = res.data as Map<String, dynamic>?;
      if (mounted && data != null && data['success'] == true) {
        setState(() {
          _adminUsers = List<Map<String, dynamic>>.from(
            data['users'] as List? ?? [],
          );
          _adminUsersTotal =
              (data['total'] as num?)?.toInt() ?? _adminUsers.length;
          _adminUsersLoading = false;
        });
      } else {
        if (mounted) setState(() => _adminUsersLoading = false);
      }
    } catch (e) {
      debugPrint('admin users load error: $e');
      if (mounted) setState(() => _adminUsersLoading = false);
    }
  }

  Map<String, String> _adminAuthHeaders(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
      };

  Future<void> _loadAutomationOps() async {
    if (!mounted) return;
    setState(() {
      _automationLoading = true;
      _automationError = null;
    });
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final headers = _adminAuthHeaders(session.accessToken);
      final results = await Future.wait<FunctionResponse>([
        _supabase.functions.invoke(
          'schedule-hub',
          headers: headers,
          body: const {'action': 'digest.run', 'source': 'admin_manual_check'},
        ),
        _supabase.functions.invoke(
          'admin-hub',
          headers: headers,
          body: const {
            'action': 'support.list',
            'source': 'admin_manual_check',
          },
        ),
      ]);

      final digestResult = results[0].data as Map<String, dynamic>?;
      final supportResult = results[1].data as Map<String, dynamic>?;
      if (digestResult?['success'] != true) {
        throw Exception('${digestResult?['error'] ?? 'digest load failed'}');
      }
      if (supportResult?['success'] != true) {
        throw Exception(
          supportResult?['error']?.toString() ?? 'support ticket load failed',
        );
      }

      final rawTickets = supportResult?['tickets'];
      final tickets = <Map<String, dynamic>>[];
      if (rawTickets is List) {
        for (final item in rawTickets.whereType<Map>()) {
          tickets.add(Map<String, dynamic>.from(item));
        }
      }

      final rawDigest = digestResult?['digest'];
      final digest = rawDigest is Map
          ? Map<String, dynamic>.from(rawDigest)
          : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _automationDigest = digest;
        _automationSupportTickets = tickets;
        _automationLoading = false;
        _automationError = null;
      });
    } catch (e) {
      debugPrint('automation ops load error: $e');
      if (!mounted) return;
      setState(() {
        _automationLoading = false;
        _automationError = e.toString();
      });
    }
  }

  Future<void> _updateFeatureRequestStatus(
    String id,
    String status,
    String title,
    String? email,
  ) async {
    try {
      await _supabase
          .from('feature_requests')
          .update({'status': status}).eq('id', id);
      await _loadFeatureRequests();
      await _loadAutomationOps();
      if (!mounted) return;
      // Offer to notify submitter when status changes to actionable state
      if ((status == 'done' || status == 'in_progress') &&
          email != null &&
          email.isNotEmpty) {
        _showFeatureRequestNotifyDialog(id, status, title, email);
      }
    } catch (e) {
      debugPrint('feature request status update error: $e');
    }
  }

  /// 優先度・工数・期日 (GitHub Issue Fields 相当) を管理者が設定する。
  Future<void> _showFeatureFieldsDialog(Map<String, dynamic> req) async {
    final id = '${req['id'] ?? ''}';
    if (id.isEmpty) return;
    String? priority = _nullableString(req['priority']);
    String? effort = _nullableString(req['effort']);
    DateTime? targetDate = DateTime.tryParse('${req['target_date'] ?? ''}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('優先度・工数・期日'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: '優先度'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('未設定'),
                        ),
                        ...kPriorityValues.map(
                          (v) => DropdownMenuItem<String?>(
                            value: v,
                            child: Text(priorityLabel(v)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => priority = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: effort,
                      decoration: const InputDecoration(labelText: '工数'),
                      items: <DropdownMenuItem<String?>>[
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('未設定'),
                        ),
                        ...kEffortValues.map(
                          (v) => DropdownMenuItem<String?>(
                            value: v,
                            child: Text(effortLabel(v)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setDialogState(() => effort = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            targetDate == null
                                ? '期日: 未設定'
                                : '期日: ${DateFormat('yyyy-MM-dd').format(targetDate!)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: targetDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setDialogState(() => targetDate = picked);
                            }
                          },
                          child: const Text('選択'),
                        ),
                        if (targetDate != null)
                          IconButton(
                            tooltip: '期日をクリア',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setDialogState(() => targetDate = null),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('キャンセル'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;
    await _updateFeatureRequestFields(
      id,
      priority: priority,
      effort: effort,
      targetDate: targetDate,
    );
  }

  Future<void> _updateFeatureRequestFields(
    String id, {
    required String? priority,
    required String? effort,
    required DateTime? targetDate,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _supabase.from('feature_requests').update(<String, dynamic>{
        'priority': priority,
        'effort': effort,
        'target_date': targetDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(targetDate),
      }).eq('id', id);
      await _loadFeatureRequests();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('優先度・工数・期日を更新しました')));
    } catch (e) {
      debugPrint('feature request fields update error: $e');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('更新に失敗: $e')));
    }
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  Future<void> _replySupportRequest({
    required String id,
    String? reply,
    required bool escalate,
    required String newStatus,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final response = await _supabase.functions.invoke(
        'admin-hub',
        headers: _adminAuthHeaders(session.accessToken),
        body: {
          'action': 'support.reply',
          'id': id,
          'reply': reply,
          'escalate': escalate,
          'newStatus': newStatus,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['success'] != true) {
        throw Exception(data?['error']?.toString() ?? 'reply failed');
      }

      await _loadFeatureRequests();
      await _loadAutomationOps();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(escalate ? 'チケットをエスカレーションしました' : '返信を送信しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CS返信に失敗しました: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  Future<void> _showSupportReplyDialog(Map<String, dynamic> req) async {
    final title = req['title']?.toString() ?? '(無題)';
    final email = req['email']?.toString();
    final existingReply = req['admin_reply']?.toString() ?? '';
    final replyCtrl = TextEditingController(text: existingReply);
    var selectedStatus = req['status']?.toString() ?? 'in_progress';

    final action = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('CS返信: $title'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email != null && email.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '送信先: $email',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        height: 1.5,
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: '返信後ステータス',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('open')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('in_progress'),
                    ),
                    DropdownMenuItem(value: 'done', child: Text('done')),
                    DropdownMenuItem(
                      value: 'rejected',
                      child: Text('rejected'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedStatus = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: replyCtrl,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: '返信文',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    hintText: 'ユーザーに送る返信文を入力',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, {
                'escalate': true,
                'status': 'in_progress',
              }),
              child: const Text('エスカレーション'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, {
                'reply': replyCtrl.text.trim(),
                'status': selectedStatus,
              }),
              child: const Text('返信送信'),
            ),
          ],
        ),
      ),
    );

    replyCtrl.dispose();
    if (action == null || !mounted) return;
    final escalate = action['escalate'] == true;
    final reply = action['reply']?.toString().trim();
    final newStatus = action['status']?.toString() ?? 'in_progress';
    if (!escalate && (reply == null || reply.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('返信文を入力してください')));
      return;
    }

    await _replySupportRequest(
      id: req['id']?.toString() ?? '',
      reply: reply,
      escalate: escalate,
      newStatus: newStatus,
    );
  }

  String _buildDefaultXPostDraft() {
    final digest = _automationDigest ?? <String, dynamic>{};
    final users = digest['users'] is Map
        ? Map<String, dynamic>.from(digest['users'] as Map)
        : <String, dynamic>{};
    final featureRequests = digest['featureRequests'] is Map
        ? Map<String, dynamic>.from(digest['featureRequests'] as Map)
        : <String, dynamic>{};
    final totalUsers = _toInt(users['total']);
    final newToday = _toInt(featureRequests['newToday']);
    final openCount = _toInt(featureRequests['openCount']);

    return '今日の自分株式会社\n'
        '総ユーザー$totalUsers人、新規要望$newToday件、未対応要望$openCount件を確認。'
        'CS自動化と改善を回し続けています。\n'
        'https://my-web-app-b67f4.web.app/ #buildinpublic #FlutterWeb #Supabase';
  }

  Future<void> _postXUpdate({
    required String text,
    required bool dryRun,
  }) async {
    if (!mounted) return;
    setState(() => _automationPostingX = true);
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final response = await _supabase.functions.invoke(
        'schedule-hub',
        headers: _adminAuthHeaders(session.accessToken),
        body: {'action': 'x.post', 'text': text, 'dryRun': dryRun},
      );
      final data = response.data as Map<String, dynamic>?;
      if (data?['success'] != true) {
        throw Exception(data?['error']?.toString() ?? 'X post failed');
      }

      if (!mounted) return;
      final account = data?['account']?.toString() ?? '@kanta13jp1';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dryRun ? '$account への投稿プレビューを確認しました' : '$account に投稿しました',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('X投稿に失敗しました: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _automationPostingX = false);
    }
  }

  Future<void> _showXPostDialog() async {
    final textCtrl = TextEditingController(text: _buildDefaultXPostDraft());
    final action = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('X投稿テスト (@kanta13jp1)'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: textCtrl,
            minLines: 6,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: '投稿文',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              helperText: 'プレビューは dry-run、投稿は本番アカウントへ送信します。',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('キャンセル'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'preview'),
            child: const Text('プレビュー'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'post'),
            child: const Text('投稿'),
          ),
        ],
      ),
    );

    final text = textCtrl.text.trim();
    textCtrl.dispose();
    if (action == null || text.isEmpty) return;
    await _postXUpdate(text: text, dryRun: action == 'preview');
  }

  void _showFeatureRequestNotifyDialog(
    String id,
    String status,
    String title,
    String email,
  ) {
    final statusLabel = status == 'done' ? '実装完了' : '対応中';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$statusLabel を通知しますか？'),
        content: Text(
          '「$title」のステータスが "$statusLabel" に変更されました。\n'
          '投稿者（$email）にメールで通知しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('スキップ'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _notifyFeatureRequestSubmitter(id, status, title, email);
            },
            child: const Text('通知する'),
          ),
        ],
      ),
    );
  }

  Future<void> _notifyFeatureRequestSubmitter(
    String id,
    String status,
    String title,
    String email,
  ) async {
    if (!mounted) return;
    setState(() => _sendingNotification = true);
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');
      final resp = await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'notify.feature', 'id': id, 'status': status},
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      if (resp.status != 200) {
        final errData = resp.data as Map<String, dynamic>?;
        throw Exception(errData?['error']?.toString() ?? 'Unknown error');
      }
      if (!mounted) return;
      setState(() => _sendingNotification = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$email に通知を送信しました')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingNotification = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('通知送信に失敗しました: $e')));
    }
  }

  Future<void> _sendWaitlistNotification({
    required String subject,
    required String bodyHtml,
  }) async {
    if (!mounted) return;
    setState(() => _sendingNotification = true);
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final res = await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'waitlist.notify',
          'subject': subject,
          'bodyHtml': bodyHtml,
        },
      );
      debugPrint('waitlist.notify result: ${res.data}');
      if (mounted) {
        final data = res.data as Map<String, dynamic>?;
        final sent = data?['sent'] ?? 0;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$sent 件に送信しました')));
      }
    } catch (e) {
      debugPrint('send notification error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信エラー: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingNotification = false);
    }
  }

  Future<void> _showNotificationComposeDialog() async {
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ウェイトリストに通知送信'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                  labelText: '件名',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                decoration: const InputDecoration(
                  labelText: '本文 (HTML可)',
                  border: OutlineInputBorder(),
                ),
                minLines: 5,
                maxLines: 10,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('送信'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        subjectCtrl.text.isNotEmpty &&
        bodyCtrl.text.isNotEmpty) {
      await _sendWaitlistNotification(
        subject: subjectCtrl.text.trim(),
        bodyHtml: bodyCtrl.text.trim(),
      );
    }
    subjectCtrl.dispose();
    bodyCtrl.dispose();
  }

  /// agent_tool_execution_logs を fail-safe に取得する (テーブル未整備でも
  /// ダッシュボードは必ず描画する)。_loadStats の並列開始点から呼ぶ。
  Future<List<Map<String, dynamic>>> _fetchToolExecutionLogsSafe() async {
    try {
      final dynamic rawToolLogs = await _supabase
          .from('agent_tool_execution_logs')
          .select('tool_name, allowed, blocked_reason, created_at')
          .order('created_at', ascending: false)
          .limit(80);
      if (rawToolLogs is List) {
        return [
          for (final row in rawToolLogs.whereType<Map>())
            Map<String, dynamic>.from(row),
        ];
      }
    } catch (error) {
      debugPrint('agent_tool_execution_logs is unavailable: $error');
    }
    return const [];
  }

  Future<void> _loadStats() async {
    try {
      final today = _startOfDay(DateTime.now());
      final startDate = today.subtract(const Duration(days: 29));
      final startDateKey = _dateKey(startDate);
      final endDateKey = _dateKey(today);

      final statsFuture = Future.wait<dynamic>([
        _supabase
            .from('app_analytics')
            .select(
              'date, landing_views, conversions, share_count, source_details',
            )
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
      // 相互依存の無いローダーは DB 4本と同時に開始する。旧実装は
      // 「DB 4本 → growth-hub 4本 → tool logs」の3段直列で、全画面スピナーが
      // 3段の合計時間 (数秒) ブロックしていた。並列化で最遅1本ぶんに縮む。
      final paidConversionFuture = _loadPaidConversionMetrics();
      final xTodayStatusFuture = _loadXTodayStatus();
      final xPerformanceContextFuture = _loadXPerformanceContext();
      final xCandidatesFuture = _loadXCandidateQueue();
      final toolLogsFuture = _fetchToolExecutionLogsSafe();

      final results = await statsFuture;
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
      final paidConversionMetrics = await paidConversionFuture;
      final xTodayStatus = await xTodayStatusFuture;
      final xPerformanceContext = await xPerformanceContextFuture;
      final xCandidates = await xCandidatesFuture;

      final toolExecutionLogs = <Map<String, dynamic>>[];
      final blockedReasonCounts = <String, int>{};
      var allowedExecutionCount = 0;
      var blockedExecutionCount = 0;

      for (final log in await toolLogsFuture) {
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
          _paidConversionMetrics = paidConversionMetrics;
          _xTodayStatus = xTodayStatus;
          _xPerformanceContext = xPerformanceContext;
          _xCandidates = xCandidates.candidates;
          _xCandidateTotals = xCandidates.totalsByStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
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

    final acquisitionEvidence = adminAcquisitionEvidenceFromAggregateSignals(
      sourceBreakdown,
    );
    final chartData = _dailyStats.reversed.toList();
    final effectiveTodayViews = _hasLpViewStats ? _lpTodayViews : todayViews;
    final effectiveTotalLpViews =
        _hasLpViewStats ? _lpTotalViews : analyticsViews;
    final double todaySummaryCvr = effectiveTodayViews == 0
        ? 0
        : (todayRegistrations / effectiveTodayViews * 100);
    final todayFunnel = _extractFunnelMetrics(todaySourceDetails);
    final totalFunnel = _extractFunnelMetrics(funnelBreakdown);
    final totalBillingFunnel = _extractBillingFunnelMetrics(funnelBreakdown);
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
    final zeroRegistrationStreakDays = _countConsecutiveNoRegistrationDays(
      _dailyStats,
    );
    // R18: streak が集計窓(_dailyStats)を使い切っていると値は下限。実際はそれ以上
    // なので「N日以上」と正直に出す(30 をちょうどの安心値に見せない)。
    final zeroStreakAtCap = streakAtWindowCap(
      zeroRegistrationStreakDays,
      _dailyStats.length,
    );
    final averageViewsLast7Days = _averageViews(_dailyStats);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          '経営分析ダッシュボード',
          style: TextStyle(fontWeight: FontWeight.bold, height: 1.5),
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: const Color(0xFFE5E7EB),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
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
                    Card(
                      color: const Color(0xFF1A1A2E),
                      child: ListTile(
                        leading: const Icon(
                          Icons.monitor_heart,
                          color: Color(0xFFFF6B35),
                        ),
                        title: const Text(
                          'AI クォータ監視',
                          style: TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        subtitle: const Text(
                          'Claude / OpenAI / Gemini / Copilot の使用状況',
                          style: TextStyle(
                            color: Color(0xB3E5E7EB),
                            height: 1.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0x8AE5E7EB),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: '/quota-dashboard',
                            ),
                            builder: (_) => const QuotaDashboardPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: const Color(0xFF1A1A2E),
                      child: ListTile(
                        leading: const Icon(
                          Icons.published_with_changes_outlined,
                          color: Color(0xFFFF6B35),
                        ),
                        title: const Text(
                          'AI成果物 公開ループ',
                          style: TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        subtitle: const Text(
                          '候補、権利、検査、商品ステージを人手承認つきで管理',
                          style: TextStyle(
                            color: Color(0xB3E5E7EB),
                            height: 1.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0x8AE5E7EB),
                        ),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/admin/artifact-publishing',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: const Color(0xFF1A1A2E),
                      child: ListTile(
                        leading: const Icon(
                          Icons.record_voice_over_outlined,
                          color: Color(0xFFFF6B35),
                        ),
                        title: const Text(
                          'Voice AI cost monitor',
                          style: TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        subtitle: const Text(
                          'TTS/STT usage, estimated cost, and realtime latency',
                          style: TextStyle(
                            color: Color(0xB3E5E7EB),
                            height: 1.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0x8AE5E7EB),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: '/admin/voice-ai-governance',
                            ),
                            builder: (_) =>
                                const VoiceAiGovernancePage(adminMode: true),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: const Color(0xFF1A1A2E),
                      child: ListTile(
                        leading: const Icon(
                          Icons.edit_note,
                          color: Color(0xFFFF6B35),
                        ),
                        title: const Text(
                          'ブログ管理',
                          style: TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        subtitle: const Text(
                          '投稿記事・いいね・コメント返信の確認',
                          style: TextStyle(
                            color: Color(0xB3E5E7EB),
                            height: 1.5,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0x8AE5E7EB),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            settings: const RouteSettings(
                              name: '/blog-management',
                            ),
                            builder: (_) => const BlogManagementPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTodayRegistrationGoalCard(
                      todayViews: effectiveTodayViews,
                      todayRegistrations: todayRegistrations,
                      sourceBreakdown: sourceBreakdown,
                      todayFunnel: todayFunnel,
                    ),
                    // R17: X 学習ループ(勝ち型/計測待ち/cron警告)を意思決定点に露出。
                    // データが無いときは SizedBox.shrink() で静かに消える。
                    _buildXGrowthLoopSection(),
                    _buildXCandidateQueueSection(),
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
                    AdminPaidConversionCard(
                      metrics: _paidConversionMetrics,
                      totalUsers: _actualUserCount,
                    ),
                    const SizedBox(height: 16),
                    AdminBillingFunnelCard(metrics: totalBillingFunnel),
                    const SizedBox(height: 16),
                    AdminGrowthEvidenceSection(
                      acquisitionEvidence: acquisitionEvidence,
                    ),
                    const SizedBox(height: 16),
                    AdminRegistrationOpsCard(
                      todayDropBeforeTrial: todayDropBeforeTrial,
                      totalDropBeforeTrial: totalDropBeforeTrial,
                      zeroRegistrationStreakDays: zeroRegistrationStreakDays,
                      zeroStreakAtCap: zeroStreakAtCap,
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSourceDistribution(sourceBreakdown),
                    const SizedBox(height: 24),
                    const Text(
                      'シェアチャネル (Share Actions)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AdminToolExecutionGuardCard(
                      toolExecutionLogs: _toolExecutionLogs,
                      allowedToolExecutionCount: _allowedToolExecutionCount,
                      blockedToolExecutionCount: _blockedToolExecutionCount,
                      blockedReasonBreakdown: _blockedReasonBreakdown,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '週次ダイジェスト',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildWeeklyDigestCard(context),
                    const SizedBox(height: 24),
                    const Text(
                      '登録ユーザー管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAdminUsersCard(),
                    const SizedBox(height: 24),
                    const Text(
                      '機能リクエスト・自動化・ウェイトリスト',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureRequestsAdminCard(),
                    const SizedBox(height: 16),
                    _buildAutomationOpsCard(),
                    const SizedBox(height: 16),
                    _buildAutoErrorReportsCard(),
                    const SizedBox(height: 16),
                    const SelfDevinControlTowerCard(),
                    const SizedBox(height: 16),
                    const ScheduleTaskMonitorCard(),
                    const SizedBox(height: 16),
                    const CompetitorMonitoringCard(),
                    const SizedBox(height: 16),
                    _buildBlogPostsCard(),
                    const SizedBox(height: 16),
                    _buildComparisonCvrCard(),
                    const SizedBox(height: 16),
                    _buildGrowthAchievementSummaryCard(),
                    const SizedBox(height: 16),
                    _buildWaitlistCard(),
                    const SizedBox(height: 16),
                    _buildUserFeedbackCard(),
                    const SizedBox(height: 24),
                    const Text(
                      '日次レポート詳細',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
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
    // R16: 今日すでに投稿済み(または spend-cap ブロック中)なら、todayViews==0 でも
    // 「流入不足/今日の流入がありません」を出さず、growthAction(投稿済み状態機械の
    // 出力)の診断・文言をそのまま使う。
    final postedTodayActive =
        !achieved && todayViews == 0 && _buildPostedTodayActionPlan() != null;
    final diagnosisLabel = achieved
        ? '登録発生'
        : postedTodayActive
            ? growthAction.bottleneckLabel
            : todayViews == 0
                ? '流入不足'
                : growthAction.bottleneckLabel;
    final diagnosisColor = achieved
        ? const Color(0xFF0D9488)
        : postedTodayActive
            ? const Color(0xFF6366F1)
            : todayViews == 0
                ? const Color(0xFFFF6B35)
                : todayFunnel.trialRuns == 0
                    ? const Color(0xFF0D9488)
                    : todayFunnel.saveClicks == 0
                        ? const Color(0xFF6366F1)
                        : todayFunnel.magicLinkSends == 0
                            ? const Color(0xFFFF6B35)
                            : todayFunnel.inboxOpens == 0
                                ? const Color(0xFF92400E)
                                : const Color(0xFFB91C1C);
    final statusText = achieved
        ? '今日の登録目標は達成済みです。次は流入改善で上振れを狙う。'
        : postedTodayActive
            ? growthAction.detail
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

    return AdminTodayRegistrationGoalCard(
      todayViews: todayViews,
      todayRegistrations: todayRegistrations,
      trialRuns: todayFunnel.trialRuns,
      magicLinkSends: todayFunnel.magicLinkSends,
      cvrText: formatRatePercent(todayRegistrations, todayViews),
      diagnosisLabel: diagnosisLabel,
      diagnosisColor: diagnosisColor,
      priorityChannelLabel: priorityChannelLabel,
      statusText: statusText,
      actionTitle: achieved ? null : growthAction.title,
      actionDetail: achieved ? null : growthAction.detail,
      actionIcon: achieved ? null : growthAction.icon,
      actionButtonLabel: achieved ? null : growthAction.buttonLabel,
      onActionPressed: achieved
          ? null
          : () => _openGrowthAction(
                isAcquisitionAction: growthAction.isAcquisitionAction,
                priorityChannelKey: priorityChannelKey,
                priorityChannelLabel: priorityChannelLabel,
                ctaUrl: growthAction.launchUrl,
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

    return AdminRegistrationFunnelCard(
      title: title,
      lpViews: lpViews,
      registrations: registrations,
      trialRuns: funnel.trialRuns,
      saveClicks: funnel.saveClicks,
      magicLinkSends: funnel.magicLinkSends,
      inboxOpens: funnel.inboxOpens,
      remainingRegistrations: remainingRegistrations,
      bottleneckLabel: funnelAction.bottleneckLabel,
      neededMagicLinks: neededMagicLinks,
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
      shadowColor: const Color(0x42000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              '今日CVR (実登録ベース)',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            // R17: 流入0のときは測定不能なので「0.0%」ではなく中立の「—」計測待ち
            // を出す(母数=todayViews==0 で判定。流入>0で登録0は真の0.0%なので従来表示)。
            if (todayViews == 0)
              const Text(
                '—',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9CA3AF),
                  height: 1.4,
                ),
              )
            else
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
                      height: 1.4,
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
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            if (todayViews == 0)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text(
                  '計測待ち（流入なし）',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
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
                  const Color(0xFF6366F1),
                ),
                _buildStatItem(
                  '今日登録',
                  '$todayRegistrations',
                  Icons.person_add,
                  const Color(0xFF6366F1),
                ),
                _buildStatItem(
                  '今日体験',
                  '${todayFunnel.trialRuns}',
                  Icons.play_circle_outline,
                  const Color(0xFF0D9488),
                ),
                _buildStatItem(
                  '今日Magic Link送信',
                  '${todayFunnel.magicLinkSends}',
                  Icons.mail_outline,
                  const Color(0xFF7C3AED),
                ),
                _buildStatItem(
                  '累計登録',
                  '$totalRegistrations',
                  Icons.group,
                  const Color(0xFF7C3AED),
                ),
                _buildStatItem(
                  '30日シェア',
                  '$shares',
                  Icons.share,
                  const Color(0xFFFF6B35),
                ),
                _buildStatItem(
                  '累計LP View',
                  '$totalLpViews',
                  Icons.analytics,
                  const Color(0xFF0D9488),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getCvrColor(double cvr) {
    if (cvr >= 10) return const Color(0xFF0D9488);
    if (cvr >= 5) return const Color(0xFFFF6B35);
    return const Color(0xFFB91C1C);
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
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
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      FractionallySizedBox(
                        heightFactor: convHeightRatio,
                        child: Container(
                          width: barWidth,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
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
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
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
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'データなし',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
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
      color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                    Text(
                      ' $percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
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
    return key.startsWith('funnel_') ||
        key.startsWith('lp_exp_') ||
        key.startsWith('activation_exp_');
  }

  bool _isShareActionKey(String key) {
    switch (key) {
      case 'share_x':
      case 'share_line':
      case 'share_facebook':
      case 'share_copy':
      case 'share_note':
      case 'public_memo_share':
      case 'public_memo_copy':
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
      case 'share_note':
        return 'メモ共有';
      case 'public_memo_share':
        return 'Public memo share';
      case 'public_memo_copy':
        return 'Public memo copy';
      case 'touch_landing':
        return 'Landing touch';
      case 'touch_profile':
        return 'X profile touch';
      case 'touch_import':
        return 'Import touch';
      case 'touch_public_memo':
        return 'Public memo touch';
      case 'touch_referral':
        return 'Referral touch';
      case 'touch_comparison':
        return 'Comparison page touch';
      case 'import_preview_notion':
        return 'Import preview: Notion';
      case 'import_preview_evernote':
        return 'Import preview: Evernote';
      case 'import_preview_markdown':
        return 'Import preview: Markdown';
      case 'import_signup_cta':
        return 'Import sign-up CTA';
      case 'public_memo_signup_cta':
        return 'Public memo sign-up CTA';
      case 'signup_submit_landing':
        return 'Sign-up submit: Landing';
      case 'signup_submit_profile':
        return 'Sign-up submit: X profile';
      case 'signup_submit_import':
        return 'Sign-up submit: Import';
      case 'signup_submit_public_memo':
        return 'Sign-up submit: Public memo';
      case 'signup_submit_referral':
        return 'Sign-up submit: Referral';
      case 'signup_submit_comparison':
        return 'Sign-up submit: Comparison';
      default:
        return key;
    }
  }

  Color _getSourceColor(String key) {
    switch (key) {
      case 'direct':
        return Theme.of(context).colorScheme.outlineVariant;
      case 'x_share':
        return Colors.black;
      case 'qr_scan':
        return const Color(0xFF0D9488);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'line':
        return const Color(0xFF06C755);
      case 'copy_link':
        return const Color(0xFF7C3AED);
      case 'share_x':
        return Theme.of(context).colorScheme.onSurface;
      case 'share_line':
        return const Color(0xFF06C755);
      case 'share_facebook':
        return const Color(0xFF1877F2);
      case 'share_copy':
        return const Color(0xFF7C3AED);
      case 'share_note':
        return const Color(0xFF3D5AFE);
      case 'public_memo_share':
        return const Color(0xFFFF6B35);
      case 'public_memo_copy':
        return const Color(0xFFFFA000);
      case 'touch_landing':
        return const Color(0xFF475569);
      case 'touch_profile':
        return const Color(0xFF0F172A);
      case 'touch_import':
        return const Color(0xFF818CF8);
      case 'touch_public_memo':
        return const Color(0xFFFF6B35);
      case 'touch_referral':
        return const Color(0xFF0D9488);
      case 'touch_comparison':
        return const Color(0xFFA78BFA);
      case 'import_preview_notion':
        return const Color(0xFF6366F1);
      case 'import_preview_evernote':
        return const Color(0xFF059669);
      case 'import_preview_markdown':
        return const Color(0xFF8D6E63);
      case 'import_signup_cta':
        return const Color(0xFF7C3AED);
      case 'public_memo_signup_cta':
        return const Color(0xFFEC4899);
      case 'signup_submit_landing':
        return const Color(0xFF0D9488);
      case 'signup_submit_profile':
        return const Color(0xFF2563EB);
      case 'signup_submit_import':
        return const Color(0xFF4338CA);
      case 'signup_submit_public_memo':
        return const Color(0xFFFF6B35);
      case 'signup_submit_referral':
        return const Color(0xFF0F766E);
      case 'signup_submit_comparison':
        return const Color(0xFF6D28D9);
      default:
        return const Color(0xFF6366F1);
    }
  }

  Widget _buildWeeklyDigestCard(BuildContext context) {
    final d = _weeklyDigest;
    final hasData = d.currentWeekStart.isNotEmpty;
    // R18: loading / loaded-empty / loaded-data の3状態に分けてヘッダ文言を決める。
    final cardState = weeklyDigestCardState(
      loaded: _weeklyDigestLoaded,
      hasData: hasData,
    );
    final headerText = switch (cardState) {
      WeeklyDigestCardState.loading => '読み込み中...',
      WeeklyDigestCardState.empty => '今週はまだ計測データがありません（計測待ち）',
      WeeklyDigestCardState.data =>
        '${d.currentWeekStart} 〜 ${d.currentWeekEnd}',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize, size: 18, color: Color(0xFF3949AB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headerText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          if (hasData) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _weeklyKpiChip('登録', d.signupSubmitTotal, d.signupSubmitDelta),
                _weeklyKpiChip('紹介', d.referralsCompleted, d.referralsDelta),
                _weeklyKpiChip('インポートCTA', d.importCtaClicks, 0),
                _weeklyKpiChip('公開メモCTA', d.publicMemoCtaClicks, 0),
              ],
            ),
            if (d.channels.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'チャネル別',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ...d.channels.map(
                (ch) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          ch.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF374151),
                            height: 1.5,
                          ),
                        ),
                      ),
                      Text(
                        'タッチ ${ch.touches}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '登録 ${ch.signupSubmits}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3949AB),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (d.brief.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                d.brief,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _weeklyKpiChip(String label, int value, int delta) {
    final isPositive = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  height: 1.5,
                ),
              ),
              if (delta != 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}$delta',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
        // R17: 流入0の日は測定不能。「0.0%」赤バッジ(_getCvrColorは0→赤)ではなく
        // 中立グレーの「—」を出す(流入>0で登録0は真の0.0%なので従来色)。
        final cvrBadgeColor =
            views == 0 ? const Color(0xFF9CA3AF) : _getCvrColor(cvr);
        final cvrBadgeText = formatRatePercent(conv, views);
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
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),
            title: Text(
              dateStr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            subtitle: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _miniStat(Icons.visibility, '$views', const Color(0xFF6366F1)),
                _miniStat(
                  Icons.play_circle_outline,
                  '${dayFunnel.trialRuns}',
                  const Color(0xFF0D9488),
                ),
                _miniStat(
                  Icons.mail_outline,
                  '${dayFunnel.magicLinkSends}',
                  const Color(0xFF7C3AED),
                ),
                _miniStat(Icons.person_add, '$conv', const Color(0xFF6366F1)),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cvrBadgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cvrBadgeText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cvrBadgeColor,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'CVR',
                    style: TextStyle(
                      fontSize: 10,
                      color: cvrBadgeColor,
                      height: 1.5,
                    ),
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
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCompletionSummary() {
    // R19: 旧サマリは未fetch の completionPct(全員0)で「0完成/0途中/44未設定」を
    // 捏造していた。email 空=匿名 auth を信頼プロキシに「実ユーザー/匿名テスト」へ
    // 誠実に分割する(合計44 vs 実CVR4 の乖離=匿名を実登録と誤認する虚栄を防ぐ)。
    final split = summarizeAdminUsers(_adminUsers);
    return Row(
      children: [
        _profileStatChip(
          Icons.verified_user_outlined,
          '実ユーザー ${split.real}人',
          const Color(0xFF0D9488),
        ),
        const SizedBox(width: 8),
        _profileStatChip(
          Icons.help_outline,
          '匿名テスト ${split.anon}人',
          const Color(0xFF9CA3AF),
        ),
      ],
    );
  }

  Widget _profileStatChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminUsersCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: Color(0xFF3949AB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _adminUsers.isEmpty
                        ? '登録ユーザー管理 (合計 $_adminUsersTotal 人)'
                        : '登録ユーザー管理 (合計 $_adminUsersTotal 人 / '
                            '実 ${summarizeAdminUsers(_adminUsers).real}・'
                            '匿名 ${summarizeAdminUsers(_adminUsers).anon})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadAdminUsers,
                  tooltip: '更新',
                ),
              ],
            ),
            if (_adminUsers.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildProfileCompletionSummary(),
            ],
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'メール・表示名で検索...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _userSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setState(() => _userSearchQuery = ''),
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
              ),
              style: const TextStyle(fontSize: 13, height: 1.6),
              onChanged: (v) => setState(() => _userSearchQuery = v),
            ),
            const SizedBox(height: 8),
            if (_adminUsersLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_adminUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'ユーザーが取得できませんでした',
                  style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
              )
            else
              Builder(
                builder: (context) {
                  final filteredUsers = _userSearchQuery.isEmpty
                      ? _adminUsers
                      : _adminUsers.where((u) {
                          final q = _userSearchQuery.toLowerCase();
                          final email =
                              u['email']?.toString().toLowerCase() ?? '';
                          final name =
                              u['displayName']?.toString().toLowerCase() ?? '';
                          return email.contains(q) || name.contains(q);
                        }).toList();
                  if (filteredUsers.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        '該当するユーザーが見つかりません',
                        style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final email = user['email']?.toString() ?? '';
                      final displayName = user['displayName']?.toString();
                      final bio = user['bio']?.toString();
                      final location = user['location']?.toString();
                      final provider = user['provider']?.toString() ?? 'email';
                      // R19: edge は created_at(snake)を返すのに旧UIは createdAt
                      // (camel)を読み全行の登録日が空だった。snake 優先で吸収する。
                      final createdAt = adminUserCreatedRaw(user);
                      final lastSignIn = user['lastSignInAt']?.toString() ?? '';
                      // R19: email 空 = Supabase 匿名 auth(headless 検証)の信頼プロキシ。
                      final isAnonymous = adminUserIsAnonymous(user);

                      // R19: 登録日=parse 不可なら「日付なし」、最終ログインは edge が
                      // 未送出のため「ログイン記録なし」と正直に出す(空欄で誤魔化さない)。
                      String createdStr = '日付なし';
                      String lastSignInStr = 'ログイン記録なし';
                      try {
                        createdStr = DateFormat(
                          'yyyy/MM/dd',
                        ).format(DateTime.parse(createdAt).toLocal());
                      } catch (_) {}
                      try {
                        lastSignInStr = DateFormat(
                          'MM/dd HH:mm',
                        ).format(DateTime.parse(lastSignIn).toLocal());
                      } catch (_) {}

                      final isGoogle = provider.contains('google');
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isGoogle
                                  ? (isDark
                                      ? const Color(0xFF0D2E1A)
                                      : const Color(0xFFE8F5E9))
                                  : (isDark
                                      ? const Color(0xFF1A1E3A)
                                      : const Color(0xFFE8EAF6)),
                              child: Text(
                                email.isNotEmpty
                                    ? email[0].toUpperCase()
                                    : (isAnonymous ? '匿' : '?'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isGoogle
                                      ? const Color(0xFF388E3C)
                                      : const Color(0xFF3949AB),
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayName != null &&
                                                  displayName.isNotEmpty
                                              ? displayName
                                              : (email.isNotEmpty
                                                  ? email
                                                  : '匿名ユーザー'),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isGoogle
                                              ? (isDark
                                                  ? const Color(0xFF0D2E1A)
                                                  : const Color(0xFFE8F5E9))
                                              : (isDark
                                                  ? const Color(0xFF1A1E3A)
                                                  : const Color(0xFFE8EAF6)),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          // R30: edge users.list は provider を
                                          // 返さない → isGoogle は常に false で
                                          // 全員 'Email' と誤表示していた。
                                          // 判別不能なので中立の '登録済' にする。
                                          isAnonymous ? '匿名' : '登録済',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isGoogle
                                                ? const Color(0xFF388E3C)
                                                : const Color(0xFF3949AB),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (displayName != null &&
                                      displayName.isNotEmpty)
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF9CA3AF),
                                        height: 1.5,
                                      ),
                                    ),
                                  if (bio != null && bio.isNotEmpty)
                                    Text(
                                      bio,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (location != null && location.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 11,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                        Text(
                                          location,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF9CA3AF),
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  // R19: completionPct は users.list が未送出で常に0。
                                  // 「プロフィール 0%」バーは捏造なので出さず、未取得を
                                  // 正直に表示する(R17 の display-truthfulness 規律)。
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 11,
                                        color: Color(0xFF9CA3AF),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'プロフィール情報 未取得',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF9CA3AF),
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '登録: $createdStr　最終ログイン: $lastSignInStr',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF9CA3AF),
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _showUserProfileDialog(user),
                                      icon: const Icon(
                                        Icons.person_outline,
                                        size: 13,
                                      ),
                                      label: const Text(
                                        'プロフィール詳細',
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.5,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF3949AB,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _adminUpdateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    if (_supabase.auth.currentUser == null) return;
    final body = <String, dynamic>{'userId': userId, ...updates};
    await _supabase.functions.invoke(
      'core-hub',
      body: <String, dynamic>{'action': 'user.update', ...body},
    );
  }

  void _showUserProfileDialog(Map<String, dynamic> user) {
    final email = user['email']?.toString() ?? '';
    final displayName = user['displayName']?.toString() ?? '';
    final bio = user['bio']?.toString() ?? '';
    final location = user['location']?.toString() ?? '';
    final twitterHandle = user['twitterHandle']?.toString() ?? '';
    final githubHandle = user['githubHandle']?.toString() ?? '';
    final websiteUrl = user['websiteUrl']?.toString() ?? '';
    final avatarUrl = user['avatarUrl']?.toString() ?? '';
    final isPublic = user['isPublic'] as bool? ?? true;
    final completionPct = _toInt(user['completionPct']);
    final hasProfile = user['hasProfile'] as bool? ?? false;
    final provider = user['provider']?.toString() ?? 'email';
    final isGoogle = provider.contains('google');
    // R19: 行と同じ契約バグ。edge の created_at(snake)を優先で拾う。
    final createdAt = adminUserCreatedRaw(user);
    final lastSignIn = user['lastSignInAt']?.toString() ?? '';

    String createdStr = '';
    String lastSignInStr = '';
    try {
      createdStr = DateFormat(
        'yyyy/MM/dd HH:mm',
      ).format(DateTime.parse(createdAt).toLocal());
    } catch (_) {}
    try {
      lastSignInStr = DateFormat(
        'yyyy/MM/dd HH:mm',
      ).format(DateTime.parse(lastSignIn).toLocal());
    } catch (_) {}

    Color profileColor;
    if (!hasProfile || completionPct < 34) {
      profileColor = const Color(0xFFB91C1C);
    } else if (completionPct < 67) {
      profileColor = const Color(0xFFFF6B35);
    } else {
      profileColor = const Color(0xFF0D9488);
    }

    // Build list of missing fields for the warning
    final missingFields = <String>[];
    if (displayName.isEmpty) missingFields.add('表示名');
    if (bio.isEmpty) missingFields.add('自己紹介');
    if (avatarUrl.isEmpty) missingFields.add('アバター');
    if (location.isEmpty) missingFields.add('場所');
    if (twitterHandle.isEmpty) missingFields.add('Twitter/X');
    if (githubHandle.isEmpty) missingFields.add('GitHub');
    if (websiteUrl.isEmpty) missingFields.add('ウェブサイト');

    final userId = user['id']?.toString() ?? '';
    final nameCtrl = TextEditingController(text: displayName);
    final bioCtrl = TextEditingController(text: bio);
    final locationCtrl = TextEditingController(text: location);
    final twitterCtrl = TextEditingController(text: twitterHandle);
    final githubCtrl = TextEditingController(text: githubHandle);
    final websiteCtrl = TextEditingController(text: websiteUrl);

    bool editMode = false;
    bool saving = false;
    bool editIsPublic = isPublic;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setInner) {
          final isDark = Theme.of(ctx2).brightness == Brightness.dark;
          Future<void> saveProfile() async {
            setInner(() => saving = true);
            try {
              await _adminUpdateUserProfile(userId, {
                'display_name': nameCtrl.text.trim(),
                'bio': bioCtrl.text.trim(),
                'location': locationCtrl.text.trim(),
                'twitter_handle': twitterCtrl.text.trim(),
                'github_handle': githubCtrl.text.trim(),
                'website_url': websiteCtrl.text.trim(),
                'is_public': editIsPublic,
              });
              if (ctx2.mounted) {
                setInner(() {
                  editMode = false;
                  saving = false;
                });
                _loadAdminUsers();
                ScaffoldMessenger.of(
                  ctx2,
                ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
              }
            } catch (e) {
              if (ctx2.mounted) {
                setInner(() => saving = false);
                ScaffoldMessenger.of(
                  ctx2,
                ).showSnackBar(SnackBar(content: Text('更新失敗: $e')));
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                if (avatarUrl.isNotEmpty)
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(avatarUrl),
                    onBackgroundImageError: (_, __) {},
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isGoogle
                        ? (isDark
                            ? const Color(0xFF0D2E1A)
                            : const Color(0xFFE8F5E9))
                        : (isDark
                            ? const Color(0xFF1A1E3A)
                            : const Color(0xFFE8EAF6)),
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isGoogle
                            ? const Color(0xFF388E3C)
                            : const Color(0xFF3949AB),
                        height: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.isNotEmpty ? displayName : email,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      if (displayName.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        ),
                      Row(
                        children: [
                          Icon(
                            isPublic ? Icons.public : Icons.lock_outlined,
                            size: 12,
                            color: const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isPublic ? '公開プロフィール' : '非公開プロフィール',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (editMode)
                  Chip(
                    label: const Text(
                      '編集中',
                      style: TextStyle(fontSize: 10, height: 1.5),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF0A1A2E)
                        : const Color(0xFFE3F2FD),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: completionPct / 100,
                              minHeight: 6,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                profileColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'プロフィール $completionPct%',
                          style: TextStyle(
                            fontSize: 12,
                            color: profileColor,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    if (!editMode) ...[
                      _profileDetailRow(
                        Icons.person_outlined,
                        '表示名',
                        displayName,
                      ),
                      const SizedBox(height: 8),
                      _profileDetailRow(Icons.notes_outlined, '自己紹介', bio),
                      const SizedBox(height: 8),
                      _profileDetailRow(
                        Icons.image_outlined,
                        'アバター画像',
                        avatarUrl,
                      ),
                      const SizedBox(height: 8),
                      _profileDetailRow(
                        Icons.location_on_outlined,
                        '場所',
                        location,
                      ),
                      const SizedBox(height: 8),
                      _profileDetailRow(
                        Icons.alternate_email,
                        'Twitter/X',
                        twitterHandle.isNotEmpty ? '@$twitterHandle' : '',
                      ),
                      const SizedBox(height: 8),
                      _profileDetailRow(
                        Icons.code,
                        'GitHub',
                        githubHandle.isNotEmpty ? '@$githubHandle' : '',
                      ),
                      const SizedBox(height: 8),
                      _profileDetailRow(
                        Icons.link_outlined,
                        'ウェブサイト',
                        websiteUrl,
                      ),
                      const SizedBox(height: 8),
                      _profileDetailRow(
                        isPublic ? Icons.public : Icons.lock_outlined,
                        '公開設定',
                        isPublic ? '公開' : '非公開',
                      ),
                      if (!hasProfile || missingFields.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF64748B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_outlined,
                                size: 16,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  !hasProfile
                                      ? 'プロフィールが未作成です。'
                                      : '未設定の項目: ${missingFields.join('、')}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '表示名',
                          prefixIcon: Icon(Icons.person_outlined, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: bioCtrl,
                        decoration: const InputDecoration(
                          labelText: '自己紹介',
                          prefixIcon: Icon(Icons.notes_outlined, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: '場所',
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: twitterCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Twitter/X (@なし)',
                          prefixIcon: Icon(Icons.alternate_email, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: githubCtrl,
                        decoration: const InputDecoration(
                          labelText: 'GitHub (@なし)',
                          prefixIcon: Icon(Icons.code, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: websiteCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ウェブサイト URL',
                          prefixIcon: Icon(Icons.link_outlined, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.public,
                            size: 16,
                            color: Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '公開プロフィール',
                            style: TextStyle(fontSize: 13, height: 1.6),
                          ),
                          const Spacer(),
                          Switch(
                            value: editIsPublic,
                            onChanged: (v) => setInner(() => editIsPublic = v),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _profileFieldRow(
                      Icons.calendar_today_outlined,
                      '登録日',
                      createdStr,
                    ),
                    const SizedBox(height: 4),
                    _profileFieldRow(
                      Icons.login_outlined,
                      '最終ログイン',
                      lastSignInStr,
                    ),
                    const SizedBox(height: 4),
                    _profileFieldRow(
                      isGoogle ? Icons.g_mobiledata : Icons.email_outlined,
                      '認証方法',
                      isGoogle ? 'Google OAuth' : 'メール/パスワード',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (editMode) {
                    setInner(() => editMode = false);
                  } else {
                    Navigator.pop(ctx2);
                  }
                },
                child: Text(editMode ? 'キャンセル' : '閉じる'),
              ),
              if (!editMode)
                TextButton.icon(
                  onPressed: () => setInner(() => editMode = true),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('編集'),
                )
              else
                FilledButton.icon(
                  onPressed: saving ? null : saveProfile,
                  icon: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFE5E7EB),
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 16),
                  label: Text(saving ? '保存中...' : '保存'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _profileFieldRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, height: 1.5),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  /// Profile detail row that shows "未設定" with a muted style for empty values.
  Widget _profileDetailRow(IconData icon, String label, String value) {
    final isEmpty = value.isEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14,
          color: isEmpty ? const Color(0xFFF87171) : const Color(0xFF9CA3AF),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
        Expanded(
          child: Text(
            isEmpty ? '未設定' : value,
            style: TextStyle(
              fontSize: 12,
              color: isEmpty ? const Color(0xFFF87171) : null,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
              height: 1.5,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRequestsAdminCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFFFFC107)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '機能リクエスト管理',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                Text(
                  '${_featureRequests.length}件',
                  style: const TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadFeatureRequests,
                  tooltip: '更新',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_featureRequestsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_featureRequests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'リクエストはまだありません',
                  style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _featureRequests.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final isDarkFR =
                      Theme.of(context).brightness == Brightness.dark;
                  final req = _featureRequests[index];
                  final id = req['id']?.toString() ?? '';
                  final title = req['title']?.toString() ?? '';
                  final email = req['email']?.toString();
                  final votes = _toInt(req['votes']);
                  final status = req['status']?.toString() ?? 'open';
                  final createdAt = req['created_at']?.toString() ?? '';
                  final adminReply = req['admin_reply']?.toString();
                  final adminRepliedAt = req['admin_replied_at']?.toString();
                  // R20: 年なし MM/dd は3か月前(04月)の要望を「今月」に見せる。
                  // 1か月超/別年は yyyy/ を前置して年齢を明示する。
                  final dateStr = formatAgeAwareDate(createdAt, DateTime.now());
                  String? repliedAtStr;
                  if (adminRepliedAt != null) {
                    try {
                      repliedAtStr = DateFormat(
                        'MM/dd HH:mm',
                      ).format(DateTime.parse(adminRepliedAt).toLocal());
                    } catch (_) {}
                  }

                  Color statusColor;
                  switch (status) {
                    case 'in_progress':
                      statusColor = const Color(0xFF6366F1);
                    case 'done':
                      statusColor = const Color(0xFF0D9488);
                    default:
                      statusColor = const Color(0xFFFF6B35);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: index < 3
                              ? (isDarkFR
                                  ? const Color(0xFF2A1C06)
                                  : const Color(0xFFFEF3C7))
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          child: Text(
                            '$votes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? (isDarkFR
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFF92400E))
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontSize: 13, height: 1.6),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 11, height: 1.5),
                            ),
                            if (adminReply != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF6366F1,
                                    ).withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Text(
                                  'AI返信済 $repliedAtStr',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6366F1),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: adminReply == null ? '返信する' : '返信を編集',
                              onPressed: () => _showSupportReplyDialog(req),
                              icon: Icon(
                                adminReply == null
                                    ? Icons.reply_outlined
                                    : Icons.edit_note_outlined,
                                size: 18,
                                color: const Color(0xFF4338CA),
                              ),
                            ),
                            IconButton(
                              tooltip: '優先度・工数・期日を設定',
                              onPressed: () => _showFeatureFieldsDialog(req),
                              icon: const Icon(
                                Icons.tune,
                                size: 18,
                                color: Color(0xFF3D5AFE),
                              ),
                            ),
                            PopupMenuButton<String>(
                              initialValue: status,
                              onSelected: (newStatus) =>
                                  _updateFeatureRequestStatus(
                                id,
                                newStatus,
                                title,
                                email,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Text('open'),
                                ),
                                PopupMenuItem(
                                  value: 'in_progress',
                                  child: Text('in_progress'),
                                ),
                                PopupMenuItem(
                                  value: 'done',
                                  child: Text('done'),
                                ),
                                PopupMenuItem(
                                  value: 'rejected',
                                  child: Text('rejected'),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.31),
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (adminReply != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'AI: $adminReply',
                              // R20: 数百字の返信が50件リストを支配する wall-of-text
                              // を抑制。全文は返信編集ダイアログで到達可能=無損失。
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4338CA),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationOpsCard() {
    final digest = _automationDigest ?? <String, dynamic>{};
    final users = digest['users'] is Map
        ? Map<String, dynamic>.from(digest['users'] as Map)
        : <String, dynamic>{};
    final featureRequests = digest['featureRequests'] is Map
        ? Map<String, dynamic>.from(digest['featureRequests'] as Map)
        : <String, dynamic>{};
    final recentAchievements =
        digest['recentAchievements'] as List? ?? const [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF4338CA)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '自動化オペレーション',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                if (_automationLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _automationPostingX ? null : _showXPostDialog,
                    icon: const Icon(Icons.send, size: 16),
                    label: Text(_automationPostingX ? '投稿中...' : 'X投稿テスト'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4338CA),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadAutomationOps,
                  tooltip: '更新',
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Claude Schedule の定期実行に合わせた CS キューと日次ダイジェストをここで手動確認できます。',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_automationError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFB91C1C).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  _automationError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB91C1C),
                    height: 1.5,
                  ),
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildAutomationMetricChip(
                    label: '総ユーザー',
                    value: '${_toInt(users['total'])}人',
                    color: const Color(0xFF6366F1),
                  ),
                  _buildAutomationMetricChip(
                    label: '新規要望',
                    value: '${_toInt(featureRequests['newToday'])}件',
                    color: const Color(0xFFFF6B35),
                  ),
                  _buildAutomationMetricChip(
                    label: '未対応要望',
                    value: '${_toInt(featureRequests['openCount'])}件',
                    color: const Color(0xFF6366F1),
                  ),
                  _buildAutomationMetricChip(
                    label: '直近実績',
                    value: '${recentAchievements.length}件',
                    color: const Color(0xFF0D9488),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'CSキュー (${_automationSupportTickets.length}件)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              if (_automationSupportTickets.isEmpty)
                const Text(
                  '未返信チケットはありません',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _automationSupportTickets.length > 5
                      ? 5
                      : _automationSupportTickets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ticket = _automationSupportTickets[index];
                    final title = ticket['title']?.toString() ?? '(無題)';
                    final votes = _toInt(ticket['votes']);
                    final email = ticket['email']?.toString();
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.07),
                        child: Text(
                          '$votes',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4338CA),
                            height: 1.5,
                          ),
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                      subtitle: Text(
                        email == null || email.isEmpty ? 'メール未登録' : email,
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                      trailing: TextButton(
                        onPressed: () => _showSupportReplyDialog(ticket),
                        child: const Text('返信'),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  // R29: 自動エラー報告 (error_reporter が hub_data へ無言送信していた caught
  // error) の可視化カード。0件なら「正常」を明示し、あれば直近を先頭行だけ出す。
  Widget _buildAutoErrorReportsCard() {
    final theme = Theme.of(context);
    final count = _autoErrorReports.length;
    final hasErrors = count > 0;
    final accent =
        hasErrors ? const Color(0xFFB45309) : const Color(0xFF0D9488);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasErrors
                      ? Icons.report_gmailerrorred
                      : Icons.verified_outlined,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    autoErrorReportsHealthLabel(count),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                      color: accent,
                    ),
                  ),
                ),
                if (_autoErrorReportsLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: '再取得',
                    onPressed: _loadRecentErrors,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasErrors
                  ? 'アプリが自動で捕捉・記録した例外です (公開 Issue 化はされません)。'
                      '本文は自分のセッション分のみ表示しています。'
                  : 'アプリが捕捉した例外は記録されていません。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasErrors) ...[
              const SizedBox(height: 10),
              ..._autoErrorReports.take(8).map((entry) {
                final when = formatAgeAwareDate(
                  entry.createdAt,
                  DateTime.now(),
                );
                final line =
                    entry.firstLine.isEmpty ? '(本文なし)' : entry.firstLine;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFFB45309),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        when,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (count > 8)
                Text(
                  'ほか ${count - 8}件',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutomationMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, height: 1.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitlistCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mail_outline, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'メールウェイトリスト (${_waitlistEmails.length}件)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                if (_sendingNotification)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _waitlistEmails.isEmpty
                        ? null
                        : _showNotificationComposeDialog,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('通知送信'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadWaitlist,
                  tooltip: '更新',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_waitlistLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_waitlistEmails.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '登録者はまだいません',
                  style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _waitlistEmails.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = _waitlistEmails[index];
                  final email = entry['email']?.toString() ?? '';
                  final source = entry['source']?.toString() ?? '';
                  final createdAt = entry['created_at']?.toString() ?? '';
                  String dateStr = createdAt;
                  try {
                    dateStr = DateFormat(
                      'MM/dd HH:mm',
                    ).format(DateTime.parse(createdAt).toLocal());
                  } catch (_) {}

                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.person_outline,
                      size: 20,
                      color: Color(0xFF6366F1),
                    ),
                    title: Text(
                      email,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                    subtitle: Text(
                      '$source  $dateStr',
                      style: const TextStyle(fontSize: 11, height: 1.5),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // ブログ投稿管理カード
  // -----------------------------------------------------------------------

  List<Map<String, dynamic>> _blogPosts = [];
  bool _blogPostsLoading = false;

  Future<void> _loadBlogPosts() async {
    setState(() => _blogPostsLoading = true);
    try {
      final data = await _supabase
          .from('blog_posts')
          .select(
            'id, title, status, target_platforms, draft_path, posted_at, url, created_at',
          )
          .order('created_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() {
          _blogPosts = List<Map<String, dynamic>>.from(data as List);
          _blogPostsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _blogPostsLoading = false);
    }
  }

  Future<void> _updateBlogPostStatus(String id, String newStatus) async {
    if (newStatus == 'posted') {
      // Ask for the published URL
      final urlController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('投稿URLを入力'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(
              hintText: 'https://zenn.dev/...',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await _supabase.from('blog_posts').update({
          'status': 'posted',
          'posted_at': DateTime.now().toIso8601String(),
          if (urlController.text.isNotEmpty) 'url': urlController.text.trim(),
        }).eq('id', id);
        await _loadBlogPosts();
      } catch (_) {}
      return;
    }
    try {
      await _supabase
          .from('blog_posts')
          .update({'status': newStatus}).eq('id', id);
      await _loadBlogPosts();
    } catch (_) {}
  }

  Widget _buildBlogPostsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor(String status) {
      switch (status) {
        case 'posted':
          return const Color(0xFF0D9488);
        case 'skipped':
          return const Color(0xFF9CA3AF);
        default:
          return const Color(0xFFFF6B35);
      }
    }

    String statusLabel(String status) {
      switch (status) {
        case 'posted':
          return '投稿済';
        case 'skipped':
          return 'スキップ';
        default:
          return '下書き';
      }
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ブログ投稿管理',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadBlogPosts,
                  tooltip: '更新',
                ),
              ],
            ),
            Text(
              'Claude Schedule が生成した下書き・投稿状況を管理',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_blogPostsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_blogPosts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'まだブログ下書きがありません。\nblog-draft Schedule タスクが実行されると自動追加されます。',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _blogPosts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final post = _blogPosts[index];
                  final status = post['status']?.toString() ?? 'draft';
                  final title = post['title']?.toString() ?? '(無題)';
                  final platforms = (post['target_platforms'] as List?)
                          ?.map((e) => e.toString())
                          .join(', ') ??
                      '';
                  final postUrl = post['url']?.toString() ?? '';
                  final createdAt = post['created_at'] != null
                      ? DateTime.tryParse(post['created_at'].toString())
                      : null;
                  final dateStr = createdAt != null
                      ? '${createdAt.month}/${createdAt.day}'
                      : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (platforms.isNotEmpty)
                                Text(
                                  '$platforms  $dateStr',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              if (postUrl.isNotEmpty)
                                GestureDetector(
                                  onTap: () => launchUrl(
                                    Uri.parse(postUrl),
                                    mode: LaunchMode.externalApplication,
                                  ),
                                  child: Text(
                                    postUrl,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF4338CA),
                                      decoration: TextDecoration.underline,
                                      height: 1.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          initialValue: status,
                          onSelected: (val) =>
                              _updateBlogPostStatus(post['id'].toString(), val),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'draft',
                              child: Text('下書き'),
                            ),
                            const PopupMenuItem(
                              value: 'posted',
                              child: Text('投稿済にする'),
                            ),
                            const PopupMenuItem(
                              value: 'skipped',
                              child: Text('スキップ'),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(
                                status,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  statusLabel(status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor(status),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color: statusColor(status),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // growth-achievement-summary
  // -----------------------------------------------------------------------

  Future<void> _loadComparisonCvr() async {
    if (!mounted) return;
    setState(() => _comparisonCvrLoading = true);
    try {
      final rows =
          await _supabase.from('app_analytics').select('source_details');
      final touches = <String, int>{};
      var signups = 0;
      for (final row in rows) {
        final sd = row['source_details'];
        if (sd is! Map) continue;
        sd.forEach((key, value) {
          final k = key.toString();
          final v = (value is num) ? value.toInt() : 0;
          if (k.startsWith('touch_comparison_')) {
            final competitor = k.replaceFirst('touch_comparison_', '');
            touches.update(competitor, (c) => c + v, ifAbsent: () => v);
          } else if (k == 'signup_submit_comparison') {
            signups += v;
          }
        });
      }
      if (mounted) {
        setState(() {
          _comparisonTouches = touches;
          _comparisonSignups = signups;
          _comparisonCvrLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _comparisonCvrLoading = false);
    }
  }

  Widget _buildComparisonCvrCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFE5E7EB);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);

    final totalTouches = _comparisonTouches.values.fold(0, (a, b) => a + b);
    // R30: 母数0で「0.0%」は計測した0%に見える捏造 → ダッシュボード共通の
    // formatRatePercent(母数0=「—」)に揃える。到達0で登録>0の自己矛盾表示も回避。
    final cvrLabel = formatRatePercent(_comparisonSignups, totalTouches);

    final sorted = _comparisonTouches.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Text(
                '比較ページ別 CVR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (_comparisonCvrLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _loadComparisonCvr,
                  tooltip: '更新',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _cvrStat(
                '総到達数',
                totalTouches.toString(),
                const Color(0xFFA78BFA),
              ),
              const SizedBox(width: 16),
              _cvrStat(
                '比較経由登録',
                _comparisonSignups.toString(),
                const Color(0xFF059669),
              ),
              const SizedBox(width: 16),
              _cvrStat('CVR', cvrLabel, const Color(0xFFFF6B35)),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty && !_comparisonCvrLoading)
            const Text(
              '比較ページへの到達データがまだありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
                height: 1.6,
              ),
            )
          else
            ...sorted.take(14).map((e) {
              final pct = totalTouches > 0 ? e.value / totalTouches : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: isDark
                              ? const Color(0x1FE5E7EB)
                              : const Color(0xFF6366F1),
                          color: const Color(0xFF6366F1),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      e.value.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _cvrStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Future<void> _loadGrowthSummary({String? since, String? label}) async {
    if (!mounted) return;
    if (_supabase.auth.currentUser == null) {
      setState(() => _growthSummaryLoading = false);
      return;
    }
    setState(() => _growthSummaryLoading = true);
    try {
      final resp = await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'achievement.list',
          'since': since ?? '2020-01-01T00:00:00Z',
          'label': label ?? 'すべて',
        },
      );
      if (mounted) {
        setState(() {
          _growthSummary = resp.data as Map<String, dynamic>?;
          _growthSummaryLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _growthSummaryLoading = false);
    }
  }

  /// R17: X 学習ループ(growth-hub x.performance_context)を意思決定点へ露出する
  /// read-only カード。データ無しは SizedBox.shrink() で静かに消える。空(bestVariant
  /// が既定 'daily_briefing' に落ちる)を勝ち型に見せないため、必ず非空ガードの内側。
  Widget _buildXGrowthLoopSection() {
    final perf = _xPerformanceContext;
    if (perf == null) return const SizedBox.shrink();
    final rows = perf['rows'] is List ? perf['rows'] as List : const [];
    final comparableRows = rows.where((row) {
      return row is! Map || row['learningCohort'] != 'historical_benchmark';
    }).toList();
    final variants = perf['variants'] is List ? perf['variants'] as List : null;
    final historicalBenchmarks = perf['historicalBenchmarks'] is List
        ? perf['historicalBenchmarks'] as List
        : const [];
    final comparisonSampleCount = perf.containsKey('comparisonSampleCount')
        ? _toInt(perf['comparisonSampleCount'])
        : comparableRows.length;
    final loop = resolveXGrowthLoop(
      measuredCount: comparisonSampleCount,
      distinctVariantCount: distinctMeasuredVariants(variants),
      postedTodayCount: _toInt(_xTodayStatus?['postedTodayCount']),
    );
    if (loop.state == XGrowthLoopState.hidden && historicalBenchmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    // R20: 鮮度はパネル自身のデータ(perf-context 行)から出す。旧実装は今日の投稿の
    // 計測時刻を読み、12件計測済みでも今日未投稿だと「計測待ち」と矛盾していた。
    final newestMeasuredAt = newestMeasuredCreatedAt(comparableRows);
    final freshness = resolveXGrowthLoopFreshness(
      measuredCount: comparisonSampleCount,
      newestMeasuredAt: newestMeasuredAt,
      now: DateTime.now(),
    );
    // R27: 鮮度が3日を超えたら灰色フッター任せにせず警告行で知らせる
    // (unlocked 以降は awaitingMetrics の cron 警告経路が二度と出ないため)。
    final stalenessWarning = xGrowthLoopStalenessWarning(
      measuredCount: comparisonSampleCount,
      newestMeasuredAt: newestMeasuredAt,
      now: DateTime.now(),
    );
    final lines = <Widget>[];
    if (stalenessWarning != null) {
      lines.add(
        _growthLoopLine(
          Icons.warning_amber_rounded,
          const Color(0xFFF59E0B),
          stalenessWarning,
        ),
      );
    }

    switch (loop.state) {
      case XGrowthLoopState.awaitingMetrics:
        lines.add(
          _growthLoopLine(
            Icons.warning_amber_rounded,
            const Color(0xFFF59E0B),
            '本日の投稿はまだ計測されていません。spend-cap 到達や metrics 収集 cron の'
            '停止で計測が止まっていないか確認してください（console.x.com の支出上限）。',
          ),
        );
        break;
      case XGrowthLoopState.sampling:
        lines.add(
          _growthLoopLine(
            Icons.hourglass_bottom,
            const Color(0xFF6366F1),
            '学習サンプル ${loop.measuredCount}件（variant ${loop.distinctVariantCount}種）。'
            '勝ちパターンの比較表示まで、あと数投稿ぶんのデータが必要です。',
          ),
        );
        break;
      case XGrowthLoopState.unlocked:
        // R27: サーバが「unknown」(タグ無し投稿の受け皿バケット)を勝ち型として
        // 返す除外漏れへの防御。variants から unknown 除外で勝ち型を再解決する。
        final bestVariant = resolveDisplayBestVariant(
          perf['bestVariant']?.toString(),
          variants,
        );
        if (bestVariant != null) {
          lines.add(
            _growthLoopLine(
              Icons.emoji_events_outlined,
              const Color(0xFF0D9488),
              '今の勝ち型: $bestVariant',
            ),
          );
        }
        for (final line in _xGrowthVariantRankingLines(variants)) {
          lines.add(
            _growthLoopLine(
              Icons.leaderboard_outlined,
              const Color(0xFF6366F1),
              line,
            ),
          );
        }
        final winnerHook = _xGrowthWinnerHook(perf['winners']);
        if (winnerHook != null) {
          lines.add(
            _growthLoopLine(
              Icons.format_quote,
              const Color(0xFF9CA3AF),
              '真似る型: $winnerHook',
            ),
          );
        }
        break;
      case XGrowthLoopState.hidden:
        break;
    }

    // R25: 内容アーキタイプ別実測(R23 Archetype lift)。sampling 中でも型別の
    // 実測は意思決定材料になるため state に依らず rows から出す。勝ち型は
    // 実測バケット(n>=2・unknown 除く)が2種以上のときだけ主張する(edge と
    // 同じ誠実性閾値)。
    final archetypeEntries = resolveArchetypeLift(rows);
    final archetypeWinner = archetypeLiftWinner(archetypeEntries);
    if (archetypeWinner != null) {
      lines.add(
        _growthLoopLine(
          Icons.emoji_events,
          const Color(0xFF0EA5E9),
          '勝ちアーキタイプ: ${archetypeWinner.label}'
          '（72時間経過後の平均${archetypeWinner.averageImpressions} imp）'
          '— 次の投稿はこの型で',
        ),
      );
    }
    final archetypeSummary = archetypeLiftSummaryLine(archetypeEntries);
    if (archetypeSummary != null) {
      lines.add(
        _growthLoopLine(
          Icons.category_outlined,
          const Color(0xFF0EA5E9),
          archetypeSummary,
        ),
      );
    }
    if (historicalBenchmarks.isNotEmpty && historicalBenchmarks.first is Map) {
      final benchmark = historicalBenchmarks.first as Map;
      final impressions = _toInt(benchmark['historicalBenchmarkImpressions']);
      final archetype = (benchmark['archetype'] ?? 'unknown').toString();
      final label = kArchetypeLiftLabels[archetype] ?? archetype;
      if (impressions > 0) {
        lines.add(
          _growthLoopLine(
            Icons.history,
            const Color(0xFF64748B),
            '参考ベンチマーク（累積実測・I72比較外）: $label '
            '${NumberFormat.decimalPattern('ja_JP').format(impressions)} imp',
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.insights,
                    size: 18,
                    color: Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'X 成長ループ（計測から勝ち型を学ぶ）',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...lines,
              const SizedBox(height: 8),
              Text(
                freshness,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// R26: X投稿候補キュー(トラッカー量産の HITL 承認面)。系列 cron が生成した
  /// pending_approval 候補を一覧し、全文確認→承認→投稿→確定を1画面で回す。
  /// 候補ゼロ or X operator 権限なし(list が空 degrade)は panel ごと非表示。
  Widget _buildXCandidateQueueSection() {
    if (_xCandidates.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // #4080: 鮮度切れ候補は「承認して投稿」が無効化済み = キューに滞留して
    // 見るべき候補を埋没させる。まとめて終端 status へ落とせるようにする。
    final now = DateTime.now();
    final staleCandidates = _xCandidates
        .where((candidate) => isCandidateExpired(candidate, now))
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pending_actions,
                    size: 18,
                    color: Color(0xFF0EA5E9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'X投稿候補キュー（${candidateQueueHeaderLabel(_xCandidates, totalsByStatus: _xCandidateTotals)}）',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (staleCandidates.isNotEmpty)
                    TextButton.icon(
                      onPressed: _xCandidateRejecting
                          ? null
                          : () => _rejectStaleXCandidates(staleCandidates),
                      icon: _xCandidateRejecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.block, size: 16),
                      label: Text('鮮度切れ${staleCandidates.length}件を却下'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'トラッカー系列の自動生成候補。承認した本文だけが投稿され、'
                '計測ループ（Archetype lift）の対象になります。',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 12),
              ..._xCandidates.map(_buildXCandidateRow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXCandidateRow(XPostCandidateSummary candidate) {
    final theme = Theme.of(context);
    final publishing = _xCandidatePublishing.contains(candidate.id);
    final now = DateTime.now();
    final age = candidateAgeLabel(candidate.generatedAt, now);
    // 鮮度切れ (news_briefing 24h / data_report 72h / 既定7日) の候補は
    // 承認ボタンを無効化し、古いニュースの誤投稿を防ぐ。
    final expired = isCandidateExpired(candidate, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        candidate.seriesLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0369A1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (candidate.archetype.isNotEmpty)
                      Text(
                        candidate.archetype,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    if (!candidate.isPendingApproval)
                      Text(
                        candidate.statusLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (age.isNotEmpty)
                      Text(
                        age,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    if (expired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFEF4444,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '鮮度切れ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  candidatePreviewText(candidate.text),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: publishing || !candidate.isActionable || expired
                ? null
                : () => _publishXCandidate(candidate),
            child: publishing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(expired ? '鮮度切れ' : '承認して投稿'),
          ),
        ],
      ),
    );
  }

  Widget _growthLoopLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// variants(平均スコア降順)から上位3種を「{variant} 平均{score} (n={count})」に。
  List<String> _xGrowthVariantRankingLines(List<dynamic>? variants) {
    // R28: 勝ち型と同じ畳み込み (unknown 除外 + `_fallback` を base へ) 済みの
    // ランキングを出す。畳まないと「勝ち型: daily_briefing」なのに直下の
    // ランキング先頭が「daily_briefing_fallback 平均89」という矛盾表示になる。
    final folded = foldVariantsForDisplay(variants);
    final lines = <String>[];
    for (final entry in folded) {
      lines.add('${entry.variant} 平均${entry.averageScore} (n=${entry.count})');
      if (lines.length >= 3) break;
    }
    return lines;
  }

  String? _xGrowthWinnerHook(dynamic winners) {
    if (winners is! List || winners.isEmpty) return null;
    final first = winners.first;
    if (first is! Map) return null;
    final text = (first['text'] ?? '').toString().trim();
    if (text.isEmpty) return null;
    return text.length <= 60 ? text : '${text.substring(0, 58)}…';
  }

  Widget _buildGrowthAchievementSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFE5E7EB);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);

    final periods = [
      (
        '今日',
        DateTime.now()
            .copyWith(hour: 0, minute: 0, second: 0)
            .toIso8601String(),
      ),
      (
        '今週',
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
      ),
      (
        '今月',
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      ),
      ('すべて', '2020-01-01T00:00:00Z'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'グロース実績サマリー',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              if (_growthSummaryLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _loadGrowthSummary,
                  tooltip: '再読み込み',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Period selector
          Wrap(
            spacing: 8,
            children: periods.map((p) {
              final (lbl, since) = p;
              return ActionChip(
                label: Text(
                  lbl,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () => _loadGrowthSummary(since: since, label: lbl),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_growthSummary == null && !_growthSummaryLoading)
            const Text(
              'データなし',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.6,
              ),
            )
          // R30: 期待するメトリクスキーが無いレスポンス(achievement.list は
          // items のみ返す)では捏造ゼロを出さず、集計未接続を正直に示す。
          else if (!growthSummaryHasMetrics(_growthSummary) &&
              !_growthSummaryLoading)
            const Text(
              '成長サマリーの集計はまだ接続されていません。'
              '各カード(登録目標・累計登録・比較CVR等)で実数をご確認ください。',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.6,
              ),
            )
          else if (growthSummaryHasMetrics(_growthSummary)) ...[
            Text(
              '期間: ${_growthSummary!['label'] ?? 'すべて'}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _growthStatRow(
              '新規ユーザー',
              '${_growthSummary!['newUsers'] ?? 0}人',
              const Color(0xFF6366F1),
            ),
            _growthStatRow(
              '累計ユーザー',
              '${_growthSummary!['totalUsersEver'] ?? 0}人',
              const Color(0xFF10B981),
            ),
            _growthStatRow(
              '成長シグナル',
              '${_growthSummary!['acquisitionSignals'] ?? 0}件',
              const Color(0xFFF59E0B),
            ),
            _growthStatRow(
              '紹介成立',
              '${_growthSummary!['referralsCompleted'] ?? 0}件',
              const Color(0xFFEC4899),
            ),
            _growthStatRow(
              'インポート試行',
              '${_growthSummary!['importPreviews'] ?? 0}件',
              const Color(0xFF0EA5E9),
            ),
          ],
        ],
      ),
    );
  }

  Widget _growthStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFeedbackCard() {
    final newCount = _appFeedbacks.where((f) => f['status'] == 'new').length;
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー行
            Row(
              children: [
                const Icon(
                  Icons.feedback_outlined,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ユーザーフィードバック',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                if (newCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB91C1C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '未対応 $newCount',
                      style: const TextStyle(
                        color: Color(0xFFE5E7EB),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _loadAppFeedbacks,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 件数サマリー
            if (!_appFeedbacksLoading) ...[
              Row(
                children: [
                  _feedbackCountChip('未対応', newCount, const Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  _feedbackCountChip(
                    '確認済',
                    _appFeedbacks
                        .where((f) => f['status'] == 'reviewed')
                        .length,
                    const Color(0xFFFF6B35),
                  ),
                  const SizedBox(width: 8),
                  _feedbackCountChip(
                    '対応完',
                    _appFeedbacks
                        .where((f) => f['status'] == 'implemented')
                        .length,
                    const Color(0xFF0D9488),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 最新フィードバックインライン表示
            if (_appFeedbacksLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_appFeedbacks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'フィードバックはまだありません',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              )
            else
              ...(_appFeedbacks
                  .take(5)
                  .map((fb) => _buildFeedbackInlineRow(fb))),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('全${_appFeedbacks.length}件を管理する'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/admin-feedback'),
                    builder: (_) => const FeedbackListPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildFeedbackInlineRow(Map<String, dynamic> fb) {
    final status = fb['status'] as String? ?? 'new';
    final category = fb['category'] as String? ?? 'other';
    final content = fb['content'] as String? ?? '';
    final issueUrl = fb['github_issue_url'] as String?;
    final id = fb['id'] as int;

    final statusColor = status == 'new'
        ? const Color(0xFFB91C1C)
        : status == 'reviewed'
            ? const Color(0xFFFF6B35)
            : const Color(0xFF0D9488);
    final categoryIcon = category == 'feature'
        ? Icons.lightbulb_outline
        : category == 'bug'
            ? Icons.bug_report_outlined
            : Icons.chat_bubble_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  categoryIcon,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status == 'new'
                        ? '未対応'
                        : status == 'reviewed'
                            ? '確認済'
                            : '対応完',
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (issueUrl != null) ...[
              const SizedBox(height: 4),
              Text(
                'Issue: $issueUrl',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (status == 'new') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _updateFeedbackStatus(id, 'reviewed'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '確認済にする',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => _updateFeedbackStatus(id, 'implemented'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF0D9488),
                    ),
                    child: const Text(
                      '対応完了',
                      style: TextStyle(fontSize: 11, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
