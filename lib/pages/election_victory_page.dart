import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/local_election_plan.dart';
import '../models/local_election_reality.dart';
import '../models/public_memo.dart';
import '../services/local_election_plan_service.dart';
import '../utils/web_image_downloader.dart';
import '../services/local_election_reality_service.dart';
import '../services/local_election_share_service.dart';
import '../services/public_memo_service.dart';
import '../widgets/election_japan_map.dart';
import '../widgets/election_progress_chart.dart';
import '../widgets/election_regional_kpi_chart.dart';
import '../widgets/election_news_badge.dart';
import '../widgets/election_x_post_composer_dialog.dart';

class ElectionVictoryPage extends StatefulWidget {
  final bool publicView;

  const ElectionVictoryPage({
    super.key,
    this.publicView = false,
  });

  @override
  State<ElectionVictoryPage> createState() => _ElectionVictoryPageState();
}

class _ElectionVictoryPageState extends State<ElectionVictoryPage> {
  static const String _allLabel = 'すべて';
  static const String _allAssemblyCategories = 'all';
  static const String _publicLocalElectionDashboardUrl =
      'https://my-web-app-b67f4.web.app/public/local-election-700';
  static const int _memberPageSize = 24;
  static const int _lowPresenceThreshold = 4;
  static const int _pastElectionOutcomeAccordionThreshold = 4;
  static const int _pastElectionBreakdownAccordionThreshold = 6;
  static const int _pastElectionCandidateAccordionThreshold = 4;
  static const List<String> _allPrefectures = <String>[
    '北海道',
    '青森県',
    '岩手県',
    '宮城県',
    '秋田県',
    '山形県',
    '福島県',
    '茨城県',
    '栃木県',
    '群馬県',
    '埼玉県',
    '千葉県',
    '東京都',
    '神奈川県',
    '新潟県',
    '富山県',
    '石川県',
    '福井県',
    '山梨県',
    '長野県',
    '岐阜県',
    '静岡県',
    '愛知県',
    '三重県',
    '滋賀県',
    '京都府',
    '大阪府',
    '兵庫県',
    '奈良県',
    '和歌山県',
    '鳥取県',
    '島根県',
    '岡山県',
    '広島県',
    '山口県',
    '徳島県',
    '香川県',
    '愛媛県',
    '高知県',
    '福岡県',
    '佐賀県',
    '長崎県',
    '熊本県',
    '大分県',
    '宮崎県',
    '鹿児島県',
    '沖縄県',
  ];

  final LocalElectionPlanService _service = const LocalElectionPlanService();
  final LocalElectionRealityService _realityService =
      const LocalElectionRealityService();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _historySectionKey = GlobalKey(debugLabel: 'realityHistory');
  final GlobalKey _scheduleSectionKey =
      GlobalKey(debugLabel: 'scheduleCalendar');
  final GlobalKey _rosterSectionKey = GlobalKey(debugLabel: 'memberRoster');
  late final PublicMemoService _publicMemoService =
      PublicMemoService(Supabase.instance.client);
  late final LocalElectionShareService _shareService =
      LocalElectionShareService(
    Supabase.instance.client,
    publishMemo: _publicMemoService.upsertMemo,
    loadMemo: _publicMemoService.getUserPublicMemoByNoteId,
  );
  final DateFormat _dateTimeFormat = DateFormat('yyyy/MM/dd HH:mm', 'ja_JP');
  final DateFormat _dateOnlyFormat = DateFormat('yyyy/MM/dd', 'ja_JP');
  final NumberFormat _numberFormat = NumberFormat('#,##0', 'ja_JP');

  LocalElectionPlanDashboard? _plan;
  LocalElectionRealitySnapshot? _realitySnapshot;
  final Map<String, LocalElectionLegislatorProfile> _memberProfileOverrides =
      <String, LocalElectionLegislatorProfile>{};
  final Set<String> _memberProfileLoadingUrls = <String>{};
  final Map<String, String> _memberProfileErrors = <String, String>{};
  PublicMemo? _publishedSnapshotMemo;
  PublicMemo? _publishedKpiMemo;
  bool _isLoading = true;
  bool _isRealityLoading = false;
  bool _isPublishingSnapshotMemo = false;
  bool _isPublishingKpiMemo = false;
  bool _isGeminiLoading = false;
  String? _realityError;
  String? _geminiAnalysisResult;
  bool _appliedInitialPrefectureFilter = false;
  String _selectedRegion = _allLabel;
  String _selectedMemberPrefecture = _allLabel;
  String _selectedMemberAssemblyCategory = _allAssemblyCategories;
  int _visibleMemberCount = _memberPageSize;
  List<LocalElectionRealityHistoryPoint> _realityHistory =
      const <LocalElectionRealityHistoryPoint>[];
  List<Map<String, dynamic>> _pastElectionResults =
      const <Map<String, dynamic>>[];
  CalendarFormat _scheduleCalendarFormat = CalendarFormat.month;
  DateTime _scheduleFocusedDay = DateTime.now();
  DateTime? _selectedScheduleDay;
  bool _showPastSchedules = false;
  String _selectedScheduleFilter = _allLabel;
  static final List<String> _scheduleFilters = <String>[
    _allLabel,
    ...LocalElectionShareService.availableWindows.map((window) => window.label),
  ];

  bool get _isPublicView => widget.publicView;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    final results = await Future.wait<dynamic>([
      _service.loadPlan(),
      _realityService.loadCachedSnapshot(),
      _realityService.loadSnapshotHistory(),
    ]);
    if (!mounted) {
      return;
    }

    var plan = results[0] as LocalElectionPlanDashboard;
    final cachedSnapshot = results[1] as LocalElectionRealitySnapshot?;
    final cachedHistory = results[2] as List<LocalElectionRealityHistoryPoint>;

    if (cachedSnapshot != null && cachedSnapshot.hasData) {
      plan = await _syncPlanWithSnapshot(
        plan,
        cachedSnapshot,
        persist: !_isPublicView,
      );
      if (!mounted) {
        return;
      }
    }

    setState(() {
      _plan = plan;
      _realitySnapshot = cachedSnapshot;
      _realityHistory = cachedHistory;
      _publishedSnapshotMemo = null;
      _publishedKpiMemo = null;
      _applyInitialPrefectureFilter(plan);
      if (!plan.regionLabels.contains(_selectedRegion)) {
        _selectedRegion = _allLabel;
      }
      _syncMemberSelection(cachedSnapshot);
      _syncScheduleSelection(cachedSnapshot);
      _isLoading = false;
    });

