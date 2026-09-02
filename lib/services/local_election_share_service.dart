// ignore_for_file: require_trailing_commas

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/official_endorsement_repository.dart';
import '../models/local_election_plan.dart';
import '../models/local_election_reality.dart';
import '../models/public_memo.dart';

typedef LocalElectionMemoPublisher = Future<PublicMemo?> Function({
  required int noteId,
  required String userId,
  required String title,
  String? content,
  String? category,
  Map<String, dynamic> metadata,
});

typedef LocalElectionMemoLoader = Future<PublicMemo?> Function(
    {required int noteId, required String userId});

typedef _OfficialEndorsementTotals = ({
  int total,
  int incumbent,
  int newcomer,
  int former,
  int prefectures,
  String asOf,
});

class LocalElectionShareDraft {
  final int noteId;
  final String title;
  final String content;
  final Map<String, dynamic> metadata;

  const LocalElectionShareDraft({
    required this.noteId,
    required this.title,
    required this.content,
    required this.metadata,
  });
}

class LocalElectionShareWindow {
  final String label;
  final int weekendOffset;

  const LocalElectionShareWindow({
    required this.label,
    required this.weekendOffset,
  });
}

class LocalElectionShareWindowRange {
  final DateTime start;
  final DateTime end;

  const LocalElectionShareWindowRange({required this.start, required this.end});
}

class LocalElectionShareService {
  static const String publicCategory = '選挙ダッシュボード';
  static const String metadataType = 'local_election_snapshot';
  static const String planDashboardMetadataType =
      'local_election_plan_dashboard';
  static const int lowPresenceThreshold = 4;
  static const int maxWeekendWindowCount = 60;
  static const int _syntheticNoteIdBase = 90000000000000;
  static const int _planDashboardNoteId = _syntheticNoteIdBase + 7002027;

  static String generatedMemoSourceKey(int syntheticNoteId) =>
      'local-election:$syntheticNoteId';
  // 統一地方選 2027 の仮日程 (官報告示前の推定 / 単一正本)。
  // 告示日は公選法の告示日数ルールと 2023 実績 (前半: 知事選17日前 /
  // 後半: 市区議・市区長7日前) に合わせる。確定後はここだけ更新する。
  static final DateTime nextUnifiedLocalElectionFirstHalfTargetDate = DateTime(
    2027,
    4,
    11,
  );
  static final DateTime nextUnifiedLocalElectionFirstHalfAnnouncementDate =
      DateTime(2027, 3, 25);
  static final DateTime nextUnifiedLocalElectionSecondHalfTargetDate = DateTime(
    2027,
    4,
    25,
  );
  static final DateTime nextUnifiedLocalElectionSecondHalfAnnouncementDate =
      DateTime(2027, 4, 18);
  static final List<LocalElectionShareWindow> availableWindows =
      List<LocalElectionShareWindow>.unmodifiable(
    List<LocalElectionShareWindow>.generate(
      maxWeekendWindowCount,
      (index) => LocalElectionShareWindow(
        label: index == 0 ? '今週末' : '${index + 1}週後',
        weekendOffset: index,
      ),
    ),
  );

  final SupabaseClient _supabase;
  final LocalElectionMemoPublisher? _publishMemo;
  final LocalElectionMemoLoader? _loadMemo;
  final OfficialEndorsementRepository _officialEndorsementRepository;
  final DateFormat _dateOnlyFormat = DateFormat('yyyy/MM/dd', 'ja_JP');

  _OfficialEndorsementTotals _officialEndorsementTotals(
    LocalElectionRealitySnapshot? snapshot,
  ) {
    final resolved = _officialEndorsementRepository.resolve(
      snapshot?.electionIntelligence,
    );
    return (
      total: resolved.totalCount,
      incumbent: resolved.incumbentCount,
      newcomer: resolved.newcomerCount,
      former: resolved.formerCount,
      prefectures: resolved.prefectureCount,
      asOf: resolved.sourceAsOf,
    );
  }

  LocalElectionShareService(
    this._supabase, {
    LocalElectionMemoPublisher? publishMemo,
    LocalElectionMemoLoader? loadMemo,
    OfficialEndorsementRepository officialEndorsementRepository =
        const OfficialEndorsementRepository(),
  })  : _publishMemo = publishMemo,
        _loadMemo = loadMemo,
        _officialEndorsementRepository = officialEndorsementRepository;

  Future<PublicMemo?> publishSnapshot({
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionLegislatorProfile> members,
    LocalElectionPlanDashboard? plan,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final draft = buildDraft(snapshot: snapshot, members: members, plan: plan);
    final publishMemo = _publishMemo;
    if (publishMemo == null) {
      return null;
    }
    return publishMemo(
      noteId: draft.noteId,
      userId: userId,
      title: draft.title,
      content: draft.content,
      category: publicCategory,
      metadata: draft.metadata,
    );
  }

  Future<PublicMemo?> loadPublishedSnapshot(
    LocalElectionRealitySnapshot snapshot,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    final loadMemo = _loadMemo;
    if (loadMemo == null) {
      return null;
    }
    return loadMemo(noteId: buildSyntheticNoteId(snapshot), userId: userId);
  }

  Future<PublicMemo?> publishPlanDashboard({
    required LocalElectionPlanDashboard plan,
    LocalElectionRealitySnapshot? snapshot,
    required String publicDashboardUrl,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    final publishMemo = _publishMemo;
    if (publishMemo == null) {
      return null;
    }

    final draft = buildPlanDashboardDraft(
      plan: plan,
      snapshot: snapshot,
      publicDashboardUrl: publicDashboardUrl,
    );
    return publishMemo(
      noteId: draft.noteId,
      userId: userId,
      title: draft.title,
      content: draft.content,
      category: publicCategory,
      metadata: draft.metadata,
    );
  }

  Future<PublicMemo?> loadPublishedPlanDashboard() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }
    final loadMemo = _loadMemo;
    if (loadMemo == null) {
      return null;
    }
    return loadMemo(noteId: _planDashboardNoteId, userId: userId);
  }

