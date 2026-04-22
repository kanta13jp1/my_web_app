import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_election_plan.dart';
import '../models/local_election_reality.dart';

enum LocalElectionPlanTemplate {
  focused,
  balanced,
}

class LocalElectionPlanService {
  static const String _storageKey = 'local_election_plan_v1';

  const LocalElectionPlanService();

  Future<LocalElectionPlanDashboard> loadPlan({
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final raw = store.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      final initial = buildDefaultPlan();
      await savePlan(initial, prefs: store);
      return initial;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        final initial = buildDefaultPlan();
        await savePlan(initial, prefs: store);
        return initial;
      }
      final plan = LocalElectionPlanDashboard.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (plan.prefectures.length != _prefectureSeeds.length) {
        final repaired = _repairPlan(plan);
        await savePlan(repaired, prefs: store);
        return repaired;
      }
      return plan;
    } catch (_) {
      final initial = buildDefaultPlan();
      await savePlan(initial, prefs: store);
      return initial;
    }
  }

  Future<LocalElectionPlanDashboard> savePlan(
    LocalElectionPlanDashboard plan, {
    SharedPreferences? prefs,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final normalized = _normalizePlan(plan);
    await store.setString(_storageKey, jsonEncode(normalized.toJson()));
    return normalized;
  }

  Future<LocalElectionPlanDashboard> resetPlan({
    LocalElectionPlanTemplate template = LocalElectionPlanTemplate.focused,
    SharedPreferences? prefs,
  }) async {
    final plan = buildDefaultPlan(template: template);
    return savePlan(plan, prefs: prefs);
  }

  LocalElectionPlanDashboard buildAutoUpdatedPlan(
    LocalElectionPlanDashboard plan,
    LocalElectionRealitySnapshot snapshot, {
    DateTime? now,
  }) {
    if (!snapshot.hasData) {
      return plan;
    }

    final updatedAt = now ?? DateTime.now();
    final realitiesByPrefecture = <String, LocalElectionPrefectureReality>{
      for (final item in snapshot.prefectures)
        _prefectureKey(item.prefecture): item,
    };
    final scheduleStatsByPrefecture = _scheduleStatsByPrefecture(snapshot);
    final additionalTargets = _allocateSnapshotAdditionalTargets(
      plan,
      snapshot,
      realitiesByPrefecture,
      scheduleStatsByPrefecture,
    );

    final prefectures = <LocalElectionPrefecturePlan>[];
    for (var index = 0; index < plan.prefectures.length; index++) {
      final current = plan.prefectures[index];
      final key = _prefectureKey(current.prefecture);
      final reality = realitiesByPrefecture[key];
      final stats = scheduleStatsByPrefecture[key] ?? _AutoScheduleStats.empty;
      final currentMembers = reality?.currentMembers ?? current.currentMembers;
      final cdpLocalMembers =
          reality?.cdpLocalMembers ?? current.cdpLocalMembers;
      final cdpSourceUrl = reality?.cdpSourceUrl ?? current.cdpSourceUrl;
      final scheduledElectionCount = stats.scheduledElectionCount;
      final additionalTarget = additionalTargets[index];
      final candidateTarget = math.max(
        additionalTarget,
        stats.kokuminCandidateCount +
            stats.redAlertCount +
            stats.yellowAlertCount,
      );
      final focusCount = math.max(
        2,
        math.max(currentMembers, scheduledElectionCount + stats.redAlertCount),
      );
      final supportRounds = math.max(
        2,
        scheduledElectionCount +
            stats.redAlertCount * 2 +
            stats.yellowAlertCount,
      );

      prefectures.add(
        current.copyWith(
          additionalSeatTarget: additionalTarget,
          incumbentRetentionTarget: currentMembers > 0
              ? currentMembers
              : current.incumbentRetentionTarget,
          focusMunicipalityCount: focusCount,
          newCandidateTarget: candidateTarget,
          endorsementDeadlineMonth: stats.earliestEndorsementMonth ??
              current.endorsementDeadlineMonth,
          closeRaceSupportRounds: supportRounds,
          currentMembers: currentMembers,
          scheduledElectionCount: scheduledElectionCount,
          cdpLocalMembers: cdpLocalMembers,
          cdpSourceUrl: cdpSourceUrl,
          autoUpdatedAt: updatedAt.toIso8601String(),
          endorsementConfirmed: stats.scheduledElectionCount > 0
              ? stats.redAlertCount == 0 && stats.confirmedCandidateCount > 0
              : current.endorsementConfirmed,
          notes: _mergeAutoNote(
            current.notes,
            stats: stats,
            currentMembers: currentMembers,
            cdpLocalMembers: cdpLocalMembers,
            updatedAt: updatedAt,
          ),
        ),
      );
    }

    return plan.copyWith(
      currentLocalMembers: snapshot.officialCurrentLocalMembers,
      targetLocalMembers: snapshot.targetLocalMembers,
      previousUnifiedElectionWins: snapshot.official2023TotalWins,
      previousUnifiedElectionFirstHalfWins: snapshot.official2023FirstHalfWins,
      previousUnifiedElectionSecondHalfWins:
          snapshot.official2023SecondHalfWins,
      updatedAt: updatedAt,
      prefectures: prefectures,
    );
  }

  LocalElectionPlanDashboard buildDefaultPlan({
    LocalElectionPlanTemplate template = LocalElectionPlanTemplate.focused,
    DateTime? now,
  }) {
    final additionalTargets = _allocateAdditionalTargets(template);
    final prefectures = <LocalElectionPrefecturePlan>[];

    for (var index = 0; index < _prefectureSeeds.length; index++) {
      final seed = _prefectureSeeds[index];
      final additionalTarget = additionalTargets[index];
      final focusMunicipalityCount = math.max(
        2,
        additionalTarget +
            (seed.tier == 1
                ? 5
                : seed.tier == 2
                    ? 3
                    : 2),
      );
      final newCandidateTarget = additionalTarget +
          (seed.tier == 1
              ? 3
              : seed.tier == 2
                  ? 2
                  : 1);
      final retentionTarget = math.max(
        1,
        (additionalTarget *
                (seed.tier == 1
                    ? 0.70
                    : seed.tier == 2
                        ? 0.60
                        : 0.50))
            .round(),
      );
      final supportRounds = math.max(
        2,
        (additionalTarget *
                (seed.tier == 1
                    ? 1.4
                    : seed.tier == 2
                        ? 1.2
                        : 1.0))
            .round(),
      );

      prefectures.add(
        LocalElectionPrefecturePlan(
          prefecture: seed.prefecture,
          region: seed.region,
          additionalSeatTarget: additionalTarget,
          incumbentRetentionTarget: retentionTarget,
          focusMunicipalityCount: focusMunicipalityCount,
          newCandidateTarget: newCandidateTarget,
          endorsementDeadlineMonth: _deadlineMonthForTier(seed.tier),
          closeRaceSupportRounds: supportRounds,
          notes: _defaultNoteForTier(seed.tier),
        ),
      );
    }

    return LocalElectionPlanDashboard(
      currentLocalMembers: 340,
      targetLocalMembers: 700,
      previousUnifiedElectionWins: 183,
      previousUnifiedElectionFirstHalfWins: 62,
      previousUnifiedElectionSecondHalfWins: 121,
      updatedAt: now ?? DateTime.now(),
      prefectures: prefectures,
    );
  }

  LocalElectionPlanDashboard _repairPlan(LocalElectionPlanDashboard stored) {
    final defaults = buildDefaultPlan();
    final byPrefecture = <String, LocalElectionPrefecturePlan>{
      for (final item in stored.prefectures) item.prefecture: item,
    };
    final repaired = <LocalElectionPrefecturePlan>[];
    for (final item in defaults.prefectures) {
      repaired.add(byPrefecture[item.prefecture] ?? item);
    }
    return stored.copyWith(
      updatedAt: stored.updatedAt == DateTime.fromMillisecondsSinceEpoch(0)
          ? DateTime.now()
          : stored.updatedAt,
      prefectures: repaired,
    );
  }

  LocalElectionPlanDashboard _normalizePlan(LocalElectionPlanDashboard plan) {
    final prefectures = <LocalElectionPrefecturePlan>[];
    for (final item in plan.prefectures) {
      prefectures.add(
        item.copyWith(
          additionalSeatTarget: clampPositiveInt(item.additionalSeatTarget),
          incumbentRetentionTarget: clampPositiveInt(
            item.incumbentRetentionTarget,
          ),
          focusMunicipalityCount: clampPositiveInt(item.focusMunicipalityCount),
          newCandidateTarget: clampPositiveInt(item.newCandidateTarget),
          closeRaceSupportRounds: clampPositiveInt(item.closeRaceSupportRounds),
          currentMembers: clampPositiveInt(item.currentMembers),
          scheduledElectionCount: clampPositiveInt(item.scheduledElectionCount),
          cdpLocalMembers: clampPositiveInt(item.cdpLocalMembers),
          cdpSourceUrl: item.cdpSourceUrl.trim(),
          endorsementDeadlineMonth:
              planningMonthKeys.contains(item.endorsementDeadlineMonth)
                  ? item.endorsementDeadlineMonth
                  : '2026-10',
          autoUpdatedAt: item.autoUpdatedAt.trim(),
          notes: item.notes.trim(),
        ),
      );
    }

    return plan.copyWith(
      currentLocalMembers: clampPositiveInt(plan.currentLocalMembers),
      targetLocalMembers: clampPositiveInt(plan.targetLocalMembers),
      previousUnifiedElectionWins: clampPositiveInt(
        plan.previousUnifiedElectionWins,
      ),
      previousUnifiedElectionFirstHalfWins: clampPositiveInt(
        plan.previousUnifiedElectionFirstHalfWins,
      ),
      previousUnifiedElectionSecondHalfWins: clampPositiveInt(
        plan.previousUnifiedElectionSecondHalfWins,
      ),
      updatedAt: plan.updatedAt,
      prefectures: prefectures,
    );
  }

  List<int> _allocateAdditionalTargets(LocalElectionPlanTemplate template) {
    const total = 360;
    final weights = <double>[
      for (final seed in _prefectureSeeds)
        switch (template) {
          LocalElectionPlanTemplate.focused => switch (seed.tier) {
              1 => 1.8,
              2 => 1.25,
              _ => 0.85,
            },
          LocalElectionPlanTemplate.balanced => 1.0,
        },
    ];

    final totalWeight = weights.fold<double>(
      0,
      (sum, weight) => sum + weight,
    );
    final rawShares = <double>[
      for (final weight in weights) total * weight / totalWeight,
    ];
    final floors = rawShares.map((value) => value.floor()).toList();
    var remainder = total - floors.fold<int>(0, (sum, value) => sum + value);

    final indexedFractions = <MapEntry<int, double>>[
      for (var index = 0; index < rawShares.length; index++)
        MapEntry(index, rawShares[index] - floors[index]),
    ]..sort((a, b) => b.value.compareTo(a.value));

    for (var index = 0;
        index < indexedFractions.length && remainder > 0;
        index++) {
      floors[indexedFractions[index].key] += 1;
      remainder--;
    }

    return floors;
  }

  String _deadlineMonthForTier(int tier) {
    switch (tier) {
      case 1:
        return '2026-09';
      case 2:
        return '2026-10';
      default:
        return '2026-11';
    }
  }

  String _defaultNoteForTier(int tier) {
    switch (tier) {
      case 1:
        return '主要都市部の重点自治体を先に固める';
      case 2:
        return '県庁所在地周辺で新人擁立を前倒しする';
      default:
        return '現職防衛と基礎票の掘り起こしを先行する';
    }
  }

  List<int> _allocateSnapshotAdditionalTargets(
    LocalElectionPlanDashboard plan,
    LocalElectionRealitySnapshot snapshot,
    Map<String, LocalElectionPrefectureReality> realitiesByPrefecture,
    Map<String, _AutoScheduleStats> scheduleStatsByPrefecture,
  ) {
    final total = math.max(0, snapshot.actualNetIncreaseRequired);
    if (total == 0 || plan.prefectures.isEmpty) {
      return List<int>.filled(plan.prefectures.length, 0);
    }

    final weights = <double>[
      for (final item in plan.prefectures)
        _autoTargetWeight(
          item,
          realitiesByPrefecture[_prefectureKey(item.prefecture)],
          scheduleStatsByPrefecture[_prefectureKey(item.prefecture)] ??
              _AutoScheduleStats.empty,
        ),
    ];
    final totalWeight = weights.fold<double>(0, (sum, value) => sum + value);
    if (totalWeight <= 0) {
      return _allocateAdditionalTargets(LocalElectionPlanTemplate.balanced);
    }

    final rawShares = <double>[
      for (final weight in weights) total * weight / totalWeight,
    ];
    final floors = rawShares.map((value) => value.floor()).toList();
    var remainder = total - floors.fold<int>(0, (sum, value) => sum + value);
    final indexedFractions = <MapEntry<int, double>>[
      for (var index = 0; index < rawShares.length; index++)
        MapEntry(index, rawShares[index] - floors[index]),
    ]..sort((a, b) => b.value.compareTo(a.value));

    for (var index = 0;
        index < indexedFractions.length && remainder > 0;
        index++) {
      floors[indexedFractions[index].key] += 1;
      remainder--;
    }
    return floors;
  }

  double _autoTargetWeight(
    LocalElectionPrefecturePlan plan,
    LocalElectionPrefectureReality? reality,
    _AutoScheduleStats stats,
  ) {
    final currentMembers = reality?.currentMembers ?? plan.currentMembers;
    final cdpLocalMembers = reality?.cdpLocalMembers ?? plan.cdpLocalMembers;
    final cdpGap = math.max(0, cdpLocalMembers - currentMembers);
    return 1 +
        currentMembers * 0.12 +
        cdpGap * 0.10 +
        stats.scheduledElectionCount * 1.45 +
        stats.redAlertCount * 2.2 +
        stats.yellowAlertCount * 0.9 +
        plan.additionalSeatTarget * 0.08;
  }

  Map<String, _AutoScheduleStats> _scheduleStatsByPrefecture(
    LocalElectionRealitySnapshot snapshot,
  ) {
    final stats = <String, _AutoScheduleStatsBuilder>{};
    for (final item in snapshot.upcomingSchedules) {
      if (item.isPast || item.prefecture.trim().isEmpty) {
        continue;
      }
      final key = _prefectureKey(item.prefecture);
      final builder = stats.putIfAbsent(key, _AutoScheduleStatsBuilder.new);
      builder.add(item);
    }
    return <String, _AutoScheduleStats>{
      for (final entry in stats.entries) entry.key: entry.value.build(),
    };
  }

  String _mergeAutoNote(
    String currentNotes, {
    required _AutoScheduleStats stats,
    required int currentMembers,
    required int cdpLocalMembers,
    required DateTime updatedAt,
  }) {
    final manualLines = currentNotes
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('AI自動更新:'))
        .toList();
    final date =
        '${updatedAt.year}/${updatedAt.month.toString().padLeft(2, '0')}/${updatedAt.day.toString().padLeft(2, '0')}';
    final autoLine = 'AI自動更新: 現職$currentMembers人 / '
        '立憲$cdpLocalMembers人 / '
        '予定選挙${stats.scheduledElectionCount}件 / '
        '未擁立${stats.redAlertCount}件 / '
        '単騎${stats.yellowAlertCount}件 ($date)';
    return <String>[...manualLines, autoLine].join('\n');
  }

  String _prefectureKey(String value) {
    final trimmed = value.trim();
    if (trimmed == '北海道') {
      return trimmed;
    }
    return trimmed.replaceFirst(RegExp(r'[都府県]$'), '');
  }
}

