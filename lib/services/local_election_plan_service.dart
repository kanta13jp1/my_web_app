import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/local_election_plan.dart';

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
          endorsementDeadlineMonth:
              planningMonthKeys.contains(item.endorsementDeadlineMonth)
                  ? item.endorsementDeadlineMonth
                  : '2026-10',
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