  LocalElectionShareDraft buildDraft({
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionLegislatorProfile> members,
    LocalElectionPlanDashboard? plan,
  }) {
    final resolvedMembers = _sortedMembers(members);
    final prefectures = _prefecturesForDisplay(snapshot);
    final title =
        '国民民主党 地方議員集計 ${_dateOnlyFormat.format(snapshot.fetchedAt.toLocal())}';

    return LocalElectionShareDraft(
      noteId: buildSyntheticNoteId(snapshot),
      title: title,
      content: _buildContent(
        title: title,
        snapshot: snapshot,
        prefectures: prefectures,
        members: resolvedMembers,
        plan: plan,
      ),
      metadata: _buildMetadata(
        snapshot: snapshot,
        prefectures: prefectures,
        members: resolvedMembers,
        plan: plan,
      ),
    );
  }

  LocalElectionShareDraft buildPlanDashboardDraft({
    required LocalElectionPlanDashboard plan,
    LocalElectionRealitySnapshot? snapshot,
    required String publicDashboardUrl,
  }) {
    final title =
        '統一地方選700 県連KPI一覧 ${_dateOnlyFormat.format(plan.updatedAt.toLocal())}';
    return LocalElectionShareDraft(
      noteId: _planDashboardNoteId,
      title: title,
      content: _buildPlanDashboardContent(
        title: title,
        plan: plan,
        snapshot: snapshot,
        publicDashboardUrl: publicDashboardUrl,
      ),
      metadata: _buildPlanDashboardMetadata(
        plan: plan,
        snapshot: snapshot,
        publicDashboardUrl: publicDashboardUrl,
      ),
    );
  }

  /// R24: 選挙集計スレッドを growth-hub x.post へ渡す payload(純関数・VMテスト可)。
  /// variant と content_archetype を明示し、8K 実測級の投稿を学習ループ
  /// (variant ranking / Archetype lift) の計測対象にする。
  static Map<String, dynamic> buildElectionXPostPayload(List<String> tweets) {
    final cleaned = tweets
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return const {};
    return {
      'action': 'x.post',
      'text': cleaned.first,
      if (cleaned.length > 1) 'replyTexts': cleaned.sublist(1),
      'source': 'local_election_tracker',
      'variant': 'local_election_tracker',
      'contentArchetype': 'data_report',
      'experimentKey': 'x_first_user_growth_10k',
    };
  }

  /// R24: composer のスレッドを growth-hub x.post 経由で直接投稿する。従来は
  /// コピー/X intent の手動投稿のみで x_post_log に残らず、データレポート型
  /// (実測 8K インプ)の勝ちが学習ループから不可視だった。
  Future<Map<String, dynamic>> postThreadToXViaApi(List<String> tweets) async {
    final payload = buildElectionXPostPayload(tweets);
    if (payload.isEmpty) {
      return {'success': false, 'error': '投稿できるテキストがありません'};
    }
    final res = await _supabase.functions.invoke('growth-hub', body: payload);
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': false, 'error': '不明な応答形式'};
  }

  String buildXShareText({
    required LocalElectionRealitySnapshot snapshot,
    required String publicUrl,
  }) {
    if (publicUrl.isNotEmpty) {
      final body = buildXShareBody(snapshot: snapshot);
      return '$body\n\n$publicUrl';
    }
    final prefectures = _prefecturesForDisplay(snapshot);
    final missingCount =
        prefectures.where((item) => item.currentMembers == 0).length;
    final lowCount = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .length;
    final topPrefectures = snapshot.topPrefectures(limit: 3);

    final lines = <String>[
      '国民民主党の地方議員数 ${_dateOnlyFormat.format(snapshot.fetchedAt.toLocal())}',
      '${snapshot.officialCurrentLocalMembers}人',
      '700まで残り${snapshot.actualNetIncreaseRequired}人',
      buildNextUnifiedLocalElectionCountdownLine(
        now: snapshot.fetchedAt.toLocal(),
      ),
      '',
      '🔴議員不在 $missingCount県',
      '🟡要強化($lowPresenceThreshold人以下) $lowCount県',
      if (topPrefectures.isNotEmpty) '',
      for (final item in topPrefectures)
        '${item.prefecture} ${item.currentMembers}人',
      '',
      '全47都道府県の内訳と現職名簿を公開ノートに整理しました。',
      publicUrl,
    ];

    return lines.join('\n').trim();
  }

  String buildXShareBody({required LocalElectionRealitySnapshot snapshot}) {
    return buildXShareText(snapshot: snapshot, publicUrl: '');
  }

  /// X の投稿長制限(25,000)は twitter-text の加重文字数で数えられる:
  /// CJK/全角=2、半角(Latin 等)=1、URL=一律23。日本語主体の集計本文を Dart の
  /// code unit 数で測ると実重みのほぼ半分にしか見えず、上限超過を素通しする
  /// (レビュー指摘)。ここでは全文字を範囲判定で加重する近似を使う(ASCII の
  /// URL を 1/字で数える=実際の 23/URL より過大評価で安全側)。
  static int xWeightedLength(String text) {
    var weighted = 0;
    for (final rune in text.runes) {
      weighted += rune < 0x1100 ? 1 : 2;
    }
    return weighted;
  }

  /// R24: 地方議員集計を growth-hub x.post(API 投稿)へ載せるための長文本文。
  /// intent 投稿は x_post_log の外=Archetype lift 計測に入らないため、実測
  /// 累積8Kの既存ポストA（後続A/B実測3.2K）と同じ集計ノート全文を、
  /// API 経由の第一級経路に
  /// する。X Premium 上限(25,000 weighted)に対し [maxWeightedChars] で安全側に
  /// 収め、超過時は名簿セクション境界(\n\n◽️)で切り詰めて公開ノートへ誘導する。
  String buildXPostLongText({
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionLegislatorProfile> members,
    LocalElectionPlanDashboard? plan,
    String publicUrl = '',
    int maxWeightedChars = 24000,
  }) {
    final draft = buildDraft(snapshot: snapshot, members: members, plan: plan);
    final suffix =
        publicUrl.isEmpty ? '' : '\n\n全都道府県の内訳と現職名簿の公開ノート:\n$publicUrl';
    final body = draft.content.trim();
    if (xWeightedLength(body) + xWeightedLength(suffix) <= maxWeightedChars) {
      return '$body$suffix';
    }
    // 公開ノート URL が無いときは「続きは公開ノートへ」と書かない(リンクの
    // 無い誘導文が公開されたまま残る事故を防ぐ。呼び出し側でも memo 発行失敗
    // 時は投稿自体を中止する)。
    final truncationNote = publicUrl.isEmpty
        ? '\n\n(文字数上限のため名簿は途中まで)'
        : '\n\n(文字数上限のため名簿の続きは公開ノートへ)';
    final budget = maxWeightedChars -
        xWeightedLength(suffix) -
        xWeightedLength(truncationNote);
    if (budget <= 0) {
      return buildXShareText(snapshot: snapshot, publicUrl: publicUrl);
    }
    // weighted budget 内に収まる最大の code-unit 位置を前方走査で求める。
    var weighted = 0;
    var cutLimit = 0;
    for (final rune in body.runes) {
      final w = rune < 0x1100 ? 1 : 2;
      if (weighted + w > budget) {
        break;
      }
      weighted += w;
      cutLimit += rune > 0xFFFF ? 2 : 1;
    }
    var cut = body.lastIndexOf('\n\n◽️', cutLimit);
    if (cut < 0) {
      cut = body.lastIndexOf('\n\n', cutLimit);
    }
    if (cut <= 0) {
      cut = cutLimit;
    }
    return '${body.substring(0, cut).trimRight()}$truncationNote$suffix';
  }