class _AutoScheduleStats {
  final int scheduledElectionCount;
  final int redAlertCount;
  final int yellowAlertCount;
  final int kokuminCandidateCount;
  final int confirmedCandidateCount;
  final String? earliestEndorsementMonth;

  const _AutoScheduleStats({
    required this.scheduledElectionCount,
    required this.redAlertCount,
    required this.yellowAlertCount,
    required this.kokuminCandidateCount,
    required this.confirmedCandidateCount,
    required this.earliestEndorsementMonth,
  });

  static const empty = _AutoScheduleStats(
    scheduledElectionCount: 0,
    redAlertCount: 0,
    yellowAlertCount: 0,
    kokuminCandidateCount: 0,
    confirmedCandidateCount: 0,
    earliestEndorsementMonth: null,
  );
}

class _AutoScheduleStatsBuilder {
  int scheduledElectionCount = 0;
  int redAlertCount = 0;
  int yellowAlertCount = 0;
  int kokuminCandidateCount = 0;
  int confirmedCandidateCount = 0;
  String? earliestEndorsementMonth;

  void add(LocalElectionScheduleEntry item) {
    scheduledElectionCount++;
    kokuminCandidateCount += item.kokuminCandidateCount;
    if (item.isAlertRed) {
      redAlertCount++;
    } else if (item.isAlertYellow) {
      yellowAlertCount++;
    }
    if (item.kokuminCandidateStatuses.any((status) => status.contains('公認'))) {
      confirmedCandidateCount += item.kokuminCandidateCount;
    }

    final month = _endorsementMonthForSchedule(item);
    if (month != null &&
        (earliestEndorsementMonth == null ||
            month.compareTo(earliestEndorsementMonth!) < 0)) {
      earliestEndorsementMonth = month;
    }
  }

