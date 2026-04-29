import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/growth_mission_service.dart';
import '../widgets/schedule_task_monitor_card.dart';
import '../widgets/competitor_monitoring_card.dart';
import '../widgets/self_devin_control_tower_card.dart';
import 'ai_secretary_page.dart';
import 'admin/feedback_list_page.dart';
import 'admin/quota_dashboard_page.dart';
import 'admin/blog_management_page.dart';
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
  WeeklyDigestSnapshot _weeklyDigest = const WeeklyDigestSnapshot.empty();
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
    _loadWeeklyDigest();
    _loadFeatureRequests();
    _loadWaitlist();
    _loadAdminUsers();
    _loadAutomationOps();
    _loadBlogPosts();
    _loadGrowthSummary();
    _loadComparisonCvr();
    _loadAppFeedbacks();
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
      if (mounted) setState(() => _weeklyDigest = digest);
    } catch (e) {
      debugPrint('weekly digest load error: $e');
    }
  }

  Future<void> _loadFeatureRequests() async {
    if (!mounted) return;
    setState(() => _featureRequestsLoading = true);
    try {
      final data = await _supabase
          .from('feature_requests')
          .select(
            'id, title, description, email, votes, status, created_at, admin_reply, admin_replied_at',
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
        throw Exception(
          '${digestResult?['error'] ?? 'digest load failed'}',
        );
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
        SnackBar(
          content: Text(
            escalate ? 'チケットをエスカレーションしました' : '返信を送信しました',
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('返信文を入力してください')),
      );
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
        body: {
          'action': 'x.post',
          'text': text,
          'dryRun': dryRun,
        },
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$email に通知を送信しました')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingNotification = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('通知送信に失敗しました: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$sent 件に送信しました')),
        );
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
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
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
        await _supabase
            .from('app_analytics')
            .delete()
            .eq('date', dateKey)
            .select();
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
            backgroundColor: const Color(0xFFB91C1C),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          '経営分析ダッシュボード',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: const Color(0xFFE5E7EB),
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
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
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
                    _buildToolExecutionGuardCard(),
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
    final accentColor =
        achieved ? const Color(0xFF0D9488) : const Color(0xFFB91C1C);
    final todayCvr =
        todayViews == 0 ? 0.0 : (todayRegistrations / todayViews * 100);
    final diagnosisLabel = achieved
        ? '登録発生'
        : todayViews == 0
            ? '流入不足'
            : growthAction.bottleneckLabel;
    final diagnosisColor = achieved
        ? const Color(0xFF0D9488)
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: achieved
              ? (isDark
                  ? const [Color(0xFF0D2E1A), Color(0xFF0A1F12)]
                  : const [Color(0xFFE8F5E9), Color(0xFFF6FFF7)])
              : (isDark
                  ? const [Color(0xFF2E0A0A), Color(0xFF1F0808)]
                  : const [Color(0xFFFFEBEE), Color(0xFFFFF8F8)]),
        ),
        borderRadius: BorderRadius.circular(12),
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
                    Text(
                      '今日の登録目標',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
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
                    height: 1.5,
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMiniKpiChip(
                label: '今日のLP View数',
                value: '$todayViews',
                color: const Color(0xFF6366F1),
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
                  color: const Color(0xFF0D9488),
                ),
              if (todayViews > 0)
                _buildMiniKpiChip(
                  label: '今日送信',
                  value: '${todayFunnel.magicLinkSends}',
                  color: const Color(0xFFFF6B35),
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
                  color: const Color(0xFF475569),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            achieved ? statusText : '$statusText あと$remaining人の登録が必要です。',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.7,
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
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          actionDetail,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: diagnosisColor,
                            foregroundColor: const Color(0xFFE5E7EB),
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
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.5,
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
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LP流入後の途中離脱を切り分けるためのファネルです。どこで止まっているかを先に確認します。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
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
                  color: const Color(0xFF6366F1),
                ),
                _buildFunnelStepItem(
                  label: '体験実行',
                  value: '${funnel.trialRuns}',
                  icon: Icons.play_circle_outline,
                  color: const Color(0xFF0D9488),
                ),
                _buildFunnelStepItem(
                  label: '保存CTA',
                  value: '${funnel.saveClicks}',
                  icon: Icons.save_outlined,
                  color: const Color(0xFF6366F1),
                ),
                _buildFunnelStepItem(
                  label: 'Magic Link送信',
                  value: '${funnel.magicLinkSends}',
                  icon: Icons.mail_outline,
                  color: const Color(0xFF7C3AED),
                ),
                _buildFunnelStepItem(
                  label: '受信箱を開く',
                  value: '${funnel.inboxOpens}',
                  icon: Icons.mark_email_read_outlined,
                  color: const Color(0xFFFF6B35),
                ),
                _buildFunnelStepItem(
                  label: '実登録',
                  value: '$registrations',
                  icon: Icons.person_add,
                  color: const Color(0xFF0D9488),
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
                  color: const Color(0xFF0D9488),
                ),
                _buildMiniKpiChip(
                  label: '体験→保存率',
                  value: _formatRate(funnel.saveClicks, funnel.trialRuns),
                  color: const Color(0xFF6366F1),
                ),
                _buildMiniKpiChip(
                  label: '保存→送信率',
                  value: _formatRate(funnel.magicLinkSends, funnel.saveClicks),
                  color: const Color(0xFF7C3AED),
                ),
                _buildMiniKpiChip(
                  label: '送信→登録率',
                  value: _formatRate(registrations, funnel.magicLinkSends),
                  color: const Color(0xFF0D9488),
                ),
                if (remainingRegistrations > 0)
                  _buildMiniKpiChip(
                    label: '最大ボトルネック',
                    value: funnelAction.bottleneckLabel,
                    color: const Color(0xFF475569),
                  ),
                if (remainingRegistrations > 0)
                  _buildMiniKpiChip(
                    label: '目標達成に必要な送信',
                    value: '$neededMagicLinks件',
                    color: const Color(0xFFB91C1C),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
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
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '登録管理の追加指標',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'LP View以外に、体験前離脱・継続未達・直近流量をまとめて確認します。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniKpiChip(
                  label: '今日の体験前離脱',
                  value: '$todayDropBeforeTrial',
                  color: const Color(0xFF0D9488),
                ),
                _buildMiniKpiChip(
                  label: '30日体験前離脱',
                  value: '$totalDropBeforeTrial',
                  color: const Color(0xFF475569),
                ),
                _buildMiniKpiChip(
                  label: '連続登録ゼロ日',
                  value: '$zeroRegistrationStreakDays日',
                  color: const Color(0xFFB91C1C),
                ),
                _buildMiniKpiChip(
                  label: '直近7日平均LP',
                  value: averageViewsLast7Days.toStringAsFixed(1),
                  color: const Color(0xFF6366F1),
                ),
                _buildMiniKpiChip(
                  label: '30日体験率',
                  value: totalTrialRate,
                  color: const Color(0xFF0D9488),
                ),
                _buildMiniKpiChip(
                  label: '直近登録効率',
                  value: registrationsPerLpView == null
                      ? '登録未発生'
                      : '$registrationsPerLpView LP/登録',
                  color: const Color(0xFF6366F1),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.7,
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
      return Card(
        elevation: 1,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'agent_tool_execution_logs のデータがありません。マイグレーション適用後に表示されます。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
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
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  color: const Color(0xFF0D9488),
                ),
                _buildMiniKpiChip(
                  label: 'Blocked',
                  value: '$_blockedToolExecutionCount',
                  color: const Color(0xFFB91C1C),
                ),
                _buildMiniKpiChip(
                  label: 'Blocked Rate',
                  value: '${blockedRate.toStringAsFixed(1)}%',
                  color: const Color(0xFFFF6B35),
                ),
              ],
            ),
            if (_blockedReasonBreakdown.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Blocked Reasons',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
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
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB91C1C),
                              height: 1.5,
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
                          backgroundColor: const Color(0xFFB91C1C).withValues(
                            alpha: 0.08,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFB91C1C),
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
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
                      ? const Color(0xFF0D9488).withValues(alpha: 0.05)
                      : const Color(0xFFB91C1C).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allowed
                        ? const Color(0xFF0D9488).withValues(alpha: 0.2)
                        : const Color(0xFFB91C1C).withValues(alpha: 0.25),
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
                          color: allowed
                              ? const Color(0xFF0D9488)
                              : const Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            toolName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    if (!allowed) ...[
                      const SizedBox(height: 8),
                      Text(
                        reasonText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
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
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
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
      case 'public_memo_share':
        return 'Public memo share';
      case 'public_memo_copy':
        return 'Public memo copy';
      case 'touch_landing':
        return 'Landing touch';
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
      case 'public_memo_share':
        return const Color(0xFFFF6B35);
      case 'public_memo_copy':
        return const Color(0xFFFFA000);
      case 'touch_landing':
        return const Color(0xFF475569);
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
                  hasData
                      ? '${d.currentWeekStart} 〜 ${d.currentWeekEnd}'
                      : '読み込み中...',
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
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
                      height: 1.5,
                    ),
                  ),
                  Text(
                    'CVR',
                    style: TextStyle(
                      fontSize: 10,
                      color: _getCvrColor(cvr),
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
    final complete =
        _adminUsers.where((u) => _toInt(u['completionPct']) >= 67).length;
    final partial = _adminUsers.where((u) {
      final pct = _toInt(u['completionPct']);
      return pct >= 34 && pct < 67;
    }).length;
    final empty =
        _adminUsers.where((u) => _toInt(u['completionPct']) < 34).length;
    return Row(
      children: [
        _profileStatChip(
          Icons.check_circle,
          '$complete 完成',
          const Color(0xFF0D9488),
        ),
        const SizedBox(width: 8),
        _profileStatChip(
          Icons.pending,
          '$partial 途中',
          const Color(0xFFFF6B35),
        ),
        const SizedBox(width: 8),
        _profileStatChip(
          Icons.warning_amber,
          '$empty 未設定',
          const Color(0xFFB91C1C),
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
                    '登録ユーザー管理 (合計 $_adminUsersTotal 人)',
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
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
              ),
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
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
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
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
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
                      final createdAt = user['createdAt']?.toString() ?? '';
                      final lastSignIn = user['lastSignInAt']?.toString() ?? '';
                      final hasProfile = user['hasProfile'] as bool? ?? false;
                      final completionPct = _toInt(user['completionPct']);

                      String createdStr = '';
                      String lastSignInStr = '';
                      try {
                        createdStr = DateFormat('yyyy/MM/dd').format(
                          DateTime.parse(createdAt).toLocal(),
                        );
                      } catch (_) {}
                      try {
                        lastSignInStr = DateFormat('MM/dd HH:mm').format(
                          DateTime.parse(lastSignIn).toLocal(),
                        );
                      } catch (_) {}

                      final isGoogle = provider.contains('google');
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;

                      Color profileColor;
                      if (!hasProfile || completionPct < 34) {
                        profileColor = const Color(0xFFB91C1C);
                      } else if (completionPct < 67) {
                        profileColor = const Color(0xFFFF6B35);
                      } else {
                        profileColor = const Color(0xFF0D9488);
                      }

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
                                email.isNotEmpty ? email[0].toUpperCase() : '?',
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
                                              : email,
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
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isGoogle ? 'Google' : 'Email',
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: completionPct / 100,
                                            minHeight: 4,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              profileColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'プロフィール $completionPct%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: profileColor,
                                          fontWeight: FontWeight.w600,
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
                                        foregroundColor:
                                            const Color(0xFF3949AB),
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
    final createdAt = user['createdAt']?.toString() ?? '';
    final lastSignIn = user['lastSignInAt']?.toString() ?? '';

    String createdStr = '';
    String lastSignInStr = '';
    try {
      createdStr = DateFormat('yyyy/MM/dd HH:mm').format(
        DateTime.parse(createdAt).toLocal(),
      );
    } catch (_) {}
    try {
      lastSignInStr = DateFormat('yyyy/MM/dd HH:mm').format(
        DateTime.parse(lastSignIn).toLocal(),
      );
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
                ScaffoldMessenger.of(ctx2).showSnackBar(
                  const SnackBar(content: Text('プロフィールを更新しました')),
                );
              }
            } catch (e) {
              if (ctx2.mounted) {
                setInner(() => saving = false);
                ScaffoldMessenger.of(ctx2).showSnackBar(
                  SnackBar(content: Text('更新失敗: $e')),
                );
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
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.5,
                      ),
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
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
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
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                        ),
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
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                        ),
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
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                        ),
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
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                        ),
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
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                        ),
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
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                        ),
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
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                            ),
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
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
            ),
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
                const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFFFFC107),
                ),
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
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
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
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
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
                  String dateStr = createdAt;
                  try {
                    dateStr = DateFormat('MM/dd')
                        .format(DateTime.parse(createdAt).toLocal());
                  } catch (_) {}
                  String? repliedAtStr;
                  if (adminRepliedAt != null) {
                    try {
                      repliedAtStr = DateFormat('MM/dd HH:mm')
                          .format(DateTime.parse(adminRepliedAt).toLocal());
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
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          child: Text(
                            '$votes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: index < 3
                                  ? (isDarkFR
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFF92400E))
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                            if (adminReply != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.24),
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
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'AI: $adminReply',
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
                        backgroundColor:
                            const Color(0xFF6366F1).withValues(alpha: 0.07),
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
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      subtitle: Text(
                        email == null || email.isEmpty ? 'メール未登録' : email,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                        ),
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
            style: TextStyle(
              fontSize: 11,
              color: color,
              height: 1.5,
            ),
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
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
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
                    dateStr = DateFormat('MM/dd HH:mm').format(
                      DateTime.parse(createdAt).toLocal(),
                    );
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
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    subtitle: Text(
                      '$source  $dateStr',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                      ),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              color:
                                  statusColor(status).withValues(alpha: 0.08),
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
    final cvrPct = totalTouches > 0
        ? (_comparisonSignups / totalTouches * 100).toStringAsFixed(1)
        : '0.0';

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
              _cvrStat('CVR', '$cvrPct%', const Color(0xFFFF6B35)),
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

  Widget _buildGrowthAchievementSummaryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFE5E7EB);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);

    final periods = [
      (
        '今日',
        DateTime.now().copyWith(hour: 0, minute: 0, second: 0).toIso8601String()
      ),
      (
        '今週',
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String()
      ),
      (
        '今月',
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String()
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
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                  ),
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
          else if (_growthSummary != null) ...[
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
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
              ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  MaterialPageRoute(builder: (_) => const FeedbackListPage()),
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
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                      ),
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
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                      ),
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