  Uri buildXShareIntentUri({
    required LocalElectionRealitySnapshot snapshot,
    required String publicUrl,
  }) {
    return Uri.https('x.com', '/intent/tweet', <String, String>{
      'text': buildXShareBody(snapshot: snapshot),
      'url': publicUrl,
    });
  }

  String buildPlanDashboardXShareText({
    required LocalElectionPlanDashboard plan,
    required String publicUrl,
  }) {
    final body = buildPlanDashboardXShareBody(plan: plan);
    if (publicUrl.isEmpty) {
      return body;
    }
    return '$body\n\n$publicUrl';
  }

  String buildPlanDashboardXShareBody({
    required LocalElectionPlanDashboard plan,
  }) {
    // X は文字数制限があるため、公認予定候補は掲載がある場合だけ1行足す。
    final endorsements = _officialEndorsementRepository.fallbackSnapshot;
    final hasOfficialEndorsement = endorsements.hasData;
    return [
      '統一地方選700 県連KPI一覧',
      '全${plan.prefectures.length}県連のKGI、CSF、KPI、現職人数、候補者進捗、公認期限、立憲・自民の参考値を公開ノートにまとめました。',
      '現職 ${plan.currentLocalMembers}人 / 700まで残り${plan.requiredNetIncrease}人',
      if (hasOfficialEndorsement)
        '公認予定候補 ${endorsements.totalCount}件'
            '(現職${endorsements.incumbentCount}/'
            '新人${endorsements.newcomerCount}/'
            '元職${endorsements.formerCount})',
      buildNextUnifiedLocalElectionCountdownLine(now: plan.updatedAt.toLocal()),
      '純増目標 ${plan.allocatedNetIncrease}人 / 新人 ${plan.totalNewCandidateTarget}人',
      '#統一地方選 #国民民主党',
    ].join('\n');
  }