  _AutoScheduleStats build() {
    return _AutoScheduleStats(
      scheduledElectionCount: scheduledElectionCount,
      redAlertCount: redAlertCount,
      yellowAlertCount: yellowAlertCount,
      kokuminCandidateCount: kokuminCandidateCount,
      confirmedCandidateCount: confirmedCandidateCount,
      earliestEndorsementMonth: earliestEndorsementMonth,
    );
  }

  String? _endorsementMonthForSchedule(LocalElectionScheduleEntry item) {
    final announcement = _parseDate(item.announcementDate);
    final vote = _parseDate(item.voteDate);
    final base = announcement ??
        (vote == null ? null : DateTime(vote.year, vote.month - 1));
    if (base == null) {
      return null;
    }
    final monthKey =
        '${base.year.toString().padLeft(4, '0')}-${base.month.toString().padLeft(2, '0')}';
    if (planningMonthKeys.contains(monthKey)) {
      return monthKey;
    }
    if (monthKey.compareTo(planningMonthKeys.first) < 0) {
      return planningMonthKeys.first;
    }
    if (monthKey.compareTo(planningMonthKeys.last) > 0) {
      return planningMonthKeys.last;
    }
    return monthKey;
  }

  DateTime? _parseDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value) ??
        DateTime.tryParse(value.replaceAll('/', '-'));
  }
}