    unawaited(_loadPublishedSnapshotMemo(cachedSnapshot));
    unawaited(_loadPublishedKpiMemo());
    unawaited(_refreshRealityData(showSnackBar: false));
  }

  Future<void> _loadPlan() async {
    var plan = await _service.loadPlan();
    final snapshot = _realitySnapshot;
    if (snapshot != null && snapshot.hasData) {
      plan = await _syncPlanWithSnapshot(
        plan,
        snapshot,
        persist: !_isPublicView,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _plan = plan;
      _applyInitialPrefectureFilter(plan);
      if (!plan.regionLabels.contains(_selectedRegion)) {
        _selectedRegion = _allLabel;
      }
      _isLoading = false;
    });
  }

  void _applyInitialPrefectureFilter(LocalElectionPlanDashboard plan) {
    if (_appliedInitialPrefectureFilter) {
      return;
    }
    _appliedInitialPrefectureFilter = true;
    final requestedPrefecture = Uri.base.queryParameters['prefecture']?.trim();
    if (requestedPrefecture == null || requestedPrefecture.isEmpty) {
      return;
    }

    final target = _normalizePrefectureKey(requestedPrefecture);
    for (final item in plan.prefectures) {
      if (_normalizePrefectureKey(item.prefecture) == target) {
        _selectedRegion = item.region;
        return;
      }
    }
  }

  Future<void> _refreshAll() async {
    await _loadPlan();
    await _refreshRealityData(showSnackBar: false, forceRefresh: true);
  }

  void _syncMemberSelection(LocalElectionRealitySnapshot? snapshot) {
    if (snapshot == null) {
      _selectedMemberPrefecture = _allLabel;
      _visibleMemberCount = _memberPageSize;
      return;
    }
    final prefectureLabels = <String>{
      _allLabel,
      ...snapshot.members.map((item) => item.prefecture).where(
            (item) => item.trim().isNotEmpty,
          ),
    };
    if (!prefectureLabels.contains(_selectedMemberPrefecture)) {
      _selectedMemberPrefecture = _allLabel;
    }
  }

  void _syncScheduleSelection(LocalElectionRealitySnapshot? snapshot) {
    final selectedDay = _bestScheduleSelection(snapshot);
    _selectedScheduleDay = selectedDay;
    _scheduleFocusedDay = selectedDay ?? _normalizeDate(DateTime.now());
  }

  DateTime? _bestScheduleSelection(LocalElectionRealitySnapshot? snapshot) {
    if (snapshot == null || snapshot.targetElectionSchedules.isEmpty) {
      return null;
    }

    final normalizedCurrent = _selectedScheduleDay == null
        ? null
        : _normalizeDate(_selectedScheduleDay!);
    if (normalizedCurrent != null &&
        _scheduleEventsForDay(snapshot, normalizedCurrent).isNotEmpty) {
      return normalizedCurrent;
    }

    final now = _normalizeDate(DateTime.now());
    final upcoming = _sortedScheduleEntries(snapshot);
    for (final item in upcoming) {
      final voteDate = item.parsedVoteDate;
      if (voteDate == null) {
        continue;
      }
      final normalized = _normalizeDate(voteDate.toLocal());
      if (!normalized.isBefore(now)) {
        return normalized;
      }
    }

    final firstDate = upcoming.first.parsedVoteDate;
    if (firstDate == null) {
      return now;
    }
    return _normalizeDate(firstDate.toLocal());
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  List<String> _memberPrefectureOptions(LocalElectionRealitySnapshot snapshot) {
    final labels = snapshot.members
        .map((item) => item.prefecture)
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return <String>[_allLabel, ...labels];
  }

  LocalElectionLegislatorProfile _resolveRosterMember(
    LocalElectionLegislatorProfile member,
  ) {
    return member.mergeWith(_memberProfileOverrides[member.detailUrl]);
  }

  List<LocalElectionLegislatorProfile> _filteredRosterMembers(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final filtered = snapshot.members
        .where((member) {
          if (_selectedMemberPrefecture != _allLabel &&
              member.prefecture != _selectedMemberPrefecture) {
            return false;
          }
          if (_selectedMemberAssemblyCategory != _allAssemblyCategories &&
              member.assemblyCategory != _selectedMemberAssemblyCategory) {
            return false;
          }
          return true;
        })
        .map(_resolveRosterMember)
        .toList();

    return _sortRosterMembers(filtered);
  }

  List<LocalElectionLegislatorProfile> _sortRosterMembers(
    List<LocalElectionLegislatorProfile> members,
  ) {
    int categoryRank(String value) {
      switch (value) {
        case 'prefectural':
          return 0;
        case 'municipal':
          return 1;
        default:
          return 2;
      }
    }

    final sorted = List<LocalElectionLegislatorProfile>.from(members);
    sorted.sort((left, right) {
      final prefectureCompare = left.prefecture.compareTo(right.prefecture);
      if (prefectureCompare != 0) {
        return prefectureCompare;
      }
      final categoryCompare = categoryRank(left.assemblyCategory) -
          categoryRank(right.assemblyCategory);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return left.name.compareTo(right.name);
    });
    return sorted;
  }

  Future<void> _loadMemberProfile(
    LocalElectionLegislatorProfile member, {
    bool forceRefresh = false,
  }) async {
    final detailUrl = member.detailUrl.trim();
    if (detailUrl.isEmpty || _memberProfileLoadingUrls.contains(detailUrl)) {
      return;
    }

    if (!forceRefresh) {
      final cached = await _realityService.loadCachedMemberProfile(detailUrl);
      if (!mounted) {
        return;
      }
      if (cached != null) {
        setState(() {
          _memberProfileOverrides[detailUrl] = member.mergeWith(cached);
          _memberProfileErrors.remove(detailUrl);
        });
        if (cached.hasDetailedProfile) {
          return;
        }
      }
    }

    setState(() {
      _memberProfileLoadingUrls.add(detailUrl);
      _memberProfileErrors.remove(detailUrl);
    });

    try {
      final profile = await _realityService.fetchMemberProfile(
        detailUrl,
        prefectureHint: member.prefecture,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _memberProfileOverrides[detailUrl] = member.mergeWith(profile);
        _memberProfileErrors.remove(detailUrl);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _memberProfileErrors[detailUrl] =
            '議員プロフィールの取得に失敗しました。しばらくしてから再試行してください。';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('議員プロフィールの取得に失敗しました'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _memberProfileLoadingUrls.remove(detailUrl);
        });
      }
    }
  }

  void _showMoreMembers() {
    setState(() {
      _visibleMemberCount += _memberPageSize;
    });
  }

  Future<void> _loadPublishedKpiMemo() async {
    final memo = await _shareService.loadPublishedPlanDashboard();
    if (!mounted) {
      return;
    }
    setState(() {
      _publishedKpiMemo = memo;
    });
  }

  Future<void> _loadPublishedSnapshotMemo(
    LocalElectionRealitySnapshot? snapshot,
  ) async {
    if (snapshot == null || !snapshot.hasData) {
      if (!mounted) {
        return;
      }
      setState(() {
        _publishedSnapshotMemo = null;
      });
      return;
    }
    final memo = await _shareService.loadPublishedSnapshot(snapshot);
    if (!mounted) {
      return;
    }
    if (_realitySnapshot?.fetchedAt != snapshot.fetchedAt) {
      return;
    }
    setState(() {
      _publishedSnapshotMemo = memo;
    });
  }

  Future<void> _refreshRealityData({
    required bool showSnackBar,
    bool forceRefresh = false,
  }) async {
    if (_isRealityLoading) {
      return;
    }
    setState(() {
      _isRealityLoading = true;
      _realityError = null;
    });

    try {
      final snapshot = await _realityService.fetchLatestSnapshot(
        includeAiSummary: false,
        includeCdpBenchmarks: false,
        forceRefresh: forceRefresh,
      );
      final history = await _realityService.loadSnapshotHistory();
      LocalElectionPlanDashboard? syncedPlan;
      if (_plan != null && snapshot.hasData) {
        syncedPlan = await _syncPlanWithSnapshot(
          _plan!,
          snapshot,
          persist: !_isPublicView,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (syncedPlan != null) {
          _plan = syncedPlan;
          if (!syncedPlan.regionLabels.contains(_selectedRegion)) {
            _selectedRegion = _allLabel;
          }
        }
        _realitySnapshot = snapshot;
        _realityHistory = history;
        _realityError = null;
        _publishedSnapshotMemo = null;
        _publishedKpiMemo = null;
        _syncMemberSelection(snapshot);
        _syncScheduleSelection(snapshot);
      });
      unawaited(_loadPublishedSnapshotMemo(snapshot));
      unawaited(_loadPublishedKpiMemo());
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '最新の実データを取得しました '
              '${syncedPlan != null ? ' / 県連KPIを自動更新しました ' : ''}'
              '(${_dateTimeFormat.format(snapshot.fetchedAt.toLocal())})',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _describeRealityError(error);
      setState(() {
        _realityError = message;
      });
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRealityLoading = false;
        });
      }
    }
  }

  Future<LocalElectionPlanDashboard> _syncPlanWithSnapshot(
    LocalElectionPlanDashboard plan,
    LocalElectionRealitySnapshot snapshot, {
    required bool persist,
  }) async {
    final syncedPlan = _service.buildAutoUpdatedPlan(
      plan,
      snapshot,
      now: snapshot.fetchedAt,
    );
    if (!persist) {
      return syncedPlan;
    }
    return _service.savePlan(syncedPlan);
  }

  Future<void> _runGeminiAnalysis() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    if (_isGeminiLoading) return;
    setState(() {
      _isGeminiLoading = true;
      _geminiAnalysisResult = null;
    });
    try {
      final resp = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'election.analyze'},
      );
      final data = resp.data;
      String result;
      if (data is Map) {
        final politicians =
            (data['politicians'] as List<dynamic>?)?.length ?? 0;
        final raw = data as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _pastElectionResults =
                (raw['pastElectionResults'] as List<dynamic>? ?? [])
                    .whereType<Map<String, dynamic>>()
                    .toList();
          });
        }
        final total = ((raw['monthlyKpi']
                as Map<String, dynamic>?)?['currentTotal'] as num?)
            ?.toInt();
        result = 'Gemini AI 分析完了\n'
            '取得議員数: $politicians 人${total != null ? ' / 目標700 残り${700 - total}人' : ''}';
      } else {
        result = data?.toString() ?? '分析結果なし';
      }
      if (!mounted) return;
      setState(() => _geminiAnalysisResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini AI 分析が完了しました')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _geminiAnalysisResult = 'エラー: $e');
    } finally {
      if (mounted) setState(() => _isGeminiLoading = false);
    }
  }

  Future<void> _copySummary() async {
    final plan = _plan;
    if (plan == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: _buildClipboardSummary(plan)));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('管理サマリーをクリップボードにコピーしました')),
    );
  }

  Future<void> _copyPublicDashboardLink() async {
    await Clipboard.setData(
      const ClipboardData(text: _publicLocalElectionDashboardUrl),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('公開ダッシュボードURLをコピーしました')),
    );
  }

  Future<PublicMemo?> _publishKpiMemo({
    bool openAfterPublish = false,
  }) async {
    final plan = _plan;
    if (plan == null) {
      return null;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('共有ノート化にはログインが必要です。公開URLは未ログインでも共有できます'),
          ),
        );
      }
      return null;
    }
    if (_isPublishingKpiMemo) {
      return _publishedKpiMemo;
    }

    setState(() {
      _isPublishingKpiMemo = true;
    });

    try {
      final snapshot =
          _realitySnapshot?.hasData == true ? _realitySnapshot : null;
      final memo = await _shareService.publishPlanDashboard(
        plan: plan,
        snapshot: snapshot,
        publicDashboardUrl: _publicLocalElectionDashboardUrl,
      );
      if (!mounted) {
        return memo;
      }
      if (memo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('全県連KPI共有ノートの作成に失敗しました')),
        );
        return null;
      }
      setState(() {
        _publishedKpiMemo = memo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('全県連KPI共有ノートを更新しました')),
      );
      if (openAfterPublish) {
        await Navigator.of(context).pushNamed('/public-memo?id=${memo.id}');
      }
      return memo;
    } finally {
      if (mounted) {
        setState(() {
          _isPublishingKpiMemo = false;
        });
      }
    }
  }

  Future<PublicMemo?> _publishSnapshotMemo({
    bool openAfterPublish = false,
  }) async {
    final snapshot = _realitySnapshot;
    if (snapshot == null || !snapshot.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最新の実データ取得後に地方議員集計をノート化できます')),
      );
      return null;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('地方議員集計のノート化にはログインが必要です'),
        ),
      );
      return null;
    }
    if (_isPublishingSnapshotMemo) {
      return _publishedSnapshotMemo;
    }

    setState(() {
      _isPublishingSnapshotMemo = true;
    });

    try {
      final memo = await _shareService.publishSnapshot(
        snapshot: snapshot,
        members: snapshot.members,
      );
      if (!mounted) {
        return memo;
      }
      if (memo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('地方議員集計ノートの作成に失敗しました')),
        );
        return null;
      }
      setState(() {
        _publishedSnapshotMemo = memo;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地方議員集計ノートを更新しました')),
      );
      if (openAfterPublish) {
        await Navigator.of(context).pushNamed('/public-memo?id=${memo.id}');
      }
      return memo;
    } finally {
      if (mounted) {
        setState(() {
          _isPublishingSnapshotMemo = false;
        });
      }
    }
  }

  Future<void> _copyKpiMemoLink() async {
    final memo = _publishedKpiMemo ?? await _publishKpiMemo();
    if (memo == null) {
      return;
    }
    final url = PublicMemoService.buildPublicMemoUrl(memo.id);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('全県連KPI共有ノートのリンクをコピーしました')),
    );
  }

  Future<void> _copySnapshotMemoLink() async {
    final memo = _publishedSnapshotMemo ?? await _publishSnapshotMemo();
    if (memo == null) {
      return;
    }
    final url = PublicMemoService.buildPublicMemoUrl(memo.id);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('地方議員集計ノートのリンクをコピーしました')),
    );
  }

  Future<void> _shareKpiMemoOnX() async {
    final plan = _plan;
    if (plan == null) {
      return;
    }
    final memo = _publishedKpiMemo ?? await _publishKpiMemo();
    final publicUrl = memo == null
        ? _publicLocalElectionDashboardUrl
        : PublicMemoService.buildPublicMemoUrl(memo.id);
    final uri = _shareService.buildPlanDashboardXShareIntentUri(
      plan: plan,
      publicUrl: publicUrl,
    );
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      final text = _shareService.buildPlanDashboardXShareText(
        plan: plan,
        publicUrl: publicUrl,
      );
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('X投稿画面を開けなかったため、投稿文をコピーしました'),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Xの投稿画面を開きました')),
    );
  }

  Future<void> _openElectionXPostComposer() async {
    final snapshot = _realitySnapshot;
    if (snapshot == null || !snapshot.hasData) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('最新の実データ取得後に地方選ポストを作成できます'),
        ),
      );
      return;
    }

    await ElectionXPostComposerDialog.show(
      context,
      snapshot: snapshot,
      shareService: _shareService,
      publishedMemo: _publishedSnapshotMemo,
      initialWindowIndex: _filterToWindowIndex(_selectedScheduleFilter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isPublicView ? '統一地方選700 公開ダッシュボード' : '統一地方選700 必達管理室'),
        actions: [
          if (!_isPublicView)
            IconButton(
              onPressed: _isGeminiLoading ? null : _runGeminiAnalysis,
              tooltip: 'Gemini AI 分析',
              icon: _isGeminiLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
            ),
          if (!_isPublicView)
            IconButton(
              onPressed: plan == null ? null : _copySummary,
              tooltip: '管理サマリーをコピー',
              icon: const Icon(Icons.content_copy),
            ),
          IconButton(
            onPressed: _isRealityLoading
                ? null
                : () => _refreshRealityData(
                      showSnackBar: true,
                      forceRefresh: true,
                    ),
            tooltip: '最新の実データを取得',
            icon: _isRealityLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
        ],
      ),
      body: _isLoading || plan == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshAll,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_isPublicView) ...[
                    _buildPublicViewNotice(),
                    const SizedBox(height: 16),
                  ],
                  _buildHeroCard(plan),
                  const SizedBox(height: 16),
                  _buildRealitySection(plan),
                  const SizedBox(height: 16),
                  _buildCdpBenchmarkSection(plan),
                  const SizedBox(height: 16),
                  _buildChartSection(plan),
                  const SizedBox(height: 16),
                  _buildAlertStrip(plan),
                  const SizedBox(height: 24),
                  _buildSummaryGrid(plan),
                  const SizedBox(height: 24),
                  _buildTopPrioritySection(plan),
                  const SizedBox(height: 24),
                  _buildMonthlySection(plan),
                  const SizedBox(height: 24),
                  _buildRegionFilter(plan),
                  const SizedBox(height: 12),
                  _buildPrefectureAccordion(plan),
                  const SizedBox(height: 24),
                  Text(
                    '注記: 実データは公式議員ページと2023年の公式選挙結果ページを '
                    'Supabase Edge Function が巡回して取得します。'
                    'AIコメントは公式データの整理用で、未取得時は固定ロジックの要約へフォールバックします。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '注記: 初期配分と月次KPIはテンプレート計算です。'
                    '2026年4月から2027年3月までの管理ボードとして、各県連の実数で上書きして使う前提です。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeroCard(LocalElectionPlanDashboard plan) {
    final theme = Theme.of(context);
    final snapshot = _realitySnapshot;
    final hasSnapshot = snapshot?.hasData == true;
    final officialCount = hasSnapshot
        ? snapshot!.officialCurrentLocalMembers
        : plan.currentLocalMembers;
    final gapToTarget = hasSnapshot
        ? snapshot!.actualNetIncreaseRequired
        : plan.requiredNetIncrease;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '2027年春の統一地方選に向けた管理型ダッシュボード',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSnapshot
                  ? '計画基準 ${_formatInt(plan.currentLocalMembers)}人に対し、'
                      '公式議員ページの最新集計は ${_formatInt(officialCount)}人です。'
                      '700人まで残り ${_formatInt(gapToTarget)}人を、'
                      '${_isPublicView ? '県連別配分と月次KPIの公開ビューで確認できます。' : '県連別配分と月次KPIで管理します。'}'
                  : '現在 ${_formatInt(plan.currentLocalMembers)}人から '
                      '${_formatInt(plan.targetLocalMembers)}人へ。'
                      '必要純増 ${_formatInt(plan.requiredNetIncrease)}人を、'
                      '${_isPublicView ? '県連別配分と月次KPIの公開ビューで確認できます。' : '県連別配分と月次KPIで管理します。'}',
              style: theme.textTheme.bodyMedium,
            ),
            if (hasSnapshot) ...[
              const SizedBox(height: 8),
              Text(
                '最新取得 ${_dateTimeFormat.format(snapshot!.fetchedAt.toLocal())}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildHeroMetric(
                  label: '計画現在',
                  value: _formatInt(plan.currentLocalMembers),
                  color: const Color(0xFF0F766E),
                ),
                _buildHeroMetric(
                  label: '公式現在',
                  value: _formatInt(officialCount),
                  color: const Color(0xFF0891B2),
                ),
                _buildHeroMetric(
                  label: '目標',
                  value: _formatInt(plan.targetLocalMembers),
                  color: const Color(0xFF2563EB),
                ),
                _buildHeroMetric(
                  label: '残り必要純増',
                  value: _formatInt(gapToTarget),
                  color: const Color(0xFFB91C1C),
                ),
                _buildHeroMetric(
                  label: '2023実績',
                  value:
                      '${plan.previousUnifiedElectionFirstHalfWins}+${plan.previousUnifiedElectionSecondHalfWins}',
                  color: const Color(0xFF7C3AED),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublicViewNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D4ED8).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '公開URLで閲覧できる固定ページです',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'この公開ビューは未ログインでも閲覧できます。'
            '県連別配分・月次KPI・現職名簿・最新の公式実データを確認できますが、'
            '計画の編集やテンプレート再適用は管理用ルートからのみ行えます。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SelectableText(
                _publicLocalElectionDashboardUrl,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              OutlinedButton.icon(
                onPressed: _copyPublicDashboardLink,
                icon: const Icon(Icons.link),
                label: const Text('URLコピー'),
              ),
            ],
          ),
          if (!_isPublicView) ...[
            const SizedBox(height: 8),
            Text(
              '未ログインの人にはこの公開URLを渡してください。Firebase Hosting のリライトで、直接URLからこの画面を開けます。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRealitySection(LocalElectionPlanDashboard plan) {
    final snapshot = _realitySnapshot;
    final realitySnapshot = snapshot?.hasData == true ? snapshot : null;
    final hasSnapshot = realitySnapshot != null;
    final activePrefectures = hasSnapshot
        ? realitySnapshot.prefectures
            .where((item) => item.currentMembers > 0)
            .length
        : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Win版#132 part 129: 9 ボタンの Wrap が無制限幅で
                // 「最新の実データ」テキスト Expanded を 0 幅に潰し、
                // 縦書き 1 文字 / 行に崩れる bug の修正.
                // 900px 以上なら横並び (= Row + Flexible 5:7) /
                // 未満なら縦積み (= Column / 旧来の挙動).
                final wide = constraints.maxWidth >= 900;
                final textColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最新の実データ',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasSnapshot
                          ? '公式議員ページと2023年の公式選挙結果ページを取得して、'
                              'AIで各県連の現職人数・目標擁立数・予定選挙数・公認期限を自動更新します。'
                          : 'まだ最新データを取得できていません。'
                              'ネット経由で公式ソースを再取得すると、'
                              '計画値とのズレを把握できます。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
                final actionWrap = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: wide ? WrapAlignment.end : WrapAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _copyPublicDashboardLink,
                      icon: const Icon(Icons.link),
                      label: const Text('公開URLコピー'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed:
                          _isPublishingSnapshotMemo || realitySnapshot == null
                              ? null
                              : () => _publishSnapshotMemo(
                                    openAfterPublish: true,
                                  ),
                      icon: _isPublishingSnapshotMemo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.summarize_outlined),
                      label: Text(
                        _isPublishingSnapshotMemo ? '集計ノート作成中' : '地方議員集計ノート化',
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _isPublishingKpiMemo
                          ? null
                          : () => _publishKpiMemo(openAfterPublish: true),
                      icon: _isPublishingKpiMemo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.public),
                      label: Text(
                        _isPublishingKpiMemo ? '共有ノート作成中' : '全県連KPIノート化',
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed:
                          _isPublishingSnapshotMemo || realitySnapshot == null
                              ? null
                              : _copySnapshotMemoLink,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('集計ノートリンクコピー'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _isPublishingKpiMemo ? null : _copyKpiMemoLink,
                      icon: const Icon(Icons.copy_all),
                      label: const Text('KPIノートリンクコピー'),
                    ),
                    FilledButton.icon(
                      onPressed: _isRealityLoading || realitySnapshot == null
                          ? null
                          : _openElectionXPostComposer,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('選挙ポスト作成'),
                    ),
                    FilledButton.icon(
                      onPressed: _isPublishingKpiMemo ? null : _shareKpiMemoOnX,
                      icon: const Icon(Icons.alternate_email),
                      label: const Text('X共有'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _isRealityLoading
                          ? null
                          : () => _refreshRealityData(
                                showSnackBar: true,
                                forceRefresh: true,
                              ),
                      icon: _isRealityLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isRealityLoading ? '取得中' : '最新取得'),
                    ),
                  ],
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(flex: 5, child: textColumn),
                      const SizedBox(width: 12),
                      Flexible(flex: 7, child: actionWrap),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textColumn,
                    const SizedBox(height: 12),
                    actionWrap,
                  ],
                );
              },
            ),
            if (realitySnapshot != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip(
                    realitySnapshot.isStale ? 'キャッシュ表示中' : '最新取得済み',
                    color: realitySnapshot.isStale
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF4CAF50),
                  ),
                  _buildStatusChip(
                    '取得日時 ${_dateTimeFormat.format(realitySnapshot.fetchedAt.toLocal())}',
                    color: const Color(0xFF607D8B),
                  ),
                  if (_publishedSnapshotMemo != null)
                    _buildStatusChip(
                      '地方議員集計ノート準備済み',
                      color: const Color(0xFF0891B2),
                    ),
                  if (_publishedKpiMemo != null)
                    _buildStatusChip(
                      '全県連KPI共有ノート準備済み',
                      color: const Color(0xFF3D5AFE),
                    ),
                  if (plan.prefectures.any(
                    (item) => item.autoUpdatedAt.isNotEmpty,
                  ))
                    _buildStatusChip(
                      '県連KPI自動更新済み',
                      color: const Color(0xFF10B981),
                    ),
                  if (!_isPublicView)
                    _buildStatusChip(
                      'AI自動更新専用',
                      color: const Color(0xFF7C3AED),
                    ),
                ],
              ),
            ],
            if (_realityError != null) ...[
              const SizedBox(height: 12),
              _buildInlineNotice(
                _realityError!,
                color: const Color(0xFFFF6B35),
                icon: Icons.info_outline,
              ),
            ],
            const SizedBox(height: 16),
            if (realitySnapshot == null && _isRealityLoading)
              const Center(child: CircularProgressIndicator())
            else if (realitySnapshot == null)
              _buildEmptyRealityState()
            else ...[
              if (_isPublicView) ...[
                _buildPublicRealityNavigator(realitySnapshot),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSummaryCard(
                    title: '公式地方議員数',
                    value:
                        _formatInt(realitySnapshot.officialCurrentLocalMembers),
                    subtitle: '議員ページ集計',
                    color: const Color(0xFF0891B2),
                  ),
                  _buildSummaryCard(
                    title: '基準340との差分',
                    value: _formatSignedInt(realitySnapshot.deltaFromBaseline),
                    subtitle: '初期前提とのズレ',
                    color: realitySnapshot.deltaFromBaseline >= 0
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFB91C1C),
                  ),
                  _buildSummaryCard(
                    title: '実数基準の残り',
                    value:
                        _formatInt(realitySnapshot.actualNetIncreaseRequired),
                    subtitle: '700人まで',
                    color: const Color(0xFFB91C1C),
                  ),
                  _buildSummaryCard(
                    title: '議員在籍県数',
                    value: _formatInt(activePrefectures),
                    subtitle: '公式ページで確認できた県',
                    color: const Color(0xFF7C3AED),
                  ),
                  _buildSummaryCard(
                    title: '2023前半戦',
                    value: _formatInt(
                      realitySnapshot.official2023FirstHalfWins,
                    ),
                    subtitle: '公式結果ベース',
                    color: const Color(0xFFB45309),
                  ),
                  _buildSummaryCard(
                    title: '2023後半戦',
                    value: _formatInt(
                      realitySnapshot.official2023SecondHalfWins,
                    ),
                    subtitle: '公式結果ベース',
                    color: const Color(0xFFBE123C),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildRealityHistorySection(realitySnapshot),
              const SizedBox(height: 20),
              _buildAiInsightSection(realitySnapshot),
              const SizedBox(height: 20),
              _buildRealityPrefectureSection(realitySnapshot),
              const SizedBox(height: 20),
              _buildScheduleSection(realitySnapshot),
              if (_displayPastElectionResults(realitySnapshot).isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildPastElectionResultsSection(realitySnapshot),
              ],
              const SizedBox(height: 20),
              _buildMemberRosterSection(realitySnapshot),
              const SizedBox(height: 20),
              _buildSourceSection(realitySnapshot),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRealityState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF607D8B).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF607D8B).withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ネットからの最新取得待ち',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '公式ソースから地方議員数と2023年実績を再取得すると、'
            '計画値と実数のズレ、上位県、AI要約がここに表示されます。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPublicRealityNavigator(LocalElectionRealitySnapshot snapshot) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '公開ビューの見どころ',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '地方議員数推移グラフ、地方選挙カレンダー、現職地方議員一覧を公開ビューから直接確認できます。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                '推移 ${_formatInt(_historyPointsForDisplay(snapshot).length)} 点',
                color: const Color(0xFF0891B2),
              ),
              _buildStatusChip(
                '日程 ${_formatInt(snapshot.targetElectionSchedules.length)} 件',
                color: const Color(0xFF2563EB),
              ),
              _buildStatusChip(
                '名簿 ${_formatInt(snapshot.rosterCount)} 人',
                color: const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _scrollToSection(_historySectionKey),
                icon: const Icon(Icons.show_chart),
                label: const Text('議員数推移'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _scrollToSection(_scheduleSectionKey),
                icon: const Icon(Icons.calendar_month),
                label: const Text('選挙カレンダー'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _scrollToSection(_rosterSectionKey),
                icon: const Icon(Icons.groups_2_outlined),
                label: const Text('地方議員一覧'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<LocalElectionRealityHistoryPoint> _historyPointsForDisplay(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final history = List<LocalElectionRealityHistoryPoint>.from(_realityHistory)
      ..sort((left, right) => left.fetchedAt.compareTo(right.fetchedAt));

    if (!snapshot.hasData) {
      return history;
    }

    final currentPoint = LocalElectionRealityHistoryPoint(
      fetchedAt: snapshot.fetchedAt,
      officialCurrentLocalMembers: snapshot.officialCurrentLocalMembers,
      actualNetIncreaseRequired: snapshot.actualNetIncreaseRequired,
    );
    final currentDay = _normalizeDate(currentPoint.fetchedAt.toLocal());

    if (history.isEmpty) {
      return <LocalElectionRealityHistoryPoint>[currentPoint];
    }

    final hasCurrentDay = history.any(
      (item) => _normalizeDate(item.fetchedAt.toLocal()) == currentDay,
    );
    if (!hasCurrentDay) {
      history.add(currentPoint);
      history.sort((left, right) => left.fetchedAt.compareTo(right.fetchedAt));
    }

    return history;
  }

  Widget _buildRealityHistorySection(LocalElectionRealitySnapshot snapshot) {
    final history = _historyPointsForDisplay(snapshot);
    final latestPoint = history.isEmpty ? null : history.last;
    final maxCount = history.isEmpty
        ? snapshot.officialCurrentLocalMembers
        : history
            .map((item) => item.officialCurrentLocalMembers)
            .reduce((left, right) => left > right ? left : right);
    final minCount = history.isEmpty
        ? snapshot.officialCurrentLocalMembers
        : history
            .map((item) => item.officialCurrentLocalMembers)
            .reduce((left, right) => left < right ? left : right);

    return Column(
      key: _historySectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '地方議員数推移',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'ネット取得した公式地方議員数をこの端末で日次履歴として蓄積し、時系列で表示します。取得回数が増えるほど推移グラフが育ちます。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              '履歴 ${_formatInt(history.length)} 点',
              color: const Color(0xFF607D8B),
            ),
            if (latestPoint != null)
              _buildStatusChip(
                '最新 ${_formatInt(latestPoint.officialCurrentLocalMembers)} 人',
                color: const Color(0xFF0891B2),
              ),
            _buildStatusChip(
              '最大 ${_formatInt(maxCount)} 人',
              color: const Color(0xFF0F766E),
            ),
            _buildStatusChip(
              '最小 ${_formatInt(minCount)} 人',
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          _buildInlineNotice(
            '履歴グラフを描くためのデータがまだありません。最新実データの取得を続けると、ここに地方議員数の推移が蓄積されます。',
            color: const Color(0xFF607D8B),
            icon: Icons.show_chart,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 240,
                  child: _buildRealityHistoryChart(history),
                ),
                if (history.length < 2) ...[
                  const SizedBox(height: 12),
                  _buildInlineNotice(
                    '履歴がまだ1点です。次回以降の取得で時系列の線が伸びます。',
                    color: const Color(0xFF607D8B),
                    icon: Icons.timeline,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRealityHistoryChart(
    List<LocalElectionRealityHistoryPoint> history,
  ) {
    final spots = history.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.officialCurrentLocalMembers.toDouble(),
      );
    }).toList(growable: false);
    final minCount = history
        .map((item) => item.officialCurrentLocalMembers)
        .reduce((left, right) => left < right ? left : right);
    final maxCount = history
        .map((item) => item.officialCurrentLocalMembers)
        .reduce((left, right) => left > right ? left : right);
    final minY = minCount <= 10 ? 0.0 : (minCount - 5).toDouble();
    final maxY = (maxCount + 5).toDouble();
    final maxX = history.length <= 1 ? 1.0 : (history.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0.0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFF607D8B).withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            bottom: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= history.length) {
                  return const SizedBox.shrink();
                }
                final point = history[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('M/d').format(point.fetchedAt.toLocal()),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= history.length) {
                  return null;
                }
                final point = history[index];
                return LineTooltipItem(
                  '${_dateOnlyFormat.format(point.fetchedAt.toLocal())}\n'
                  '${_formatInt(point.officialCurrentLocalMembers)} 人',
                  const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: history.length > 2,
            color: const Color(0xFF0891B2),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF0891B2),
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0891B2).withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsightSection(LocalElectionRealitySnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_geminiAnalysisResult != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1565C0).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: Color(0xFF1565C0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _geminiAnalysisResult!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF1565C0),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          'AI整理メモ',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.aiSummary.isEmpty
                    ? '公式データの要約はまだありません。'
                    : snapshot.aiSummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (snapshot.aiAlerts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '注視ポイント',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (final item in snapshot.aiAlerts) _buildBulletLine(item),
              ],
              if (snapshot.aiStrategicNotes.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  '運用メモ',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                for (final item in snapshot.aiStrategicNotes)
                  _buildBulletLine(item),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRealityPrefectureSection(LocalElectionRealitySnapshot snapshot) {
    final prefectures = _prefecturesForDisplay(snapshot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '公式集計の全都道府県',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '地方議員 0 人の県は赤、$_lowPresenceThreshold 人以下の県は黄で表示しています。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PrefectureLegendChip(
              label: '通常',
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHigh,
              borderColor: Theme.of(context).colorScheme.outlineVariant,
            ),
            const _PrefectureLegendChip(
              label: '要強化',
              backgroundColor: Color(0xFFFFF4CC),
              borderColor: Color(0xFFE0A800),
            ),
            const _PrefectureLegendChip(
              label: '議員不在',
              backgroundColor: Color(0xFFFDE2E1),
              borderColor: Color(0xFFD92D20),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in prefectures)
              SizedBox(
                width: 250,
                child: Card(
                  color: _prefectureCardBackgroundColor(context, item),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _prefectureCardBorderColor(context, item),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
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
                                    item.prefecture,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                  if (_prefectureStatusLabel(item)
                                      case final label?)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _prefectureBadgeBackgroundColor(
                                            context,
                                            item,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                _prefectureBadgeForegroundColor(
                                              context,
                                              item,
                                            ),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (item.sourceUrl.isNotEmpty)
                              IconButton(
                                onPressed: () => _openUrl(item.sourceUrl),
                                tooltip: '県別ソースを開く',
                                icon: const Icon(Icons.open_in_new, size: 18),
                              ),
                            if (item.sourceUrl.isEmpty)
                              const SizedBox(width: 40),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '地方議員 ${_formatInt(item.currentMembers)}人',
                          style: TextStyle(
                            fontWeight: item.currentMembers == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: item.currentMembers == 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          '都道府県議 ${_formatInt(item.prefecturalAssemblyMembers)}'
                          ' / 市区町村議 ${_formatInt(item.municipalAssemblyMembers)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<LocalElectionPrefectureReality> _prefecturesForDisplay(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final prefectureMap = <String, LocalElectionPrefectureReality>{};
    for (final item in snapshot.prefectures) {
      prefectureMap[_normalizePrefectureKey(item.prefecture)] = item;
    }

    final completed = _allPrefectures.map((prefecture) {
      return prefectureMap[_normalizePrefectureKey(prefecture)] ??
          LocalElectionPrefectureReality(
            prefecture: prefecture,
            sourceUrl: '',
            currentMembers: 0,
            prefecturalAssemblyMembers: 0,
            municipalAssemblyMembers: 0,
          );
    }).toList();

    completed.sort((a, b) {
      final countCompare = b.currentMembers.compareTo(a.currentMembers);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.prefecture.compareTo(b.prefecture);
    });

    return completed;
  }

  Color _prefectureCardBackgroundColor(
    BuildContext context,
    LocalElectionPrefectureReality item,
  ) {
    final surface = Theme.of(context).colorScheme.surface;
    if (item.currentMembers == 0) {
      return Color.alphaBlend(
        Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
        surface,
      );
    }
    if (item.currentMembers <= _lowPresenceThreshold) {
      return Color.alphaBlend(
        const Color(0xFFFFC107).withValues(alpha: 0.22),
        surface,
      );
    }
    return surface;
  }

  Color _prefectureCardBorderColor(
    BuildContext context,
    LocalElectionPrefectureReality item,
  ) {
    if (item.currentMembers == 0) {
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.5);
    }
    if (item.currentMembers <= _lowPresenceThreshold) {
      return const Color(0xFFFFA000).withValues(alpha: 0.7);
    }
    return Theme.of(context).colorScheme.outlineVariant;
  }

  String? _prefectureStatusLabel(LocalElectionPrefectureReality item) {
    if (item.currentMembers == 0) {
      return '議員不在';
    }
    if (item.currentMembers <= _lowPresenceThreshold) {
      return '要強化';
    }
    return null;
  }

  Color _prefectureBadgeBackgroundColor(
    BuildContext context,
    LocalElectionPrefectureReality item,
  ) {
    if (item.currentMembers == 0) {
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.14);
    }
    return const Color(0xFFFFC107).withValues(alpha: 0.25);
  }

  Color _prefectureBadgeForegroundColor(
    BuildContext context,
    LocalElectionPrefectureReality item,
  ) {
    if (item.currentMembers == 0) {
      return Theme.of(context).colorScheme.error;
    }
    return const Color(0xFFFF6F00);
  }

  Future<void> _downloadElectionDataCsv(
    LocalElectionRealitySnapshot snapshot,
  ) async {
    // 未擁立 (Red) または 単騎 (Yellow) のスケジュールを抽出
    final alertSchedules = snapshot.targetElectionSchedules.where((s) {
      return s.isAlertRed || s.isAlertYellow;
    }).toList();

    final pastResults = _displayPastElectionResults(snapshot);

    if (alertSchedules.isEmpty && pastResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('エクスポート対象の選挙情報がありません')),
      );
      return;
    }

    final buffer = StringBuffer();

    if (alertSchedules.isNotEmpty) {
      alertSchedules.sort((a, b) {
        final aDate = a.parsedVoteDate;
        final bDate = b.parsedVoteDate;
        if (aDate != null && bDate != null) {
          return aDate.compareTo(bDate);
        }
        return a.voteDate.compareTo(b.voteDate);
      });
      buffer.writeln('--- 未擁立・単騎の選挙 ---');
      buffer.writeln('投票日,都道府県,自治体,選挙名,候補者数,候補者一覧,Xハンドル');
      for (final s in alertSchedules) {
        final date = s.voteDate.replaceAll(',', '、');
        final pref = s.prefecture.replaceAll(',', '、');
        final muni = s.municipality.replaceAll(',', '、');
        final name = s.electionName.replaceAll(',', '、');
        final count = s.kokuminCandidateCount.toString();
        final candidates =
            _buildScheduleCandidateSummary(s).replaceAll(',', '、');
        final handles = _candidateHandles(s)
            .map((handle) => '@$handle')
            .join(' / ')
            .replaceAll(',', '、');
        buffer.writeln('$date,$pref,$muni,$name,$count,$candidates,$handles');
      }
      buffer.writeln('');
    }

    if (pastResults.isNotEmpty) {
      buffer.writeln('--- 過去の選挙結果 ---');
      buffer.writeln('投票日,場所,選挙名,候補者名,当落,得票数');
      for (final result in pastResults) {
        final date = result.date.replaceAll(',', '、');
        final location = result.location.replaceAll(',', '、');
        final electionName = result.electionName.replaceAll(',', '、');
        final candidates = result.resolvedCandidates.toList();

        if (candidates.isEmpty) {
          buffer.writeln('$date,$location,$electionName,候補者情報なし,N/A,0');
        } else {
          for (final candidate in candidates) {
            final name = candidate.name;
            final status = candidate.status;
            final votes = candidate.votes.toString();
            buffer
                .writeln('$date,$location,$electionName,$name,$status,$votes');
          }
        }
      }
    }

    final csvData = buffer.toString();
    downloadCsvFile(
      csvData,
      'election_data_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '選挙情報（${alertSchedules.length + pastResults.length}件分）をCSVファイルとしてダウンロードしました',
        ),
      ),
    );
  }

  Widget _buildUnifiedElectionCountdown() {
    // 統一地方選挙 2027 暫定日程 (官報告示前の推定値)
    const firstVoteDate = '2027-04-11';
    const firstAnnouncementDate = '2027-03-25';
    const secondVoteDate = '2027-04-25';
    const secondAnnouncementDate = '2027-04-13';

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    int daysUntil(String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return 0;
      return d.difference(today).inDays;
    }

    Widget countdownCell(String label, String iso) {
      final days = daysUntil(iso);
      final dateStr = iso.replaceAll('-', '/');
      final passed = days < 0;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: passed
                ? Theme.of(context).colorScheme.surfaceContainerHigh
                : const Color(0xFF1D4ED8).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: passed
                  ? Theme.of(context).colorScheme.outlineVariant
                  : const Color(0xFF1D4ED8).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: passed
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : const Color(0xFF1D4ED8),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                passed ? '終了' : '残 $days 日',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: passed
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : const Color(0xFF1D4ED8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1D4ED8).withValues(alpha: 0.08),
            const Color(0xFF7C3AED).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1D4ED8).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote, size: 18, color: Color(0xFF1D4ED8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '統一地方選挙 2027 カウントダウン (仮日程)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D4ED8),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '※ 官報告示前の推定日程です。確定次第更新します。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            '第一次 (都道府県・政令市)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              countdownCell('公示日', firstAnnouncementDate),
              const SizedBox(width: 8),
              countdownCell('投開票日', firstVoteDate),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '第二次 (市区町村)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              countdownCell('公示日', secondAnnouncementDate),
              const SizedBox(width: 8),
              countdownCell('投開票日', secondVoteDate),
            ],
          ),
        ],
      ),
    );
  }

  int? _filterToWindowIndex(String filter) {
    final idx = LocalElectionShareService.availableWindows
        .indexWhere((w) => w.label == filter);
    return idx >= 0 ? idx : null;
  }

  LocalElectionShareWindow? _windowForFilter(String filter) {
    final index = _filterToWindowIndex(filter);
    if (index == null) {
      return null;
    }
    return LocalElectionShareService.availableWindows[index];
  }

  bool _matchesScheduleFilter(DateTime? voteDate, String filter) {
    if (voteDate == null) return true;
    if (filter == _allLabel) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = _normalizeDate(voteDate.toLocal());
    final weekendWindow = _windowForFilter(filter);

    if (weekendWindow != null) {
      final range = _shareService.scheduleWindowRange(
        weekendWindow,
        now: today,
      );
      return !targetDate.isBefore(range.start) &&
          !targetDate.isAfter(range.end);
    }

    return true;
  }

  void _updateCalendarForFilter(
    String filter,
    List<LocalElectionScheduleEntry> upcomingSchedules,
  ) {
    if (filter == _allLabel) {
      _syncScheduleSelection(_realitySnapshot);
      return;
    }

    final filtered = upcomingSchedules.where((s) {
      return _matchesScheduleFilter(s.parsedVoteDate, filter);
    }).toList();

    if (filtered.isNotEmpty && filtered.first.parsedVoteDate != null) {
      final targetDate =
          _normalizeDate(filtered.first.parsedVoteDate!.toLocal());
      _selectedScheduleDay = targetDate;
      _scheduleFocusedDay = targetDate;
      return;
    }

    final today = _normalizeDate(DateTime.now());
    final weekendWindow = _windowForFilter(filter);
    if (weekendWindow == null) {
      _syncScheduleSelection(_realitySnapshot);
      return;
    }

    final targetDate = _shareService
        .scheduleWindowRange(
          weekendWindow,
          now: today,
        )
        .start;
    _selectedScheduleDay = targetDate;
    _scheduleFocusedDay = targetDate;
  }

  Widget _buildScheduleSection(LocalElectionRealitySnapshot snapshot) {
    final allSchedules = _sortedScheduleEntries(snapshot);
    final pastSchedules = _sortedScheduleEntries(
      snapshot,
      reverseForPast: true,
    ).where((s) => s.isPast).toList();
    final upcomingSchedules = allSchedules.where((s) => !s.isPast).toList();
    final filteredUpcomingSchedules = upcomingSchedules.where((s) {
      return _matchesScheduleFilter(s.parsedVoteDate, _selectedScheduleFilter);
    }).toList();
    final upcomingSoonCount = snapshot.schedulesWithinDays(14).length;

    return Column(
      key: _scheduleSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '地方選挙スケジュール',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _downloadElectionDataCsv(snapshot),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('CSVダウンロード'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '党公式の候補予定者ページとネット上の最新選挙日程を突合しています。'
          ' 国民民主党の候補予定者が 0 人の選挙は赤、1 人の選挙は黄色で表示します。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _buildUnifiedElectionCountdown(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              '今後 ${_formatInt(upcomingSchedules.length)} 件',
              color: const Color(0xFF607D8B),
            ),
            _buildStatusChip(
              '14日以内 ${_formatInt(upcomingSoonCount)} 件',
              color: const Color(0xFF2563EB),
            ),
            _buildStatusChip(
              '未擁立 ${_formatInt(snapshot.redAlertScheduleCount)} 件',
              color: Theme.of(context).colorScheme.error,
            ),
            _buildStatusChip(
              '単騎 ${_formatInt(snapshot.yellowAlertScheduleCount)} 件',
              color: const Color(0xFFFF8F00),
            ),
            _buildStatusChip(
              '過去1年 ${_formatInt(pastSchedules.length)} 件',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        if (snapshot.scheduleAiSummary.trim().isNotEmpty ||
            snapshot.scheduleAiAlerts.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (snapshot.scheduleAiSummary.trim().isNotEmpty)
                  Text(
                    snapshot.scheduleAiSummary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (snapshot.scheduleAiAlerts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final item in snapshot.scheduleAiAlerts)
                    _buildBulletLine(item),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PrefectureLegendChip(
              label: '通常',
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHigh,
              borderColor: Theme.of(context).colorScheme.outlineVariant,
            ),
            const _PrefectureLegendChip(
              label: '単騎',
              backgroundColor: Color(0xFFFFF4CC),
              borderColor: Color(0xFFE0A800),
            ),
            const _PrefectureLegendChip(
              label: '未擁立',
              backgroundColor: Color(0xFFFDE2E1),
              borderColor: Color(0xFFD92D20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildScheduleCalendar(snapshot),
        const SizedBox(height: 16),
        // ── 今後の選挙 ─────────────────────────────────────────
        Text(
          '今後の日程',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _scheduleFilters) ...[
              () {
                final count = upcomingSchedules
                    .where(
                      (s) => _matchesScheduleFilter(s.parsedVoteDate, filter),
                    )
                    .length;
                final isSelected = _selectedScheduleFilter == filter;
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(
                    filter == 'すべて' ? filter : '$filter ($count)',
                    style: TextStyle(
                      color: isSelected ? const Color(0xFFE5E7EB) : null,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedScheduleFilter = filter;
                        _updateCalendarForFilter(filter, upcomingSchedules);
                      });
                    }
                  },
                );
              }(),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (filteredUpcomingSchedules.isEmpty)
          _buildInlineNotice(
            _selectedScheduleFilter == 'すべて'
                ? '今後の地方選挙日程をまだ取得できていません。時間を置いて再取得してください。'
                : '$_selectedScheduleFilterに該当する地方選挙はありません。',
            color: const Color(0xFF607D8B),
            icon: Icons.event_busy,
          )
        else
          ..._buildScheduleGroups(filteredUpcomingSchedules),
        const SizedBox(height: 16),
        // ── 過去1年の結果 ───────────────────────────────────────
        GestureDetector(
          onTap: () => setState(() {
            _showPastSchedules = !_showPastSchedules;
          }),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '過去1年の結果 (${_formatInt(pastSchedules.length)} 件)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Icon(
                _showPastSchedules ? Icons.expand_less : Icons.expand_more,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        if (_showPastSchedules) ...[
          const SizedBox(height: 8),
          if (pastSchedules.isEmpty)
            _buildInlineNotice(
              '過去1年分の結果データがありません。',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              icon: Icons.history,
            )
          else
            ..._buildScheduleGroups(pastSchedules),
        ],
      ],
    );
  }

  Widget _buildScheduleCalendar(LocalElectionRealitySnapshot snapshot) {
    final calendarEvents = _scheduleEventMap(snapshot);
    final selectedDay = _selectedScheduleDay ??
        _bestScheduleSelection(snapshot) ??
        _normalizeDate(DateTime.now());
    final selectedEvents = _scheduleEventsForDay(snapshot, selectedDay);
    final firstDay = _scheduleCalendarFirstDay(snapshot, selectedDay);
    final lastDay = _scheduleCalendarLastDay(snapshot, selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: RepaintBoundary(
            child: TableCalendar<LocalElectionScheduleEntry>(
              locale: 'ja_JP',
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: _scheduleFocusedDay,
              calendarFormat: _scheduleCalendarFormat,
              selectedDayPredicate: (day) => isSameDay(day, selectedDay),
              eventLoader: (day) =>
                  calendarEvents[_normalizeDate(day)] ??
                  const <LocalElectionScheduleEntry>[],
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {
                CalendarFormat.month: '月',
                CalendarFormat.twoWeeks: '2週',
                CalendarFormat.week: '週',
              },
              onFormatChanged: (format) {
                if (_scheduleCalendarFormat == format) {
                  return;
                }
                setState(() {
                  _scheduleCalendarFormat = format;
                });
              },
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedScheduleDay = _normalizeDate(selected);
                  _scheduleFocusedDay = _normalizeDate(focused);
                });
              },
              onPageChanged: (focused) {
                setState(() {
                  _scheduleFocusedDay = _normalizeDate(focused);
                });
              },
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                canMarkersOverflow: false,
                markersMaxCount: 1,
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF1D4ED8),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFF78909C),
                  shape: BoxShape.circle,
                ),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final severity = events
                      .map(_scheduleSeverity)
                      .reduce((left, right) => left < right ? left : right);
                  final color = switch (severity) {
                    0 => Theme.of(context).colorScheme.error,
                    1 => const Color(0xFFFF8F00),
                    _ => const Color(0xFF0F766E),
                  };
                  final countLabel =
                      events.length > 9 ? '9+' : '${events.length}';
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        countLabel,
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '選択日 ${_dateOnlyFormat.format(selectedDay)}',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        if (selectedEvents.isEmpty)
          _buildInlineNotice(
            '選択日に該当する地方選挙はありません。',
            color: const Color(0xFF607D8B),
            icon: Icons.event_available,
          )
        else
          ...selectedEvents.map(_buildScheduleCard),
        const SizedBox(height: 12),
        Text(
          '日程一覧',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Map<DateTime, List<LocalElectionScheduleEntry>> _scheduleEventMap(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final map = <DateTime, List<LocalElectionScheduleEntry>>{};
    for (final item in _sortedScheduleEntries(snapshot)) {
      final voteDate = item.parsedVoteDate;
      if (voteDate == null) {
        continue;
      }
      final key = _normalizeDate(voteDate.toLocal());
      map.putIfAbsent(key, () => <LocalElectionScheduleEntry>[]).add(item);
    }
    return map;
  }

  List<LocalElectionScheduleEntry> _scheduleEventsForDay(
    LocalElectionRealitySnapshot snapshot,
    DateTime day,
  ) {
    return _scheduleEventMap(snapshot)[_normalizeDate(day)] ??
        const <LocalElectionScheduleEntry>[];
  }

  DateTime _scheduleCalendarFirstDay(
    LocalElectionRealitySnapshot snapshot,
    DateTime fallback,
  ) {
    final dates = snapshot.targetElectionSchedules
        .map((item) => item.parsedVoteDate)
        .whereType<DateTime>()
        .map((item) => _normalizeDate(item.toLocal()))
        .toList();
    if (dates.isEmpty) {
      return DateTime(fallback.year, fallback.month, 1);
    }
    dates.sort();
    final first = dates.first;
    return DateTime(first.year, first.month, 1);
  }

  DateTime _scheduleCalendarLastDay(
    LocalElectionRealitySnapshot snapshot,
    DateTime fallback,
  ) {
    final dates = snapshot.targetElectionSchedules
        .map((item) => item.parsedVoteDate)
        .whereType<DateTime>()
        .map((item) => _normalizeDate(item.toLocal()))
        .toList();
    if (dates.isEmpty) {
      return DateTime(fallback.year, fallback.month + 3, 0);
    }
    dates.sort();
    final last = dates.last;
    return DateTime(last.year, last.month + 1, 0);
  }

  List<Widget> _buildScheduleGroups(
    List<LocalElectionScheduleEntry> schedules,
  ) {
    // Windows版#94: 件数が多いと縦に長くなるため日付ごとに ExpansionTile で
    // 折りたたみ可能にする。最初の 1 日付だけ initiallyExpanded=true。
    final groups = <String, List<LocalElectionScheduleEntry>>{};
    final orderedDates = <String>[];
    for (final item in schedules) {
      final key = item.voteDate;
      if (!groups.containsKey(key)) {
        orderedDates.add(key);
        groups[key] = <LocalElectionScheduleEntry>[];
      }
      groups[key]!.add(item);
    }
    final widgets = <Widget>[];
    for (var i = 0; i < orderedDates.length; i++) {
      final date = orderedDates[i];
      final items = groups[date]!;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: i == 0,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                title: Text(
                  _formatScheduleDate(date),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                subtitle: Text(
                  '${items.length}件の選挙',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                children: items.map(_buildScheduleCard).toList(),
              ),
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  List<LocalElectionScheduleEntry> _sortedScheduleEntries(
    LocalElectionRealitySnapshot snapshot, {
    bool reverseForPast = false,
  }) {
    final schedules = List<LocalElectionScheduleEntry>.from(
      snapshot.targetElectionSchedules,
    );
    schedules.sort((left, right) {
      final leftDate = left.parsedVoteDate;
      final rightDate = right.parsedVoteDate;
      if (leftDate != null && rightDate != null) {
        final dateCompare = reverseForPast
            ? rightDate.compareTo(leftDate)
            : leftDate.compareTo(rightDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
      }
      final severityCompare = _scheduleSeverity(left).compareTo(
        _scheduleSeverity(right),
      );
      if (severityCompare != 0) {
        return severityCompare;
      }
      final prefectureCompare = left.prefecture.compareTo(right.prefecture);
      if (prefectureCompare != 0) {
        return prefectureCompare;
      }
      return left.electionName.compareTo(right.electionName);
    });
    return schedules;
  }

  Widget _buildScheduleCard(LocalElectionScheduleEntry item) {
    final candidateSummary = _buildScheduleCandidateSummary(item);
    final candidateHandles = _candidateHandles(item);

    return Card(
      color: item.isPast
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : _scheduleCardBackgroundColor(context, item),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: item.isPast
              ? Theme.of(context).colorScheme.outlineVariant
              : _scheduleCardBorderColor(context, item),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Row(
                        children: [
                          if (item.isPast) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '結果',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              item.electionName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: item.isPast
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                    : null,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.prefecture} / ${item.electionCategory}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (!item.isPast) ...[
                        if (_scheduleStatusLabel(item) case final label?) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _scheduleBadgeBackgroundColor(context, item),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: _scheduleBadgeForegroundColor(
                                  context,
                                  item,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (item.detailUrl.trim().isNotEmpty)
                      IconButton(
                        onPressed: () => _openUrl(item.detailUrl),
                        tooltip: '選挙日程ソースを開く',
                        icon: const Icon(Icons.event_note_outlined, size: 18),
                      ),
                    if (item.officialCandidateSourceUrl.trim().isNotEmpty)
                      IconButton(
                        onPressed: () =>
                            _openUrl(item.officialCandidateSourceUrl),
                        tooltip: '党公式候補ページを開く',
                        icon: const Icon(Icons.open_in_new, size: 18),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip(
                  '国民候補',
                  '${_formatInt(item.kokuminCandidateCount)}人',
                  color: _scheduleMetricColor(item),
                ),
                _buildMetricChip(
                  '自治体',
                  item.municipality,
                  color: const Color(0xFF475569),
                ),
                if (item.announcementDate.trim().isNotEmpty)
                  _buildMetricChip(
                    '告示日',
                    _formatScheduleDate(item.announcementDate),
                    color: const Color(0xFF2563EB),
                  ),
                if (item.seatCount > 0 || item.totalCandidateCount > 0)
                  _buildMetricChip(
                    '定数/候補者',
                    '${_formatInt(item.seatCount)} / ${_formatInt(item.totalCandidateCount)}',
                    color: const Color(0xFF7C3AED),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              candidateSummary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (candidateHandles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidateHandles.map((handle) {
                  return ActionChip(
                    avatar: const Icon(Icons.alternate_email, size: 16),
                    label: Text('@$handle'),
                    onPressed: () => _openUrl('https://x.com/$handle'),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _scheduleSeverity(LocalElectionScheduleEntry item) {
    if (item.isAlertRed) {
      return 0;
    }
    if (item.isAlertYellow) {
      return 1;
    }
    return 2;
  }

  String _buildScheduleCandidateSummary(LocalElectionScheduleEntry item) {
    if (item.kokuminCandidateNames.isEmpty) {
      return '党公式候補予定者ページで該当候補を確認できていません。';
    }
    return item.kokuminCandidateNames.asMap().entries.map((entry) {
      final status = entry.key < item.kokuminCandidateStatuses.length
          ? item.kokuminCandidateStatuses[entry.key].trim()
          : '';
      final handle = entry.key < item.kokuminCandidateXHandles.length
          ? _normalizeXHandle(item.kokuminCandidateXHandles[entry.key])
          : '';
      final suffixes = <String>[
        if (status.isNotEmpty) status,
        if (handle.isNotEmpty) '@$handle',
      ];
      if (suffixes.isEmpty) {
        return entry.value;
      }
      return '${entry.value}（${suffixes.join(' / ')}）';
    }).join(' / ');
  }

  List<String> _candidateHandles(LocalElectionScheduleEntry item) {
    return item.kokuminCandidateXHandles
        .map(_normalizeXHandle)
        .where((handle) => handle.isNotEmpty)
        .toList();
  }

  String _normalizeXHandle(String raw) {
    return raw.trim().replaceFirst(RegExp(r'^@+'), '');
  }

  Color _scheduleCardBackgroundColor(
    BuildContext context,
    LocalElectionScheduleEntry item,
  ) {
    final surface = Theme.of(context).colorScheme.surface;
    if (item.isAlertRed) {
      return Color.alphaBlend(
        Theme.of(context).colorScheme.error.withValues(alpha: 0.12),
        surface,
      );
    }
    if (item.isAlertYellow) {
      return Color.alphaBlend(
        const Color(0xFFFFC107).withValues(alpha: 0.22),
        surface,
      );
    }
    return surface;
  }

  Color _scheduleCardBorderColor(
    BuildContext context,
    LocalElectionScheduleEntry item,
  ) {
    if (item.isAlertRed) {
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.5);
    }
    if (item.isAlertYellow) {
      return const Color(0xFFFFA000).withValues(alpha: 0.7);
    }
    return Theme.of(context).colorScheme.outlineVariant;
  }

  String? _scheduleStatusLabel(LocalElectionScheduleEntry item) {
    if (item.isAlertRed) {
      return '未擁立';
    }
    if (item.isAlertYellow) {
      return '単騎';
    }
    return null;
  }

  Color _scheduleBadgeBackgroundColor(
    BuildContext context,
    LocalElectionScheduleEntry item,
  ) {
    if (item.isAlertRed) {
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.14);
    }
    return const Color(0xFFFFC107).withValues(alpha: 0.25);
  }

  Color _scheduleBadgeForegroundColor(
    BuildContext context,
    LocalElectionScheduleEntry item,
  ) {
    if (item.isAlertRed) {
      return Theme.of(context).colorScheme.error;
    }
    return const Color(0xFFFF6F00);
  }

  Color _scheduleMetricColor(LocalElectionScheduleEntry item) {
    if (item.isAlertRed) {
      return const Color(0xFFB91C1C);
    }
    if (item.isAlertYellow) {
      return const Color(0xFFFF8F00);
    }
    return const Color(0xFF0F766E);
  }

  String _formatScheduleDate(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return '-';
    }
    final parsed = DateTime.tryParse(normalized) ??
        DateTime.tryParse(normalized.replaceAll('/', '-'));
    if (parsed == null) {
      return normalized;
    }
    return _dateOnlyFormat.format(parsed.toLocal());
  }

  List<PastElectionResult> _displayPastElectionResults(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final merged = <String, PastElectionResult>{};

    for (final result in _rawPastElectionResults()) {
      merged[_pastElectionResultKey(result)] = result;
    }

    for (final result in snapshot.resolvedPastElectionResults) {
      merged.putIfAbsent(_pastElectionResultKey(result), () => result);
    }

    final results =
        merged.values.where((item) => item.hasResolvedCandidates).toList()
          ..sort((left, right) {
            final leftDate = left.parsedDate;
            final rightDate = right.parsedDate;
            if (leftDate != null && rightDate != null) {
              final dateCompare = rightDate.compareTo(leftDate);
              if (dateCompare != 0) {
                return dateCompare;
              }
            } else if (rightDate != null) {
              return 1;
            } else if (leftDate != null) {
              return -1;
            }
            return right.electionName.compareTo(left.electionName);
          });
    return results;
  }

  List<PastElectionResult> _rawPastElectionResults() {
    final results = <PastElectionResult>[];
    for (final item in _pastElectionResults) {
      try {
        final result = PastElectionResult.fromJson(item);
        if (result.hasResolvedCandidates) {
          results.add(result);
        }
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  String _pastElectionResultKey(PastElectionResult result) {
    final parsedDate = result.parsedDate;
    final dateKey = parsedDate == null
        ? result.date.trim()
        : '${parsedDate.year.toString().padLeft(4, '0')}-'
            '${parsedDate.month.toString().padLeft(2, '0')}-'
            '${parsedDate.day.toString().padLeft(2, '0')}';
    return '$dateKey|${result.location.trim()}|${result.electionName.trim()}';
  }

  Map<int, List<PastElectionResult>> _groupPastElectionResultsByYear(
    List<PastElectionResult> results,
  ) {
    final grouped = <int, List<PastElectionResult>>{};
    for (final result in results) {
      final year = result.parsedDate?.year;
      if (year == null) {
        continue;
      }
      grouped.putIfAbsent(year, () => <PastElectionResult>[]).add(result);
    }

    final entries = grouped.entries.toList()
      ..sort((left, right) => right.key.compareTo(left.key));
    return Map<int, List<PastElectionResult>>.fromEntries(entries);
  }

  int _pastElectionBattleCount(List<PastElectionResult> results) {
    return results.fold<int>(
      0,
      (sum, result) => sum + result.resolvedCandidateCount,
    );
  }

  List<String> _pastElectionOutcomeLines(
    List<PastElectionResult> results, {
    required bool wins,
  }) {
    final entries = <({DateTime? date, String text})>[];
    for (final result in results) {
      for (final candidate in result.resolvedCandidates) {
        if (wins && !candidate.isWin) {
          continue;
        }
        if (!wins && !candidate.isLoss) {
          continue;
        }
        entries.add(
          (
            date: result.parsedDate,
            text: _formatPastElectionOutcomeLine(result, candidate),
          ),
        );
      }
    }

    entries.sort((left, right) {
      final leftDate = left.date;
      final rightDate = right.date;
      if (leftDate != null && rightDate != null) {
        final dateCompare = rightDate.compareTo(leftDate);
        if (dateCompare != 0) {
          return dateCompare;
        }
      } else if (rightDate != null) {
        return 1;
      } else if (leftDate != null) {
        return -1;
      }
      return left.text.compareTo(right.text);
    });
    return entries.map((item) => item.text).toList();
  }

  String _formatPastElectionOutcomeLine(
    PastElectionResult result,
    PastElectionCandidate candidate,
  ) {
    final date = result.parsedDate;
    final dateLabel = date == null ? result.date : '${date.month}月${date.day}日';
    final voteLabel = candidate.votes > 0
        ? ' (${_numberFormat.format(candidate.votes)}票)'
        : '';
    return '$dateLabel ${result.electionName} ${candidate.name} ${candidate.status}$voteLabel';
  }

  Widget _buildPastElectionYearSummary(
    int year,
    List<PastElectionResult> results,
  ) {
    final winCount =
        results.fold<int>(0, (sum, result) => sum + result.winCount);
    final lossCount =
        results.fold<int>(0, (sum, result) => sum + result.lossCount);
    final battleCount = _pastElectionBattleCount(results);
    final winLines = _pastElectionOutcomeLines(results, wins: true);
    final lossLines = _pastElectionOutcomeLines(results, wins: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$year年',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPastElectionRecordChip(
                label: '${_formatInt(battleCount)}戦',
                backgroundColor:
                    const Color(0xFF0F172A).withValues(alpha: 0.08),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              _buildPastElectionRecordChip(
                label: '${_formatInt(winCount)}勝',
                backgroundColor:
                    const Color(0xFF4CAF50).withValues(alpha: 0.12),
                foregroundColor: const Color(0xFF2E7D32),
              ),
              _buildPastElectionRecordChip(
                label: '${_formatInt(lossCount)}敗',
                backgroundColor:
                    const Color(0xFFE53935).withValues(alpha: 0.10),
                foregroundColor: const Color(0xFFC62828),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPastElectionOutcomeGroup(
            title: '当選',
            lines: winLines,
            accentColor: const Color(0xFF4CAF50),
            emptyLabel: '当選記録はまだありません',
          ),
          const SizedBox(height: 8),
          _buildPastElectionOutcomeGroup(
            title: '落選',
            lines: lossLines,
            accentColor: const Color(0xFFE53935),
            emptyLabel: '落選記録はまだありません',
          ),
        ],
      ),
    );
  }

  Widget _buildPastElectionRecordChip({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildPastElectionOutcomeGroup({
    required String title,
    required List<String> lines,
    required Color accentColor,
    required String emptyLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lines.isEmpty)
            Text(
              title,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            )
          else if (lines.length > _pastElectionOutcomeAccordionThreshold)
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                iconColor: accentColor,
                collapsedIconColor: accentColor,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                subtitle: Text(
                  '${lines.length}件のため折りたたみ表示',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                children: [
                  const SizedBox(height: 8),
                  ...lines.map(_buildBulletLine),
                ],
              ),
            )
          else
            Text(
              title,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
          if (lines.length <= _pastElectionOutcomeAccordionThreshold)
            const SizedBox(height: 8),
          if (lines.isEmpty)
            Text(
              emptyLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else if (lines.length <= _pastElectionOutcomeAccordionThreshold)
            ...lines.map(_buildBulletLine),
        ],
      ),
    );
  }

  Widget _buildPastElectionBreakdownBlock(List<PastElectionResult> results) {
    if (results.length <= _pastElectionBreakdownAccordionThreshold) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '選挙別の内訳',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          ...results.map((result) => _buildPastElectionCard(result)),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            '選挙別の内訳',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          subtitle: Text(
            '${results.length}件のため折りたたみ表示',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          children: [
            const SizedBox(height: 8),
            ...results.map((result) => _buildPastElectionCard(result)),
          ],
        ),
      ),
    );
  }

  Widget _buildPastElectionCandidateBlock(
    List<PastElectionCandidate> candidates,
  ) {
    final chips = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: candidates.map((candidate) {
        final isWin = candidate.isWin;
        return Chip(
          label: Text(
            '${candidate.name} ${candidate.status}${candidate.votes > 0 ? ' (${candidate.votes}票)' : ''}',
            style: TextStyle(
              fontSize: 11,
              color: isWin ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              height: 1.5,
            ),
          ),
          backgroundColor: isWin
              ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
              : const Color(0xFFE53935).withValues(alpha: 0.10),
          side: BorderSide(
            color: isWin
                ? const Color(0xFF4CAF50).withValues(alpha: 0.35)
                : const Color(0xFFE53935).withValues(alpha: 0.28),
          ),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        );
      }).toList(),
    );

    if (candidates.length <= _pastElectionCandidateAccordionThreshold) {
      return chips;
    }

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          '候補者内訳',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        subtitle: Text(
          '${candidates.length}件のため折りたたみ表示',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        children: [
          const SizedBox(height: 8),
          chips,
        ],
      ),
    );
  }

  Widget _buildPastElectionResultsSection(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final results = _displayPastElectionResults(snapshot);
    final yearlyResults = _groupPastElectionResultsByYear(results);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '過去の選挙結果',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '国民民主党候補の当落情報を年別戦績つきで表示します。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (yearlyResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...yearlyResults.entries.map(
            (entry) => _buildPastElectionYearSummary(entry.key, entry.value),
          ),
        ],
        const SizedBox(height: 10),
        _buildPastElectionBreakdownBlock(results),
      ],
    );
  }

  Widget _buildPastElectionCard(PastElectionResult result) {
    final winCount = result.winCount;
    final lossCount = result.lossCount;
    final battleCount = result.resolvedCandidateCount > 0
        ? result.resolvedCandidateCount
        : result.totalCount;
    final hasWin = winCount > 0;
    final displayCandidates = result.resolvedCandidates.isNotEmpty
        ? result.resolvedCandidates.toList()
        : result.dppCandidates;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasWin
            ? const Color(0xFF4CAF50).withValues(alpha: 0.06)
            : const Color(0xFFE53935).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWin
              ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
              : const Color(0xFFE53935).withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.electionName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasWin
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$battleCount戦 ${_formatInt(winCount)}勝 ${_formatInt(lossCount)}敗',
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${result.location}  ${result.date}',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (displayCandidates.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPastElectionCandidateBlock(displayCandidates),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRosterSection(LocalElectionRealitySnapshot snapshot) {
    final prefectureOptions = _memberPrefectureOptions(snapshot);
    final filteredMembers = _filteredRosterMembers(snapshot);
    final visibleMembers = filteredMembers.take(_visibleMemberCount).toList();
    final ageVisibleCount =
        filteredMembers.where((item) => item.age != null).length;
    final profileVisibleCount =
        filteredMembers.where((item) => item.profile.trim().isNotEmpty).length;

    return Column(
      key: _rosterSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '現職地方議員の個票一覧',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '氏名・自治体・議会種別・当選回数は都道府県ページから取得しています。'
          '年齢と簡易プロフィールは公式詳細ページに記載がある議員だけ追加表示し、'
          '性別は明示がある場合のみ表示します。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'member-prefecture-$_selectedMemberPrefecture',
                ),
                initialValue: _selectedMemberPrefecture,
                decoration: const InputDecoration(
                  labelText: '都道府県',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final label in prefectureOptions)
                    DropdownMenuItem<String>(
                      value: label,
                      child: Text(label),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedMemberPrefecture = value;
                    _visibleMemberCount = _memberPageSize;
                  });
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'member-assembly-$_selectedMemberAssemblyCategory',
                ),
                initialValue: _selectedMemberAssemblyCategory,
                decoration: const InputDecoration(
                  labelText: '議会種別',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: _allAssemblyCategories,
                    child: Text('すべて'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'prefectural',
                    child: Text('都道府県議会'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'municipal',
                    child: Text('市区町村議会'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedMemberAssemblyCategory = value;
                    _visibleMemberCount = _memberPageSize;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatusChip(
              '表示 ${_formatInt(visibleMembers.length)}/${_formatInt(filteredMembers.length)} 人',
              color: const Color(0xFF607D8B),
            ),
            _buildStatusChip(
              '個票 ${_formatInt(snapshot.rosterCount)} 人',
              color: const Color(0xFF0891B2),
            ),
            _buildStatusChip(
              '年齢表示 ${_formatInt(ageVisibleCount)} 人',
              color: const Color(0xFF0F766E),
            ),
            _buildStatusChip(
              'プロフィール表示 ${_formatInt(profileVisibleCount)} 人',
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredMembers.isEmpty)
          _buildInlineNotice(
            '条件に合う議員が見つかりません。都道府県または検索条件を変更してください。',
            color: const Color(0xFF607D8B),
            icon: Icons.info_outline,
          )
        else
          _buildMemberRosterAccordion(
            visibleMembers: visibleMembers,
            totalFilteredCount: filteredMembers.length,
          ),
      ],
    );
  }

  Widget _buildMemberRosterAccordion({
    required List<LocalElectionLegislatorProfile> visibleMembers,
    required int totalFilteredCount,
  }) {
    final grouped = <String, List<LocalElectionLegislatorProfile>>{};
    for (final member in visibleMembers) {
      grouped.putIfAbsent(member.prefecture, () => []).add(member);
    }
    final entries = grouped.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          _buildMemberRosterGroup(
            prefecture: entries[index].key,
            members: entries[index].value,
            initiallyExpanded: entries.length <= 2 || index == 0,
          ),
        if (totalFilteredCount > visibleMembers.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: _showMoreMembers,
              icon: const Icon(Icons.expand_more),
              label: Text(
                'さらに ${_formatInt((totalFilteredCount - visibleMembers.length).clamp(0, _memberPageSize))} 人表示',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemberRosterGroup({
    required String prefecture,
    required List<LocalElectionLegislatorProfile> members,
    required bool initiallyExpanded,
  }) {
    final prefecturalCount =
        members.where((item) => item.assemblyCategory == 'prefectural').length;
    final municipalCount =
        members.where((item) => item.assemblyCategory == 'municipal').length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            title: Text(
              '$prefecture ${_formatInt(members.length)}人',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMiniStatChip(
                    '都道府県議',
                    prefecturalCount,
                    color: const Color(0xFF2563EB),
                  ),
                  _buildMiniStatChip(
                    '市区町村議',
                    municipalCount,
                    color: const Color(0xFF0F766E),
                  ),
                ],
              ),
            ),
            children: members.map(_buildMemberCard).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(LocalElectionLegislatorProfile member) {
    final detailUrl = member.detailUrl.trim();
    final isLoading =
        detailUrl.isNotEmpty && _memberProfileLoadingUrls.contains(detailUrl);
    final detailError =
        detailUrl.isEmpty ? null : _memberProfileErrors[detailUrl];
    final hasDetailedProfile = member.hasDetailedProfile;
    final detailSummary = member.profile.trim().isNotEmpty
        ? member.profile
        : hasDetailedProfile
            ? '生年月日など、公式詳細ページで確認できた項目を反映済みです。'
            : '詳細プロフィールは未取得です。必要な議員だけ個別取得できます。';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        member.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                      if (member.kana.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.kana,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        member.constituency,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (detailUrl.isNotEmpty)
                  IconButton(
                    onPressed: () => _openUrl(detailUrl),
                    tooltip: '公式プロフィールを開く',
                    icon: const Icon(Icons.open_in_new),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip(
                  '議会',
                  member.assemblyLabel,
                  color: const Color(0xFF1D4ED8),
                ),
                if (member.electionCountLabel.trim().isNotEmpty)
                  _buildMetricChip(
                    '当選回数',
                    member.electionCountLabel,
                    color: const Color(0xFFB45309),
                  ),
                _buildMetricChip(
                  '県連',
                  member.prefecture,
                  color: const Color(0xFF475569),
                ),
                if (member.age != null)
                  _buildMetricChip(
                    '年齢',
                    '${member.age}歳',
                    color: const Color(0xFF0F766E),
                  ),
                if (member.gender.trim().isNotEmpty)
                  _buildMetricChip(
                    '性別',
                    member.gender,
                    color: const Color(0xFFBE185D),
                  ),
              ],
            ),
            if (member.birthDate.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '生年月日 ${member.birthDate}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              detailSummary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (detailError != null) ...[
              const SizedBox(height: 10),
              _buildInlineNotice(
                detailError,
                color: const Color(0xFFFF6B35),
                icon: Icons.info_outline,
              ),
            ],
            if (detailUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: isLoading
                        ? null
                        : () => _loadMemberProfile(
                              member,
                              forceRefresh: hasDetailedProfile,
                            ),
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            hasDetailedProfile
                                ? Icons.refresh
                                : Icons.manage_search,
                          ),
                    label: Text(
                      isLoading
                          ? '取得中'
                          : hasDetailedProfile
                              ? '詳細を更新'
                              : '詳細を取得',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openUrl(detailUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('公式ページ'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSection(LocalElectionRealitySnapshot snapshot) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          title: Text(
            '公式ソース',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          subtitle: Text(
            '${_formatInt(snapshot.sources.length)}件の取得元',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          children: [
            for (final source in snapshot.sources)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(source.label),
                  subtitle: Text(
                    source.note.isEmpty
                        ? source.url
                        : '${source.note}\n${source.url}',
                  ),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openUrl(source.url),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCdpBenchmarkSection(LocalElectionPlanDashboard plan) {
    final comparedCount = plan.cdpComparisonPrefectureCount;
    if (comparedCount == 0) {
      return _buildInlineNotice(
        '立憲民主党の県別地方議員数は次回のAI更新で取り込みます。',
        color: const Color(0xFF607D8B),
        icon: Icons.insights_outlined,
      );
    }

    final topGaps = plan.topCdpGapPrefectures();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.insights_outlined),
          title: Text(
            '立憲地方議員ベンチマーク',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildMiniStatChip(
                  '立憲合計',
                  plan.totalCdpLocalMembers,
                  color: const Color(0xFFDC2626),
                ),
                _buildMiniStatChip(
                  '取得県連',
                  comparedCount,
                  suffix: '/47',
                  color: const Color(0xFF2563EB),
                ),
                _buildMiniStatChip(
                  '立憲先行',
                  plan.cdpLeadPrefectureCount,
                  color: const Color(0xFFF59E0B),
                ),
                _buildMiniStatChip(
                  '国民同数以上',
                  plan.kokuminLeadPrefectureCount,
                  color: const Color(0xFF0F766E),
                ),
              ],
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in topGaps) _buildCdpGapPill(item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCdpGapPill(LocalElectionPrefecturePlan plan) {
    final gap = plan.cdpMemberGap;
    final color = gap > 0
        ? const Color(0xFFDC2626)
        : gap == 0
            ? const Color(0xFF64748B)
            : const Color(0xFF0F766E);
    final label = gap > 0
        ? '立憲+${_formatInt(gap)}'
        : gap == 0
            ? '同数'
            : '国民+${_formatInt(-gap)}';

    return Container(
      constraints: const BoxConstraints(minWidth: 148),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.prefecture,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '国民 ${_formatInt(plan.currentMembers)} / 立憲 ${_formatInt(plan.cdpLocalMembers)}',
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertStrip(LocalElectionPlanDashboard plan) {
    final gap = plan.allocationGap;
    final overdue = plan.overdueEndorsementCount();
    final dueSoon = plan.dueSoonEndorsementCount();
    final snapshot = _realitySnapshot;
    final gapLabel = gap >= 0 ? '未配分ギャップ $gap人' : '超過配分 ${gap.abs()}人';
    final realityLabel = snapshot?.hasData == true
        ? '公式実数ベースでは残り ${_formatInt(snapshot!.actualNetIncreaseRequired)}人'
        : '計画基準は ${_formatInt(plan.currentLocalMembers)}人';
    final color = gap == 0 && overdue == 0
        ? const Color(0xFF4CAF50)
        : overdue > 0 || gap != 0
            ? const Color(0xFFE53935)
            : const Color(0xFFFF6B35);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              gap == 0 && overdue == 0
                  ? '県連配分は必要純増 ${_formatInt(plan.requiredNetIncrease)}人を満たしています。'
                      ' $realityLabel。'
                      '次は公認内定の前倒しと月次レビューの固定化です。'
                  : '$gapLabel、期限超過県連 $overdue、'
                      '60日以内に期限到来 $dueSoon。'
                      ' $realityLabel。'
                      '「700」の看板ではなく、月次レビューで詰める運用が必要です。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(LocalElectionPlanDashboard plan) {
    final snapshot = _realitySnapshot;
    final currentTotal = snapshot?.hasData == true
        ? snapshot!.officialCurrentLocalMembers
        : plan.currentLocalMembers;
    final shortfall = snapshot?.hasData == true
        ? snapshot!.actualNetIncreaseRequired
        : plan.requiredNetIncrease;
    final topPrefectures = plan.topPriorityPrefectures(limit: 10);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 1000;
        final progressChart = ElectionProgressChart(
          currentTotal: currentTotal,
          shortfall: shortfall,
          target: plan.targetLocalMembers,
          caption: snapshot?.hasData == true
              ? '公式議員ページの最新集計を反映'
              : '最新実データ未取得時は計画値を表示',
        );
        final regionalChart = ElectionRegionalKpiChart(
          prefectures: topPrefectures,
        );
        final japanMap = ElectionJapanMap(
          prefectures: plan.prefectures,
          schedules: snapshot?.targetElectionSchedules ?? const [],
          pastElectionResults: snapshot == null
              ? const <PastElectionResult>[]
              : _displayPastElectionResults(snapshot),
          members:
              snapshot?.members ?? const <LocalElectionLegislatorProfile>[],
        );

        if (stacked) {
          return Column(
            children: [
              japanMap,
              const SizedBox(height: 16),
              progressChart,
              const SizedBox(height: 16),
              regionalChart,
            ],
          );
        }

        return Column(
          children: [
            japanMap,
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: progressChart),
                const SizedBox(width: 16),
                Expanded(child: regionalChart),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryGrid(LocalElectionPlanDashboard plan) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          title: '県連配分済み純増',
          value: _formatInt(plan.allocatedNetIncrease),
          subtitle: '必要 ${_formatInt(plan.requiredNetIncrease)} に対して',
          color: const Color(0xFF0F766E),
        ),
        _buildSummaryCard(
          title: '現職維持目標',
          value: _formatInt(plan.totalIncumbentRetentionTarget),
          subtitle: '県連入力の合計値',
          color: const Color(0xFFB45309),
        ),
        _buildSummaryCard(
          title: '重点自治体',
          value: _formatInt(plan.totalFocusMunicipalityCount),
          subtitle: '全国合計',
          color: const Color(0xFF1D4ED8),
        ),
        _buildSummaryCard(
          title: '新人擁立',
          value: _formatInt(plan.totalNewCandidateTarget),
          subtitle: '全国合計',
          color: const Color(0xFF7C3AED),
        ),
        _buildSummaryCard(
          title: '公認内定済み県連',
          value:
              '${_formatInt(plan.confirmedEndorsementCount)}/${_formatInt(plan.prefectures.length)}',
          subtitle: '期限管理に使用',
          color: const Color(0xFF0F766E),
        ),
        _buildSummaryCard(
          title: '接戦区支援回数',
          value: _formatInt(plan.totalCloseRaceSupportRounds),
          subtitle: '全国合計',
          color: const Color(0xFFBE123C),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPrioritySection(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '重点県連',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in plan.topPriorityPrefectures(limit: 8))
              _buildTopPriorityCard(item),
          ],
        ),
      ],
    );
  }

  Widget _buildTopPriorityCard(LocalElectionPrefecturePlan item) {
    final reality = _realityForPrefecture(item.prefecture);

    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.prefecture,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '純増 ${_formatInt(item.additionalSeatTarget)} / '
                '新人 ${_formatInt(item.newCandidateTarget)}',
              ),
              Text(
                '重点自治体 ${_formatInt(item.focusMunicipalityCount)} / '
                '支援 ${_formatInt(item.closeRaceSupportRounds)}回',
              ),
              Text(
                '公認内定期限 ${formatMonthKey(item.endorsementDeadlineMonth)}',
              ),
              if (reality != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '公式現在 ${_formatInt(reality.currentMembers)}人 '
                    '(都道府県議 ${_formatInt(reality.prefecturalAssemblyMembers)} / '
                    '市区町村議 ${_formatInt(reality.municipalAssemblyMembers)})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlySection(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月次KPI',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          '2026年4月から2027年3月までの累計管理です。'
          '公認内定は「その月に期限到来する県連数」を別列で表示します。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('月')),
              DataColumn(label: Text('現職維持累計')),
              DataColumn(label: Text('重点自治体累計')),
              DataColumn(label: Text('新人擁立累計')),
              DataColumn(label: Text('内定期限到来')),
              DataColumn(label: Text('内定期限累計')),
              DataColumn(label: Text('接戦区支援累計')),
            ],
            rows: [
              for (final month in plan.monthlyCheckpoints)
                DataRow(
                  cells: [
                    DataCell(Text(month.label)),
                    DataCell(
                      Text(
                        _formatInt(month.cumulativeIncumbentRetentionTarget),
                      ),
                    ),
                    DataCell(
                      Text(_formatInt(month.cumulativeFocusMunicipalityCount)),
                    ),
                    DataCell(
                      Text(_formatInt(month.cumulativeNewCandidateTarget)),
                    ),
                    DataCell(
                      Text(
                        '${_formatInt(month.endorsementsDueThisMonth)}県連',
                      ),
                    ),
                    DataCell(
                      Text('${_formatInt(month.cumulativeEndorsementsDue)}県連'),
                    ),
                    DataCell(
                      Text(_formatInt(month.cumulativeCloseRaceSupportRounds)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegionFilter(LocalElectionPlanDashboard plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '県連別配分',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in plan.regionLabels)
              ChoiceChip(
                label: Text(label),
                selected: _selectedRegion == label,
                onSelected: (_) {
                  setState(() {
                    _selectedRegion = label;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrefectureAccordion(LocalElectionPlanDashboard plan) {
    final selectedPrefectures = plan.prefecturesForRegion(_selectedRegion);
    if (selectedPrefectures.isEmpty) {
      return _buildInlineNotice(
        '表示できる県連KPIがありません。',
        color: const Color(0xFF607D8B),
        icon: Icons.info_outline,
      );
    }

    if (_selectedRegion != _allLabel) {
      return _buildPrefectureRegionGroup(
        title: '$_selectedRegion ${_formatInt(selectedPrefectures.length)}県連',
        prefectures: selectedPrefectures,
        initiallyExpanded: true,
      );
    }

    final regions = plan.regionLabels.where((label) => label != _allLabel);
    return Column(
      children: [
        for (final region in regions)
          _buildPrefectureRegionGroup(
            title:
                '$region ${_formatInt(plan.prefecturesForRegion(region).length)}県連',
            prefectures: plan.prefecturesForRegion(region),
            initiallyExpanded: region == selectedPrefectures.first.region,
          ),
      ],
    );
  }

  Widget _buildPrefectureRegionGroup({
    required String title,
    required List<LocalElectionPrefecturePlan> prefectures,
    required bool initiallyExpanded,
  }) {
    final additionalTotal = prefectures.fold<int>(
      0,
      (sum, item) => sum + item.additionalSeatTarget,
    );
    final newCandidateTotal = prefectures.fold<int>(
      0,
      (sum, item) => sum + item.newCandidateTarget,
    );
    final currentMembersTotal = prefectures.fold<int>(
      0,
      (sum, item) => sum + item.currentMembers,
    );
    final cdpMembersTotal = prefectures.fold<int>(
      0,
      (sum, item) => sum + item.cdpLocalMembers,
    );
    final scheduledTotal = prefectures.fold<int>(
      0,
      (sum, item) => sum + item.scheduledElectionCount,
    );
    final now = DateTime.now();
    final overdueCount =
        prefectures.where((item) => item.isEndorsementOverdue(now)).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            title: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildMiniStatChip(
                    '現職',
                    currentMembersTotal,
                    color: const Color(0xFF0891B2),
                  ),
                  if (cdpMembersTotal > 0)
                    _buildMiniStatChip(
                      '立憲',
                      cdpMembersTotal,
                      color: const Color(0xFFDC2626),
                    ),
                  _buildMiniStatChip(
                    '純増',
                    additionalTotal,
                    color: const Color(0xFF0F766E),
                  ),
                  _buildMiniStatChip(
                    '新人',
                    newCandidateTotal,
                    color: const Color(0xFF7C3AED),
                  ),
                  _buildMiniStatChip(
                    '予定選挙',
                    scheduledTotal,
                    suffix: '件',
                    color: const Color(0xFF2563EB),
                  ),
                  if (overdueCount > 0)
                    _buildMiniStatChip(
                      '期限超過',
                      overdueCount,
                      color: const Color(0xFFE53935),
                    ),
                ],
              ),
            ),
            children: prefectures.map(_buildPrefectureCard).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPrefectureCard(LocalElectionPrefecturePlan plan) {
    final now = DateTime.now();
    final overdue = plan.isEndorsementOverdue(now);
    final dueSoon = plan.isEndorsementDueSoon(now);
    final reality = _realityForPrefecture(plan.prefecture);
    final accent = overdue
        ? const Color(0xFFE53935)
        : dueSoon
            ? const Color(0xFFFF6B35)
            : plan.endorsementConfirmed
                ? const Color(0xFF4CAF50)
                : const Color(0xFF607D8B);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        '${plan.prefecture} 県連',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(plan.region),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricChip('純増', _formatInt(plan.additionalSeatTarget)),
                _buildMetricChip(
                  '現職維持',
                  _formatInt(plan.incumbentRetentionTarget),
                ),
                _buildMetricChip(
                  '重点自治体',
                  _formatInt(plan.focusMunicipalityCount),
                ),
                _buildMetricChip(
                  '新人擁立',
                  _formatInt(plan.newCandidateTarget),
                ),
                _buildMetricChip(
                  '現状当選率',
                  plan.currentCandidateWinRateLabel,
                ),
                _buildMetricChip(
                  '公認内定期限',
                  formatMonthKey(plan.endorsementDeadlineMonth),
                  color: accent,
                ),
                _buildMetricChip(
                  '接戦区支援',
                  '${_formatInt(plan.closeRaceSupportRounds)}回',
                ),
                _buildMetricChip(
                  '内定状況',
                  plan.endorsementConfirmed
                      ? '完了'
                      : overdue
                          ? '期限超過'
                          : dueSoon
                              ? '期限接近'
                              : '進行中',
                  color: accent,
                ),
                if (reality != null)
                  _buildMetricChip(
                    '公式実数',
                    '${_formatInt(reality.currentMembers)}人',
                    color: const Color(0xFF0891B2),
                  ),
                if (plan.cdpLocalMembers > 0)
                  _buildMetricChip(
                    '立憲参考',
                    '${_formatInt(plan.cdpLocalMembers)}人',
                    color: const Color(0xFFDC2626),
                  ),
                if (plan.cdpLocalMembers > 0)
                  _buildMetricChip(
                    '地力差',
                    _formatCdpGap(plan),
                    color: plan.cdpMemberGap > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF0F766E),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ElectionNewsBadge(prefecture: plan.prefecture),
            _buildKgiCsfKpiPanel(plan),
            const SizedBox(height: 12),
            _buildPrefectureOfficerPanel(plan),
            if (reality != null) ...[
              const SizedBox(height: 12),
              Text(
                '公式内訳: 都道府県議 ${_formatInt(reality.prefecturalAssemblyMembers)} / '
                '市区町村議 ${_formatInt(reality.municipalAssemblyMembers)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (plan.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                plan.notes,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrefectureOfficerPanel(LocalElectionPrefecturePlan plan) {
    const accent = Color(0xFF7C3AED);
    final chair = plan.prefectureChairName.trim().isEmpty
        ? '公式未確認'
        : plan.prefectureChairName.trim();
    final secretary = plan.prefectureSecretaryGeneralName.trim().isEmpty
        ? '公式未確認'
        : plan.prefectureSecretaryGeneralName.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(
                '県連役員',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip('県連代表', chair, color: accent),
              _buildMetricChip('幹事長', secretary, color: accent),
            ],
          ),
          if (plan.prefectureOfficerSourceUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '出典: ${plan.prefectureOfficerSourceUrl}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKgiCsfKpiPanel(LocalElectionPrefecturePlan plan) {
    const accent = Color(0xFF2563EB);
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(Icons.flag_outlined, color: accent),
          title: Text(
            'KGI ${_formatInt(plan.kgiTargetLocalMembers)}人 / 残り${_formatInt(plan.kgiGapMembers)}人',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          subtitle: Text(
            plan.kgiStatement,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            LinearProgressIndicator(
              value: plan.kgiProgressRatio,
              minHeight: 8,
              backgroundColor: accent.withValues(alpha: 0.12),
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 12),
            for (final item in plan.csfKpis) _buildCsfKpiRow(item),
          ],
        ),
      ),
    );
  }

  Widget _buildCsfKpiRow(LocalElectionCsfKpi item) {
    const accent = Color(0xFF0F766E);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.csf,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              Text(
                '${_formatInt(item.actual)}/${_formatInt(item.target)}${item.unit}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accent,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.kpiLabel} / 残り${_formatInt(item.remaining)}${item.unit}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: item.progressRatio,
            minHeight: 6,
            backgroundColor: accent.withValues(alpha: 0.12),
            color: accent,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, {Color? color}) {
    final chipColor = color ?? const Color(0xFF607D8B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: chipColor.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  String _formatCdpGap(LocalElectionPrefecturePlan plan) {
    final gap = plan.cdpMemberGap;
    if (gap > 0) {
      return '立憲+${_formatInt(gap)}';
    }
    if (gap < 0) {
      return '国民+${_formatInt(-gap)}';
    }
    return '同数';
  }

  Widget _buildMiniStatChip(
    String label,
    int value, {
    required Color color,
    String suffix = '人',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${_formatInt(value)}$suffix',
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildInlineNotice(
    String message, {
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color.withValues(alpha: 0.95),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('• '),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  LocalElectionPrefectureReality? _realityForPrefecture(String prefecture) {
    final snapshot = _realitySnapshot;
    if (snapshot == null) {
      return null;
    }
    final target = _normalizePrefectureKey(prefecture);
    for (final item in snapshot.prefectures) {
      if (_normalizePrefectureKey(item.prefecture) == target) {
        return item;
      }
    }
    return null;
  }

  String _normalizePrefectureKey(String value) {
    final trimmed = value.trim();
    if (trimmed == '北海道') {
      return trimmed;
    }
    if (trimmed.endsWith('都') ||
        trimmed.endsWith('府') ||
        trimmed.endsWith('県')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  String _buildClipboardSummary(LocalElectionPlanDashboard plan) {
    final base = StringBuffer(plan.buildClipboardSummary());
    final snapshot = _realitySnapshot;
    if (snapshot != null && snapshot.hasData) {
      base
        ..writeln()
        ..writeln()
        ..writeln('最新実データ')
        ..writeln(
          '取得日時: ${_dateTimeFormat.format(snapshot.fetchedAt.toLocal())}',
        )
        ..writeln('公式地方議員数: ${snapshot.officialCurrentLocalMembers}')
        ..writeln('基準340との差分: ${snapshot.deltaFromBaseline}')
        ..writeln('700まで残り: ${snapshot.actualNetIncreaseRequired}')
        ..writeln(
          _shareService.buildNextUnifiedLocalElectionCountdownLine(
            now: snapshot.fetchedAt.toLocal(),
          ),
        )
        ..writeln(
          '2023公式実績: ${snapshot.official2023FirstHalfWins} + '
          '${snapshot.official2023SecondHalfWins} = ${snapshot.official2023TotalWins}',
        );
      if (snapshot.aiSummary.isNotEmpty) {
        base.writeln('AI要約: ${snapshot.aiSummary}');
      }
      final topPrefectures = snapshot.topPrefectures(limit: 5);
      if (topPrefectures.isNotEmpty) {
        base.writeln('上位県:');
        for (final item in topPrefectures) {
          base.writeln(
            '- ${item.prefecture}: ${item.currentMembers}人 '
            '(都道府県議 ${item.prefecturalAssemblyMembers} / '
            '市区町村議 ${item.municipalAssemblyMembers})',
          );
        }
      }
    }
    return base.toString();
  }

  String _describeRealityError(Object error) {
    final message = error.toString();
    if (message.contains('Unauthorized') ||
        message.contains('authorization') ||
        message.contains('authorization header')) {
      return '最新データの取得にはログイン済みのSupabaseセッションが必要です。';
    }
    if (message.contains('Supabase client is not available')) {
      return 'Supabaseクライアントが初期化されていないため、最新データを取得できません。';
    }
    if (message.contains('CORS') ||
        message.contains('cors') ||
        message.contains('XMLHttpRequest') ||
        message.contains('Failed to fetch') ||
        message.contains('NetworkError')) {
      return 'Edge Function への接続がブロックされました (CORS)。しばらくしてから再試行してください。';
    }
    if (message.contains('TimeoutException') ||
        message.contains('timed out') ||
        message.contains('timeout')) {
      return '最新データの取得が時間切れになりました。外部公式サイトの応答が遅い可能性があります。少し待って再試行してください。';
    }
    return '最新データの取得に失敗しました。通信状態と Edge Function の設定を確認してください。';
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched || !mounted) {
      return;
    }
  }

  String _formatInt(int value) => _numberFormat.format(value);

  String _formatSignedInt(int value) {
    if (value > 0) {
      return '+${_formatInt(value)}';
    }
    return _formatInt(value);
  }
}

class _PrefectureLegendChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color borderColor;

  const _PrefectureLegendChip({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