  int daysUntilNextUnifiedLocalElection({DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final target = _dateOnly(nextUnifiedLocalElectionFirstHalfTargetDate);
    final days = target.difference(today).inDays;
    return days < 0 ? 0 : days;
  }

  String buildNextUnifiedLocalElectionCountdownLine({DateTime? now}) {
    final dateLabel = _dateOnlyFormat.format(
      nextUnifiedLocalElectionFirstHalfTargetDate,
    );
    final days = daysUntilNextUnifiedLocalElection(now: now);
    return '次回統一地方選($dateLabel目安)まであと$days日';
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  Uri buildPlanDashboardXShareIntentUri({
    required LocalElectionPlanDashboard plan,
    required String publicUrl,
  }) {
    return Uri.https('x.com', '/intent/tweet', <String, String>{
      'text': buildPlanDashboardXShareBody(plan: plan),
      if (publicUrl.isNotEmpty) 'url': publicUrl,
    });
  }

  String buildPrefectureKpiXShareText({
    required LocalElectionPrefecturePlan plan,
    LocalElectionPrefectureReality? reality,
    required String publicUrl,
  }) {
    final body = buildPrefectureKpiXShareBody(plan: plan, reality: reality);
    if (publicUrl.isEmpty) {
      return body;
    }
    return '$body\n\n$publicUrl';
  }

  String buildPrefectureKpiXShareBody({
    required LocalElectionPrefecturePlan plan,
    LocalElectionPrefectureReality? reality,
  }) {
    final currentMembers = reality?.currentMembers ?? plan.currentMembers;
    final realityCdpMembers = reality?.cdpLocalMembers ?? 0;
    final cdpMembers = plan.cdpLocalMembers >= realityCdpMembers
        ? plan.cdpLocalMembers
        : realityCdpMembers;
    final gap = cdpMembers - currentMembers;

    final lines = <String>[
      '${plan.prefecture} 県連KPI',
      '現職 $currentMembers人 / 純増目標 ${plan.additionalSeatTarget}人 / 新人 ${plan.newCandidateTarget}人',
      '重点自治体 ${plan.focusMunicipalityCount} / 予定選挙 ${plan.scheduledElectionCount}件 / 支援 ${plan.closeRaceSupportRounds}回',
      plan.endorsementConfirmed
          ? '公認内定済み'
          : '公認内定期限 ${formatMonthKey(plan.endorsementDeadlineMonth)}',
      if (cdpMembers > 0)
        '立憲参考 $cdpMembers人 / 地力差 ${_formatPrefectureKpiGap(gap)}',
      if (reality != null)
        '公式内訳 都道府県議 ${reality.prefecturalAssemblyMembers} / 市区町村議 ${reality.municipalAssemblyMembers}',
      '#統一地方選 #国民民主党',
    ];

    return lines.join('\n').trim();
  }

  Uri buildPrefectureKpiXShareIntentUri({
    required LocalElectionPrefecturePlan plan,
    LocalElectionPrefectureReality? reality,
    required String publicUrl,
  }) {
    return Uri.https('x.com', '/intent/tweet', <String, String>{
      'text': buildPrefectureKpiXShareBody(plan: plan, reality: reality),
      if (publicUrl.isNotEmpty) 'url': publicUrl,
    });
  }

  LocalElectionShareWindowRange scheduleWindowRange(
    LocalElectionShareWindow window, {
    DateTime? now,
  }) {
    final today = _normalizeDate(now ?? DateTime.now());
    final daysUntilSunday = (DateTime.sunday - today.weekday) % 7;
    final baseSunday = today.add(Duration(days: daysUntilSunday));
    final baseSaturday = baseSunday.subtract(const Duration(days: 1));
    final offset = Duration(days: window.weekendOffset * 7);

    return LocalElectionShareWindowRange(
      start: baseSaturday.add(offset),
      end: baseSunday.add(offset),
    );
  }

  List<LocalElectionScheduleEntry> schedulesForWindow({
    required LocalElectionRealitySnapshot snapshot,
    required LocalElectionShareWindow window,
    DateTime? now,
  }) {
    final range = scheduleWindowRange(window, now: now);
    final schedules = snapshot.targetElectionSchedules.where((entry) {
      if (entry.isPast) {
        return false;
      }
      final voteDate = entry.parsedVoteDate;
      if (voteDate == null) {
        return false;
      }
      final localDate = _normalizeDate(voteDate.toLocal());
      return !localDate.isBefore(range.start) && !localDate.isAfter(range.end);
    }).toList()
      ..sort((a, b) {
        final aDate = a.parsedVoteDate ?? DateTime(9999);
        final bDate = b.parsedVoteDate ?? DateTime(9999);
        if (aDate != bDate) {
          return aDate.compareTo(bDate);
        }
        final prefectureCompare = a.prefecture.compareTo(b.prefecture);
        if (prefectureCompare != 0) {
          return prefectureCompare;
        }
        return a.electionName.compareTo(b.electionName);
      });
    return schedules;
  }

  String buildWindowDateRangeLabel(
    LocalElectionShareWindow window, {
    DateTime? now,
  }) {
    final range = scheduleWindowRange(window, now: now);
    final s = range.start;
    final e = range.end;
    return '${s.month}/${s.day}〜${e.month}/${e.day}';
  }

  /// Builds a Twitter/X thread for upcoming local elections with 0 Kokumin candidates.
  /// Returns a list of tweet texts forming a thread.
  /// Tweet 1: intro sentence + all prefecture blocks (no char truncation — user edits in dialog).
  /// Tweet 2: current member stats + top prefectures + public memo link.
  ///
  /// Specify either [weekendSaturday] (weekend-based) or [daysAhead] (legacy).
  /// [weekendSaturday] takes precedence when provided.
  List<String> buildUpcomingElectionsThread({
    required LocalElectionRealitySnapshot snapshot,
    String publicUrl = '',
    DateTime? weekendSaturday,
    int daysAhead = 7,
  }) {
    final List<LocalElectionScheduleEntry> upcoming;
    if (weekendSaturday != null) {
      upcoming = snapshot.schedulesOnWeekend(weekendSaturday)
        ..sort((a, b) {
          final aDate = a.parsedVoteDate ?? DateTime(9999);
          final bDate = b.parsedVoteDate ?? DateTime(9999);
          if (aDate != bDate) return aDate.compareTo(bDate);
          return a.prefecture.compareTo(b.prefecture);
        });
    } else {
      upcoming = snapshot
          .schedulesWithinDays(daysAhead)
          .where((e) => !e.isPast)
          .toList()
        ..sort((a, b) {
          final aDate = a.parsedVoteDate ?? DateTime(9999);
          final bDate = b.parsedVoteDate ?? DateTime(9999);
          if (aDate != bDate) return aDate.compareTo(bDate);
          return a.prefecture.compareTo(b.prefecture);
        });
    }

    final noCandidate =
        upcoming.where((e) => e.kokuminCandidateCount == 0).toList();
    final total = upcoming.length;
    final noCount = noCandidate.length;

    final tweets = <String>[];

    // --- Tweet 1: intro + ALL election entries grouped by prefecture ---
    final byPref = <String, List<LocalElectionScheduleEntry>>{};
    for (final e in upcoming) {
      byPref.putIfAbsent(e.prefecture, () => []).add(e);
    }

    // Build human-readable date label for the weekend
    final String weekendLabel;
    if (weekendSaturday != null) {
      weekendLabel =
          '${weekendSaturday.month}/${weekendSaturday.day}(土)〜${weekendSaturday.add(const Duration(days: 1)).month}/${weekendSaturday.add(const Duration(days: 1)).day}(日)';
    } else {
      weekendLabel = '今週末';
    }

    final String introText;
    if (upcoming.isEmpty) {
      return ['$weekendLabel投開票日の地方選挙はありません。'];
    }
    if (noCount > 0) {
      final candidatePhrase = noCount == total ? '1人も' : '$noCount件';
      introText = '$weekendLabel投開票日の地方選挙が$total件ありますが、'
          '国民民主党は独自公認候補を$candidatePhrase擁立できていません。'
          '痛恨の極みです。こんな状況では統一地方選までに地方議員700人など絶対に達成できません。';
    } else {
      introText = '$weekendLabel投開票日の地方選挙が$total件あります。'
          '国民民主党は全選挙に候補者を擁立しています！';
    }

    const prefOrder = _allPrefectures;
    final sortedPrefs = byPref.keys.toList()
      ..sort((a, b) {
        final ai = prefOrder.indexOf(a);
        final bi = prefOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    // Build tweet 1 — include ALL prefecture blocks (no 280-char truncation).
    // The dialog's char counter alerts the user if manual splitting is needed.
    final tweet1Buffer = StringBuffer(introText);
    for (final pref in sortedPrefs) {
      final elections = byPref[pref]!;
      tweet1Buffer.write('\n\n$pref');
      for (final e in elections) {
        final candidateLine = _buildScheduleCandidateLine(e);
        tweet1Buffer.write('\n${e.electionName}');
        if (candidateLine.isNotEmpty) {
          tweet1Buffer.write('：$candidateLine');
        }
      }
    }
    tweets.add(tweet1Buffer.toString().trim());

    // --- Tweet 2: statistics + top prefectures + link ---
    final prefectures = _prefecturesForDisplay(snapshot);
    final missingCount =
        prefectures.where((item) => item.currentMembers == 0).length;
    final lowCount = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .length;
    final topPrefs = snapshot.topPrefectures(limit: 3);
    final dateStr = _dateOnlyFormat.format(snapshot.fetchedAt.toLocal());

    final stats = <String>[
      '国民民主党の地方議員数 $dateStr',
      '${snapshot.officialCurrentLocalMembers}人',
      '700まで残り${snapshot.actualNetIncreaseRequired}人',
      buildNextUnifiedLocalElectionCountdownLine(
        now: snapshot.fetchedAt.toLocal(),
      ),
      '',
      '🔴議員不在 $missingCount県',
      '🟡要強化($lowPresenceThreshold人以下) $lowCount県',
      '',
    ];
    for (final p in topPrefs) {
      stats.add('${p.prefecture} ${p.currentMembers}人');
    }
    if (publicUrl.isNotEmpty) {
      stats
        ..add('')
        ..add('全47都道府県の内訳と現職名簿を公開ノートに整理しました。')
        ..add(publicUrl);
    }
    tweets.add(stats.join('\n').trim());

    return tweets;
  }

  int buildSyntheticNoteId(LocalElectionRealitySnapshot snapshot) {
    final dateKey = int.parse(
      _dateOnlyFormat.format(snapshot.fetchedAt.toLocal()).replaceAll('/', ''),
    );
    return _syntheticNoteIdBase + dateKey;
  }

  String _buildContent({
    required String title,
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionPrefectureReality> prefectures,
    required List<LocalElectionLegislatorProfile> members,
    LocalElectionPlanDashboard? plan,
  }) {
    final endorsementTotals = _officialEndorsementTotals(snapshot);
    final dpjOfficialEndorsementTotal = endorsementTotals.total;
    final dpjOfficialEndorsementIncumbentTotal = endorsementTotals.incumbent;
    final dpjOfficialEndorsementNewcomerTotal = endorsementTotals.newcomer;
    final dpjOfficialEndorsementFormerTotal = endorsementTotals.former;
    final dpjOfficialEndorsementPrefectureCount = endorsementTotals.prefectures;
    final cdpByPrefecture = _cdpByPrefecture(plan);
    final missing =
        prefectures.where((item) => item.currentMembers == 0).toList();
    final low = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .toList();

    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln('取得日時: ${snapshot.fetchedAt.toLocal().toIso8601String()}')
      ..writeln('公式地方議員数: ${snapshot.officialCurrentLocalMembers}人')
      ..writeln('基準340との差分: ${snapshot.deltaFromBaseline}人')
      ..writeln('700まで残り: ${snapshot.actualNetIncreaseRequired}人')
      ..writeln(
        buildNextUnifiedLocalElectionCountdownLine(
          now: snapshot.fetchedAt.toLocal(),
        ),
      )
      ..writeln(
        '2023年統一地方選実績: ${snapshot.official2023FirstHalfWins} + '
        '${snapshot.official2023SecondHalfWins} = ${snapshot.official2023TotalWins}',
      )
      ..writeln(
        '議員在籍県数: ${prefectures.where((item) => item.currentMembers > 0).length}県',
      )
      ..writeln('現職名簿件数: ${members.length}人');

    // 画面に出している比較指標 (公認予定候補 / 自民地力差) を共有本文にも載せる。
    // 載せないと「ノート化」「X投稿」した先で最新の重要指標だけが欠落する。
    if (dpjOfficialEndorsementTotal > 0) {
      buffer.writeln(
        '公認予定候補: $dpjOfficialEndorsementTotal件'
        '(現職$dpjOfficialEndorsementIncumbentTotal / '
        '新人$dpjOfficialEndorsementNewcomerTotal / '
        '元職$dpjOfficialEndorsementFormerTotal) '
        '※$dpjOfficialEndorsementPrefectureCount/47都道府県に掲載',
      );
    }
    final ldpTotal = plan?.totalLdpLocalMembers ?? 0;
    if (ldpTotal > 0) {
      buffer.writeln('自民地方議員参考合計: $ldpTotal人(総務省 所属党派別人員調)');
    }

    if (snapshot.aiSummary.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('AI要約')
        ..writeln(snapshot.aiSummary.trim());
    }

    final alerts = displayAiAlerts(snapshot, plan);
    if (alerts.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('注視ポイント');
      for (final item in alerts) {
        buffer.writeln('- $item');
      }
    }

    if (snapshot.aiStrategicNotes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('戦略メモ');
      for (final item in snapshot.aiStrategicNotes) {
        buffer.writeln('- $item');
      }
    }

    buffer
      ..writeln()
      ..writeln('アラート');
    if (missing.isEmpty) {
      buffer.writeln('- 🔴議員不在県なし');
    } else {
      buffer.writeln(
        '- 🔴議員不在 ${missing.length}県: ${missing.map((item) => item.prefecture).join('、')}',
      );
    }
    if (low.isEmpty) {
      buffer.writeln('- 🟡要強化県なし');
    } else {
      buffer.writeln(
        '- 🟡要強化($lowPresenceThreshold人以下) ${low.length}県: ${low.map((item) => item.prefecture).join('、')}',
      );
    }

    buffer
      ..writeln()
      ..writeln('全都道府県内訳');
    for (final prefecture in prefectures) {
      buffer.writeln(
        '${_prefectureMarker(prefecture)}${prefecture.prefecture} '
        '地方議員 ${prefecture.currentMembers}人 '
        '立憲参考 ${_resolveCdpLocalMembers(prefecture, cdpByPrefecture)}人 '
        '都道府県議 ${prefecture.prefecturalAssemblyMembers} / '
        '市区町村議 ${prefecture.municipalAssemblyMembers}',
      );
    }

    buffer
      ..writeln()
      ..writeln('現職地方議員名簿');
    // Defensive sort: prefecture グルーピングを直前要素との比較で行うため、
    // 呼び出し元のソート順に依存せずここで再ソートして安全側に倒す。
    final rosterMembers = _sortedMembers(members);
    String? currentPrefecture;
    for (final member in rosterMembers) {
      final prefecture = member.prefecture.trim();
      if (prefecture != currentPrefecture) {
        currentPrefecture = prefecture;
        buffer
          ..writeln()
          ..writeln('◽️ 国民民主党$prefecture現職地方議員');
      }
      buffer.writeln(_describeMember(member));
    }

    if (snapshot.sources.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('公式ソース');
      for (final source in snapshot.sources) {
        buffer.writeln('- ${source.label}: ${source.url}');
      }
    }

    return buffer.toString().trimRight();
  }

  Map<String, dynamic> _buildMetadata({
    required LocalElectionRealitySnapshot snapshot,
    required List<LocalElectionPrefectureReality> prefectures,
    required List<LocalElectionLegislatorProfile> members,
    LocalElectionPlanDashboard? plan,
  }) {
    final cdpByPrefecture = _cdpByPrefecture(plan);
    final missing =
        prefectures.where((item) => item.currentMembers == 0).toList();
    final low = prefectures
        .where(
          (item) =>
              item.currentMembers > 0 &&
              item.currentMembers <= lowPresenceThreshold,
        )
        .toList();

    return <String, dynamic>{
      'type': metadataType,
      'snapshotDate': _dateOnlyFormat.format(snapshot.fetchedAt.toLocal()),
      'fetchedAt': snapshot.fetchedAt.toIso8601String(),
      'nextUnifiedLocalElectionTargetDate': _dateOnlyFormat.format(
        nextUnifiedLocalElectionFirstHalfTargetDate,
      ),
      'daysUntilNextUnifiedLocalElection': daysUntilNextUnifiedLocalElection(
        now: snapshot.fetchedAt.toLocal(),
      ),
      'officialCurrentLocalMembers': snapshot.officialCurrentLocalMembers,
      'actualNetIncreaseRequired': snapshot.actualNetIncreaseRequired,
      'electionMode': snapshot.electionIntelligence.selectedMode.wireName,
      'electionIntelligenceSchemaVersion':
          snapshot.electionIntelligence.schemaVersion,
      'partyGoals': snapshot.electionIntelligence.goals
          .map((item) => item.toJson())
          .toList(),
      'electionAchievements': snapshot.electionIntelligence.achievements
          .map((item) => item.toJson())
          .toList(),
      'officialEndorsements':
          snapshot.electionIntelligence.officialEndorsements.toJson(),
      'cdpLocalMembers': prefectures.fold<int>(
        0,
        (sum, item) => sum + _resolveCdpLocalMembers(item, cdpByPrefecture),
      ),
      'activePrefectureCount':
          prefectures.where((item) => item.currentMembers > 0).length,
      'missingPrefectureCount': missing.length,
      'missingPrefectures': missing.map((item) => item.prefecture).toList(),
      'lowPresenceThreshold': lowPresenceThreshold,
      'lowPresencePrefectureCount': low.length,
      'lowPresencePrefectures': low.map((item) => item.prefecture).toList(),
      'rosterCount': members.length,
      'topPrefectures': snapshot
          .topPrefectures(limit: 5)
          .map(
            (item) => <String, dynamic>{
              'prefecture': item.prefecture,
              'currentMembers': item.currentMembers,
              'cdpLocalMembers': _resolveCdpLocalMembers(item, cdpByPrefecture),
            },
          )
          .toList(),
    };
  }

  String _buildPlanDashboardContent({
    required String title,
    required LocalElectionPlanDashboard plan,
    required LocalElectionRealitySnapshot? snapshot,
    required String publicDashboardUrl,
  }) {
    final endorsementTotals = _officialEndorsementTotals(snapshot);
    final dpjOfficialEndorsementTotal = endorsementTotals.total;
    final dpjOfficialEndorsementIncumbentTotal = endorsementTotals.incumbent;
    final dpjOfficialEndorsementNewcomerTotal = endorsementTotals.newcomer;
    final dpjOfficialEndorsementFormerTotal = endorsementTotals.former;
    final dpjOfficialEndorsementPrefectureCount = endorsementTotals.prefectures;
    final fetchedAt = snapshot?.fetchedAt.toLocal();
    final realityByPrefecture = <String, LocalElectionPrefectureReality>{
      if (snapshot != null)
        for (final item in snapshot.prefectures)
          _normalizePrefectureKey(item.prefecture): item,
    };

    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..writeln('公開ダッシュボード: $publicDashboardUrl')
      ..writeln('更新日時: ${plan.updatedAt.toLocal().toIso8601String()}');
    if (fetchedAt != null) {
      buffer.writeln('公式データ取得: ${fetchedAt.toIso8601String()}');
    }
    buffer
      ..writeln()
      ..writeln('全国サマリー')
      ..writeln('- 現職地方議員数: ${plan.currentLocalMembers}人')
      ..writeln('- 目標地方議員数: ${plan.targetLocalMembers}人')
      ..writeln('- 700まで残り: ${plan.requiredNetIncrease}人')
      ..writeln('- 県連配分済み純増: ${plan.allocatedNetIncrease}人')
      ..writeln('- 現職維持目標: ${plan.totalIncumbentRetentionTarget}人')
      ..writeln('- 重点自治体: ${plan.totalFocusMunicipalityCount}')
      ..writeln('- 新人擁立: ${plan.totalNewCandidateTarget}人')
      ..writeln(
        '- 想定当選率: ${LocalElectionPrefecturePlan.assumedCandidateWinRatePercent}%',
      )
      ..writeln('- 現状当選率: ${plan.currentCandidateWinRateLabel}')
      ..writeln('- 予定支援回数: ${plan.totalCloseRaceSupportRounds}回')
      ..writeln(
        '- 公認内定済み県連: '
        '${plan.confirmedEndorsementCount}/${plan.prefectures.length}',
      )
      ..writeln('- 立憲地方議員参考合計: ${plan.totalCdpLocalMembers}人')
      ..writeln(
        '- 自民地方議員参考合計: ${plan.totalLdpLocalMembers}人'
        '(総務省 所属党派別人員調)',
      )
      ..writeln(
        '- 公認予定候補: $dpjOfficialEndorsementTotal件'
        '(現職$dpjOfficialEndorsementIncumbentTotal / '
        '新人$dpjOfficialEndorsementNewcomerTotal / '
        '元職$dpjOfficialEndorsementFormerTotal) '
        '※$dpjOfficialEndorsementPrefectureCount/47都道府県に掲載',
      );

    buffer
      ..writeln()
      ..writeln('全県連KPI');
    for (final item in plan.prefecturesForRegion('すべて')) {
      final reality =
          realityByPrefecture[_normalizePrefectureKey(item.prefecture)];
      buffer.writeln(_describePlanPrefecture(item, reality));
    }

    buffer
      ..writeln()
      ..writeln('月次KPI');
    for (final item in plan.monthlyCheckpoints) {
      buffer.writeln(
        '- ${item.label}: 現職維持累計${item.cumulativeIncumbentRetentionTarget} / '
        '重点自治体累計${item.cumulativeFocusMunicipalityCount} / '
        '新人累計${item.cumulativeNewCandidateTarget} / '
        '内定期限到来${item.endorsementsDueThisMonth}県連 / '
        '支援累計${item.cumulativeCloseRaceSupportRounds}回',
      );
    }

    return buffer.toString().trimRight();
  }

  Map<String, dynamic> _buildPlanDashboardMetadata({
    required LocalElectionPlanDashboard plan,
    required LocalElectionRealitySnapshot? snapshot,
    required String publicDashboardUrl,
  }) {
    final endorsementTotals = _officialEndorsementTotals(snapshot);
    final dpjOfficialEndorsementTotal = endorsementTotals.total;
    final dpjOfficialEndorsementIncumbentTotal = endorsementTotals.incumbent;
    final dpjOfficialEndorsementNewcomerTotal = endorsementTotals.newcomer;
    final dpjOfficialEndorsementFormerTotal = endorsementTotals.former;
    final dpjOfficialEndorsementPrefectureCount = endorsementTotals.prefectures;
    final dpjLocalElectionOfficialListAsOf = endorsementTotals.asOf;
    return <String, dynamic>{
      'type': planDashboardMetadataType,
      'publicDashboardUrl': publicDashboardUrl,
      'updatedAt': plan.updatedAt.toIso8601String(),
      'snapshotFetchedAt': snapshot?.fetchedAt.toIso8601String(),
      'currentLocalMembers': plan.currentLocalMembers,
      'targetLocalMembers': plan.targetLocalMembers,
      'requiredNetIncrease': plan.requiredNetIncrease,
      'allocatedNetIncrease': plan.allocatedNetIncrease,
      'totalIncumbentRetentionTarget': plan.totalIncumbentRetentionTarget,
      'totalFocusMunicipalityCount': plan.totalFocusMunicipalityCount,
      'totalNewCandidateTarget': plan.totalNewCandidateTarget,
      'assumedCandidateWinRatePercent':
          LocalElectionPrefecturePlan.assumedCandidateWinRatePercent,
      'currentCandidateWinRatePercent': plan.currentCandidateWinRatePercent,
      'totalCloseRaceSupportRounds': plan.totalCloseRaceSupportRounds,
      'confirmedEndorsementCount': plan.confirmedEndorsementCount,
      'totalCdpLocalMembers': plan.totalCdpLocalMembers,
      'totalLdpLocalMembers': plan.totalLdpLocalMembers,
      'officialEndorsementTotal': dpjOfficialEndorsementTotal,
      'officialEndorsementIncumbent': dpjOfficialEndorsementIncumbentTotal,
      'officialEndorsementNewcomer': dpjOfficialEndorsementNewcomerTotal,
      'officialEndorsementFormer': dpjOfficialEndorsementFormerTotal,
      'officialEndorsementPrefectureCount':
          dpjOfficialEndorsementPrefectureCount,
      'officialEndorsementAsOf': dpjLocalElectionOfficialListAsOf,
      // 既存の共有ノート利用者向けに旧キーを当面維持する。
      'firstEndorsementTotal': dpjOfficialEndorsementTotal,
      'firstEndorsementIncumbent': dpjOfficialEndorsementIncumbentTotal,
      'firstEndorsementNewcomer': dpjOfficialEndorsementNewcomerTotal,
      'firstEndorsementPrefectureCount': dpjOfficialEndorsementPrefectureCount,
      'prefectures': plan.prefectures
          .map(
            (item) => <String, dynamic>{
              'prefecture': item.prefecture,
              'region': item.region,
              'currentMembers': item.currentMembers,
              'kgiTargetLocalMembers': item.kgiTargetLocalMembers,
              'kgiGapMembers': item.kgiGapMembers,
              'kgiProgressRatio': item.kgiProgressRatio,
              'additionalSeatTarget': item.additionalSeatTarget,
              'incumbentRetentionTarget': item.incumbentRetentionTarget,
              'focusMunicipalityCount': item.focusMunicipalityCount,
              'newCandidateTarget': item.newCandidateTarget,
              'candidateWinRatePercent': item.currentCandidateWinRatePercent,
              'announcedCandidateCount': item.announcedCandidateCount,
              'confirmedCandidateCount': item.confirmedCandidateCount,
              'scheduledElectionCount': item.scheduledElectionCount,
              'prefectureChairName': item.prefectureChairName,
              'prefectureSecretaryGeneralName':
                  item.prefectureSecretaryGeneralName,
              'prefectureOfficerSourceUrl': item.prefectureOfficerSourceUrl,
              'endorsementDeadlineMonth': item.endorsementDeadlineMonth,
              'endorsementConfirmed': item.endorsementConfirmed,
              'closeRaceSupportRounds': item.closeRaceSupportRounds,
              'cdpLocalMembers': item.cdpLocalMembers,
              'cdpMemberGap': item.cdpMemberGap,
              'ldpLocalMembers': item.ldpLocalMembers,
              'ldpMemberGap': item.ldpMemberGap,
              'csfKpis': item.csfKpis.map((kpi) => kpi.toJson()).toList(),
            },
          )
          .toList(),
    };
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

  List<LocalElectionLegislatorProfile> _sortedMembers(
    List<LocalElectionLegislatorProfile> members,
  ) {
    final sorted = List<LocalElectionLegislatorProfile>.from(members);

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

  String _describeMember(LocalElectionLegislatorProfile member) {
    // 形式: {議会ラベル} / {選挙区(区)} / {氏名} / {当選期数}
    // 例:   横浜市議 / 旭区 / 小粥 康弘 / 6期
    //       鎌倉市議 / 大石 香 / 1期   (区の無い市町村は選挙区を省略)
    final segments = <String>[
      if (member.assemblyLabel.trim().isNotEmpty) member.assemblyLabel.trim(),
      if (member.constituency.trim().isNotEmpty) member.constituency.trim(),
      member.name.trim(),
      if (member.electionCountLabel.trim().isNotEmpty)
        member.electionCountLabel.trim(),
    ];
    return segments.join(' / ');
  }

  String _describePlanPrefecture(
    LocalElectionPrefecturePlan plan,
    LocalElectionPrefectureReality? reality,
  ) {
    final currentMembers = reality?.currentMembers ?? plan.currentMembers;
    final cdpMembers = plan.cdpLocalMembers > 0
        ? plan.cdpLocalMembers
        : (reality?.cdpLocalMembers ?? 0);
    final segments = <String>[
      '${plan.prefecture}(${plan.region})',
      '現職$currentMembers人',
      'KGI${plan.kgiTargetLocalMembers}人(残${plan.kgiGapMembers}人)',
      'CSF/KPI ${plan.csfKpis.map((item) => item.compactLabel).join('; ')}',
      '純増${plan.additionalSeatTarget}人',
      '現職維持${plan.incumbentRetentionTarget}人',
      '重点自治体${plan.focusMunicipalityCount}',
      '新人擁立目標${plan.newCandidateTarget}人',
      '現状当選率${plan.currentCandidateWinRateLabel}',
      '県連代表${plan.prefectureChairName.isEmpty ? '公式未確認' : plan.prefectureChairName}',
      '幹事長${plan.prefectureSecretaryGeneralName.isEmpty ? '公式未確認' : plan.prefectureSecretaryGeneralName}',
      '確認済み候補者${plan.announcedCandidateCount}人',
      '公認/予定候補${plan.confirmedCandidateCount}人',
      '予定選挙${plan.scheduledElectionCount}件',
      plan.endorsementConfirmed
          ? '公認内定済み'
          : '公認期限${formatMonthKey(plan.endorsementDeadlineMonth)}',
      '支援${plan.closeRaceSupportRounds}回',
      if (cdpMembers > 0)
        '立憲参考$cdpMembers人(${_formatPrefectureKpiGap(cdpMembers - currentMembers)})',
      if (plan.ldpLocalMembers > 0)
        '自民参考${plan.ldpLocalMembers}人'
            '(${_formatPrefectureKpiGap(plan.ldpMemberGap, rivalLabel: '自民')})',
      if (reality != null)
        '公式内訳 都道府県議${reality.prefecturalAssemblyMembers}/市区町村議${reality.municipalAssemblyMembers}',
    ];
    return '- ${segments.join(' / ')}';
  }

  String _buildScheduleCandidateLine(LocalElectionScheduleEntry entry) {
    if (entry.kokuminCandidateNames.isEmpty) {
      return '';
    }

    return entry.kokuminCandidateNames.asMap().entries.map((candidate) {
      final status = candidate.key < entry.kokuminCandidateStatuses.length
          ? entry.kokuminCandidateStatuses[candidate.key].trim()
          : '';
      return status.isEmpty ? candidate.value : '${candidate.value}（$status）';
    }).join('、');
  }

  String _prefectureMarker(LocalElectionPrefectureReality item) {
    if (item.currentMembers == 0) {
      return '🔴 ';
    }
    if (item.currentMembers <= lowPresenceThreshold) {
      return '🟡 ';
    }
    return '';
  }

  /// 地力差ラベル。比較相手の党名は呼び出し側が渡す。
  /// (汎用名のまま '立憲+' を直書きすると、自民の差分に立憲ラベルが付いて
  /// しまうため必ず [rivalLabel] を明示する)
  String _formatPrefectureKpiGap(int gap, {String rivalLabel = '立憲'}) {
    if (gap > 0) {
      return '$rivalLabel+$gap';
    }
    if (gap < 0) {
      return '国民+${-gap}';
    }
    return '同数';
  }

  /// AI整理メモの注視ポイント。snapshot の edge function は立憲値を取得しない
  /// (週次cronが正本) ため立憲比較行が「取得していません」になる。週次cronで
  /// バッチ取得した立憲値 (plan に適用済み) から地力差を計算し、その行だけ差し替える。
  /// データが無ければ原文。
  List<String> displayAiAlerts(
    LocalElectionRealitySnapshot snapshot,
    LocalElectionPlanDashboard? plan,
  ) {
    final cdpLine = cdpBenchmarkAlertLine(plan);
    if (cdpLine == null) {
      return snapshot.aiAlerts;
    }
    final result = <String>[];
    var replaced = false;
    for (final alert in snapshot.aiAlerts) {
      if (!replaced && alert.contains('立憲')) {
        result.add(cdpLine);
        replaced = true;
      } else {
        result.add(alert);
      }
    }
    return result;
  }

  /// バッチ取得した立憲値を適用済みの plan から、立憲との地力差(上位3県)を edge
  /// function フォールバックと同じ書式で組み立てる。データが無ければ null。
  String? cdpBenchmarkAlertLine(LocalElectionPlanDashboard? plan) {
    if (plan == null) {
      return null;
    }
    final top = plan.topCdpGapPrefectures(limit: 3);
    if (top.isEmpty) {
      return null;
    }
    final parts = top.map((item) {
      final gap = item.cdpMemberGap;
      return '${item.prefecture}${gap >= 0 ? '+' : ''}$gap';
    }).join(' / ');
    return '立憲民主党との地力差（上位）：$parts。';
  }

  /// plan の各県のバッチ取得済み立憲値を正規化キーで索引する。plan が無ければ空。
  Map<String, int> _cdpByPrefecture(LocalElectionPlanDashboard? plan) {
    if (plan == null) {
      return const <String, int>{};
    }
    return <String, int>{
      for (final item in plan.prefectures)
        _normalizePrefectureKey(item.prefecture): item.cdpLocalMembers,
    };
  }

  /// snapshot の立憲値は edge function が取得せず常に 0 のため、plan のバッチ値が
  /// あればそれを優先する (_describePlanPrefecture のマージと同型 / 0・欠損は据置)。
  int _resolveCdpLocalMembers(
    LocalElectionPrefectureReality reality,
    Map<String, int> cdpByPrefecture,
  ) {
    final planCdp =
        cdpByPrefecture[_normalizePrefectureKey(reality.prefecture)];
    if (planCdp != null && planCdp > 0) {
      return planCdp;
    }
    return reality.cdpLocalMembers;
  }

  DateTime _normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

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
}

const List<String> _allPrefectures = <String>[
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
