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
      final batchNewWins = current.autoUpdatedAt.trim().isEmpty
          ? 0
          : math.max(0, currentMembers - current.currentMembers);
      final candidateWinRatePercent = _candidateWinRatePercent(
        wins: batchNewWins,
        candidates: stats.kokuminCandidateCount,
      );
      final candidateTarget =
          LocalElectionPrefecturePlan.candidateTargetForElectionTarget(
        additionalTarget,
      );
      final focusCount = _realisticFocusMunicipalityCount(
        currentMembers: currentMembers,
        stats: stats,
      );
      final supportRounds = _realisticSupportRounds(
        currentMembers: currentMembers,
        stats: stats,
      );

      prefectures.add(
        current.copyWith(
          additionalSeatTarget: additionalTarget,
          incumbentRetentionTarget: currentMembers,
          focusMunicipalityCount: focusCount,
          newCandidateTarget: candidateTarget,
          endorsementDeadlineMonth: stats.earliestEndorsementMonth ??
              current.endorsementDeadlineMonth,
          closeRaceSupportRounds: supportRounds,
          currentMembers: currentMembers,
          scheduledElectionCount: scheduledElectionCount,
          announcedCandidateCount: stats.kokuminCandidateCount,
          confirmedCandidateCount: stats.confirmedCandidateCount,
          candidateWinRatePercent: candidateWinRatePercent,
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
            candidateWinRatePercent: candidateWinRatePercent,
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
      final newCandidateTarget =
          LocalElectionPrefecturePlan.candidateTargetForElectionTarget(
        additionalTarget,
      );
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
      final officerSeed = _officerSeedFor(seed.prefecture);

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
          prefectureChairName: officerSeed?.chairName ?? '',
          prefectureSecretaryGeneralName:
              officerSeed?.secretaryGeneralName ?? '',
          prefectureOfficerSourceUrl: officerSeed?.sourceUrl ?? '',
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
      final officerSeed = _officerSeedFor(item.prefecture);
      prefectures.add(
        item.copyWith(
          additionalSeatTarget: clampPositiveInt(item.additionalSeatTarget),
          incumbentRetentionTarget: clampPositiveInt(
            item.incumbentRetentionTarget,
          ),
          focusMunicipalityCount: clampPositiveInt(item.focusMunicipalityCount),
          newCandidateTarget:
              LocalElectionPrefecturePlan.candidateTargetForElectionTarget(
            item.newElectionTarget,
          ),
          closeRaceSupportRounds: clampPositiveInt(item.closeRaceSupportRounds),
          currentMembers: clampPositiveInt(item.currentMembers),
          scheduledElectionCount: clampPositiveInt(item.scheduledElectionCount),
          announcedCandidateCount:
              clampPositiveInt(item.announcedCandidateCount),
          confirmedCandidateCount:
              clampPositiveInt(item.confirmedCandidateCount),
          candidateWinRatePercent: clampPositiveInt(
            item.candidateWinRatePercent,
          ).clamp(0, 100).toInt(),
          cdpLocalMembers: clampPositiveInt(item.cdpLocalMembers),
          cdpSourceUrl: item.cdpSourceUrl.trim(),
          prefectureChairName: item.prefectureChairName.trim().isNotEmpty
              ? item.prefectureChairName.trim()
              : officerSeed?.chairName,
          prefectureSecretaryGeneralName:
              item.prefectureSecretaryGeneralName.trim().isNotEmpty
                  ? item.prefectureSecretaryGeneralName.trim()
                  : officerSeed?.secretaryGeneralName,
          prefectureOfficerSourceUrl:
              item.prefectureOfficerSourceUrl.trim().isNotEmpty
                  ? item.prefectureOfficerSourceUrl.trim()
                  : officerSeed?.sourceUrl,
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
    if (plan.prefectures.isEmpty) {
      return List<int>.filled(plan.prefectures.length, 0);
    }

    final baseTargets = <int>[];
    final adjustmentWeights = <double>[];
    for (final item in plan.prefectures) {
      final key = _prefectureKey(item.prefecture);
      final reality = realitiesByPrefecture[key];
      final stats = scheduleStatsByPrefecture[key] ?? _AutoScheduleStats.empty;
      final currentMembers = reality?.currentMembers ?? item.currentMembers;
      final cdpLocalMembers = reality?.cdpLocalMembers ?? item.cdpLocalMembers;
      baseTargets.add(
        _baseNewElectionTarget(
          currentMembers: currentMembers,
          cdpLocalMembers: cdpLocalMembers,
          stats: stats,
        ),
      );
      adjustmentWeights.add(
        _autoTargetWeight(item, reality, stats),
      );
    }

    final hasCompleteReality = plan.prefectures.every(
      (item) =>
          realitiesByPrefecture.containsKey(_prefectureKey(item.prefecture)),
    );
    final baseTotal = baseTargets.fold<int>(0, (sum, value) => sum + value);
    final targetTotal = hasCompleteReality ? total : baseTotal;
    if (targetTotal <= 0) {
      return List<int>.filled(plan.prefectures.length, 0);
    }

    return _fitTargetsToTotal(
      baseTargets: baseTargets,
      targetTotal: targetTotal,
      adjustmentWeights: adjustmentWeights,
    );
  }

  List<int> _fitTargetsToTotal({
    required List<int> baseTargets,
    required int targetTotal,
    required List<double> adjustmentWeights,
  }) {
    final baseTotal = baseTargets.fold<int>(0, (sum, value) => sum + value);
    if (baseTotal == targetTotal) {
      return baseTargets;
    }
    if (baseTotal <= 0) {
      return _allocateByWeight(adjustmentWeights, targetTotal);
    }
    if (baseTotal < targetTotal) {
      final additions = _allocateByWeight(
        adjustmentWeights,
        targetTotal - baseTotal,
      );
      return <int>[
        for (var index = 0; index < baseTargets.length; index++)
          baseTargets[index] + additions[index],
      ];
    }

    final minimums = <int>[
      for (final target in baseTargets) target > 0 ? 1 : 0,
    ];
    final minimumTotal = minimums.fold<int>(0, (sum, value) => sum + value);
    if (targetTotal <= minimumTotal) {
      return _allocateByWeight(
        baseTargets.map((value) => value.toDouble()).toList(),
        targetTotal,
      );
    }

    final surplusWeights = <double>[
      for (var index = 0; index < baseTargets.length; index++)
        math.max(0, baseTargets[index] - minimums[index]).toDouble(),
    ];
    final surplus = _allocateByWeight(
      surplusWeights,
      targetTotal - minimumTotal,
    );
    return <int>[
      for (var index = 0; index < baseTargets.length; index++)
        minimums[index] + surplus[index],
    ];
  }

  List<int> _allocateByWeight(List<double> weights, int total) {
    if (total <= 0 || weights.isEmpty) {
      return List<int>.filled(weights.length, 0);
    }
    final totalWeight = weights.fold<double>(0, (sum, value) => sum + value);
    if (totalWeight <= 0) {
      final result = List<int>.filled(weights.length, 0);
      for (var index = 0; index < total; index++) {
        result[index % result.length]++;
      }
      return result;
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

  int _baseNewElectionTarget({
    required int currentMembers,
    required int cdpLocalMembers,
    required _AutoScheduleStats stats,
  }) {
    if (currentMembers > 0) {
      return currentMembers;
    }
    final hasFootholdChance = stats.confirmedCandidateCount > 0 ||
        stats.kokuminCandidateCount > 0 ||
        stats.scheduledElectionCount >= 3 ||
        (stats.scheduledElectionCount > 0 && cdpLocalMembers >= 5);
    return hasFootholdChance ? 1 : 0;
  }

  int _candidateWinRatePercent({
    required int wins,
    required int candidates,
  }) {
    if (candidates <= 0) {
      return 0;
    }
    return ((wins / candidates) * 100).round().clamp(0, 100).toInt();
  }

  int _realisticFocusMunicipalityCount({
    required int currentMembers,
    required _AutoScheduleStats stats,
  }) {
    if (currentMembers <= 0) {
      return math.max(1, math.min(2, stats.scheduledElectionCount));
    }
    return math.max(
      2,
      math.min(
        currentMembers,
        math.max(stats.scheduledElectionCount, stats.redAlertCount + 1),
      ),
    );
  }

  int _realisticSupportRounds({
    required int currentMembers,
    required _AutoScheduleStats stats,
  }) {
    final pressure = stats.scheduledElectionCount +
        stats.redAlertCount * 2 +
        stats.yellowAlertCount;
    if (currentMembers <= 0) {
      return math.max(1, math.min(3, pressure));
    }
    return math.max(2, math.min(currentMembers + 2, pressure));
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
    required int candidateWinRatePercent,
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
        '単騎${stats.yellowAlertCount}件 / '
        '現状当選率$candidateWinRatePercent% ($date)';
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

class _PrefectureOfficerSeed {
  final String chairName;
  final String secretaryGeneralName;
  final String sourceUrl;

  const _PrefectureOfficerSeed({
    required this.chairName,
    required this.secretaryGeneralName,
    required this.sourceUrl,
  });
}

_PrefectureOfficerSeed? _officerSeedFor(String prefecture) {
  final key = prefecture.trim().replaceFirst(RegExp(r'[都府県]$'), '');
  return _prefectureOfficerSeeds[key];
}

const Map<String, _PrefectureOfficerSeed> _prefectureOfficerSeeds =
    <String, _PrefectureOfficerSeed>{
  '東京': _PrefectureOfficerSeed(
    chairName: '川合孝典',
    secretaryGeneralName: '石黒たつお',
    sourceUrl: 'https://www.new-kokumin.tokyo/2025/10/yakuin2025/',
  ),
  '岩手': _PrefectureOfficerSeed(
    chairName: '軽石義則',
    secretaryGeneralName: '斎藤明',
    sourceUrl: 'https://kokumin-iwate.jp/member/index.html',
  ),
  '和歌山': _PrefectureOfficerSeed(
    chairName: '浦口高典',
    secretaryGeneralName: '永野裕久',
    sourceUrl: 'https://dp-wakayama.jp/management/',
  ),
  '鹿児島': _PrefectureOfficerSeed(
    chairName: '田村まみ',
    secretaryGeneralName: '成川幸太郎',
    sourceUrl: 'https://new-kokumin-kagoshima.jp/officer_list/',
  ),
};

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