class _PrefectureSeed {
  final String prefecture;
  final String region;
  final int tier;

  const _PrefectureSeed(this.prefecture, this.region, this.tier);
}

const List<_PrefectureSeed> _prefectureSeeds = <_PrefectureSeed>[
  _PrefectureSeed('北海道', '北海道', 1),
  _PrefectureSeed('青森', '東北', 3),
  _PrefectureSeed('岩手', '東北', 3),
  _PrefectureSeed('宮城', '東北', 2),
  _PrefectureSeed('秋田', '東北', 3),
  _PrefectureSeed('山形', '東北', 3),
  _PrefectureSeed('福島', '東北', 2),
  _PrefectureSeed('茨城', '関東', 2),
  _PrefectureSeed('栃木', '関東', 2),
  _PrefectureSeed('群馬', '関東', 2),
  _PrefectureSeed('埼玉', '関東', 1),
  _PrefectureSeed('千葉', '関東', 1),
  _PrefectureSeed('東京', '関東', 1),
  _PrefectureSeed('神奈川', '関東', 1),
  _PrefectureSeed('新潟', '中部', 2),
  _PrefectureSeed('富山', '中部', 3),
  _PrefectureSeed('石川', '中部', 3),
  _PrefectureSeed('福井', '中部', 3),
  _PrefectureSeed('山梨', '中部', 3),
  _PrefectureSeed('長野', '中部', 2),
  _PrefectureSeed('岐阜', '中部', 2),
  _PrefectureSeed('静岡', '中部', 2),
  _PrefectureSeed('愛知', '中部', 1),
  _PrefectureSeed('三重', '近畿', 2),
  _PrefectureSeed('滋賀', '近畿', 3),
  _PrefectureSeed('京都', '近畿', 2),
  _PrefectureSeed('大阪', '近畿', 1),
  _PrefectureSeed('兵庫', '近畿', 1),
  _PrefectureSeed('奈良', '近畿', 3),
  _PrefectureSeed('和歌山', '近畿', 3),
  _PrefectureSeed('鳥取', '中国', 3),
  _PrefectureSeed('島根', '中国', 3),
  _PrefectureSeed('岡山', '中国', 2),
  _PrefectureSeed('広島', '中国', 2),
  _PrefectureSeed('山口', '中国', 3),
  _PrefectureSeed('徳島', '四国', 3),
  _PrefectureSeed('香川', '四国', 3),
  _PrefectureSeed('愛媛', '四国', 3),
  _PrefectureSeed('高知', '四国', 3),
  _PrefectureSeed('福岡', '九州', 1),
  _PrefectureSeed('佐賀', '九州', 3),
  _PrefectureSeed('長崎', '九州', 3),
  _PrefectureSeed('熊本', '九州', 2),
  _PrefectureSeed('大分', '九州', 3),
  _PrefectureSeed('宮崎', '九州', 3),
  _PrefectureSeed('鹿児島', '九州', 2),
  _PrefectureSeed('沖縄', '九州', 2),
];
