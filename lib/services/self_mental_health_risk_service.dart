import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/self_mental_health_check.dart';

typedef MentalHealthCloudWriter = Future<bool> Function(
  SelfMentalHealthCheck check,
);

class SelfMentalHealthRiskService {
  static const String defaultPrefsKey = 'self_mental_health_checks_v1';
  static const int maxRetainedDays = 90;

  final String prefsKey;
  final MentalHealthCloudWriter? _cloudWriter;

  const SelfMentalHealthRiskService({
    this.prefsKey = defaultPrefsKey,
    MentalHealthCloudWriter? cloudWriter,
  }) : _cloudWriter = cloudWriter;

  Future<List<SelfMentalHealthCheck>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <SelfMentalHealthCheck>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <SelfMentalHealthCheck>[];
      }
      final entries = decoded
          .whereType<Map>()
          .map(
            (item) => SelfMentalHealthCheck.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
      entries.sort((a, b) => b.dateKey.compareTo(a.dateKey));
      return entries;
    } catch (_) {
      return const <SelfMentalHealthCheck>[];
    }
  }

  Future<SelfMentalHealthCheck> recordDailyCheck({
    required int moodScore,
    required int fatigueScore,
    String note = '',
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final dateKey = SelfMentalHealthCheck.formatDateKey(timestamp);
    final candidate = SelfMentalHealthCheck(
      dateKey: dateKey,
      moodScore: SelfMentalHealthCheck.clampScore(moodScore),
      fatigueScore: SelfMentalHealthCheck.clampScore(fatigueScore),
      note: note.trim(),
      recordedAt: timestamp,
    );

    final synced = await _writeToCloudFailOpen(candidate);
    final saved = SelfMentalHealthCheck(
      dateKey: candidate.dateKey,
      moodScore: candidate.moodScore,
      fatigueScore: candidate.fatigueScore,
      note: candidate.note,
      recordedAt: candidate.recordedAt,
      syncedToCloud: synced,
    );

    final existing = await loadEntries();
    final byDate = <String, SelfMentalHealthCheck>{
      for (final item in existing) item.dateKey: item,
    };
    byDate[saved.dateKey] = saved;
    final next = byDate.values.toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    final trimmed = next.take(maxRetainedDays).toList(growable: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
    return saved;
  }

  Future<bool> _writeToCloudFailOpen(SelfMentalHealthCheck check) async {
    final customWriter = _cloudWriter;
    if (customWriter != null) {
      try {
        return await customWriter(check);
      } catch (_) {
        return false;
      }
    }
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }
      await client.from('mental_health_records').insert(<String, dynamic>{
        'user_id': userId,
        'mood_score': check.moodScore,
        'stress_score': check.fatigueScore,
        'sleep_hours': 7,
        'note': check.note,
        'recorded_at': check.recordedAt.toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static SelfBurnoutRiskReport evaluateRisk(
    List<SelfMentalHealthCheck> entries, {
    DateTime? now,
    int windowDays = 14,
  }) {
    final reference = now ?? DateTime.now();
    final endDay = DateTime(reference.year, reference.month, reference.day);
    final startDay = endDay.subtract(Duration(days: windowDays - 1));
    final startKey = SelfMentalHealthCheck.formatDateKey(startDay);
    final endKey = SelfMentalHealthCheck.formatDateKey(endDay);

    final windowEntries = entries
        .where(
          (entry) =>
              entry.dateKey.compareTo(startKey) >= 0 &&
              entry.dateKey.compareTo(endKey) <= 0,
        )
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    if (windowEntries.length < 3) {
      final count = windowEntries.length;
      final avgMood = count == 0
          ? 0.0
          : windowEntries.map((e) => e.moodScore).reduce((a, b) => a + b) /
              count;
      final avgFatigue = count == 0
          ? 0.0
          : windowEntries.map((e) => e.fatigueScore).reduce((a, b) => a + b) /
              count;
      return SelfBurnoutRiskReport(
        windowDays: windowDays,
        entryCount: count,
        averageMood: avgMood,
        averageFatigue: avgFatigue,
        lowMoodDays: windowEntries.where((e) => e.moodScore <= 2).length,
        highFatigueDays: windowEntries.where((e) => e.fatigueScore >= 4).length,
        consecutiveHighStrainDays: _trailingHighStrainDays(windowEntries),
        level: SelfBurnoutRiskLevel.low,
        headline: 'コンディションを記録して傾向を確認しましょう（現在 $count/3 日）',
        suggestions: const <String>[
          '1日1回、気分と身体の疲労度をワンタップで記録すると直近2週間の変化を可視化できます。',
        ],
      );
    }

    final count = windowEntries.length;
    final avgMood =
        windowEntries.map((e) => e.moodScore).reduce((a, b) => a + b) / count;
    final avgFatigue =
        windowEntries.map((e) => e.fatigueScore).reduce((a, b) => a + b) /
            count;
    final lowMoodDays = windowEntries.where((e) => e.moodScore <= 2).length;
    final highFatigueDays =
        windowEntries.where((e) => e.fatigueScore >= 4).length;
    final trailingStreak = _trailingHighStrainDays(windowEntries);

    final SelfBurnoutRiskLevel level;
    if (avgFatigue >= 4.0 || avgMood <= 2.0 || trailingStreak >= 3) {
      level = SelfBurnoutRiskLevel.high;
    } else if (avgFatigue >= 3.4 ||
        avgMood <= 2.6 ||
        highFatigueDays >= 4 ||
        lowMoodDays >= 4) {
      level = SelfBurnoutRiskLevel.caution;
    } else {
      level = SelfBurnoutRiskLevel.low;
    }

    return switch (level) {
      SelfBurnoutRiskLevel.high => SelfBurnoutRiskReport(
          windowDays: windowDays,
          entryCount: count,
          averageMood: avgMood,
          averageFatigue: avgFatigue,
          lowMoodDays: lowMoodDays,
          highFatigueDays: highFatigueDays,
          consecutiveHighStrainDays: trailingStreak,
          level: level,
          headline: '過労・バーンアウト警戒: 負荷が高い日が続いています',
          suggestions: const <String>[
            '緊急でないタスクを翌週へ先送りし、本日は15〜30分の小休止を確保しましょう。',
            '就寝前の画面時間を控えめにして、十分な睡眠時間を優先しましょう。',
            '信頼できる家族・友人・相談窓口へ現状の負荷を共有する時間も検討してください。',
          ],
        ),
      SelfBurnoutRiskLevel.caution => SelfBurnoutRiskReport(
          windowDays: windowDays,
          entryCount: count,
          averageMood: avgMood,
          averageFatigue: avgFatigue,
          lowMoodDays: lowMoodDays,
          highFatigueDays: highFatigueDays,
          consecutiveHighStrainDays: trailingStreak,
          level: level,
          headline: 'コンディション注意: 疲労の蓄積が見られます',
          suggestions: const <String>[
            '作業の合間に5分間のストレッチや深呼吸を取り入れ、連続稼働を区切りましょう。',
            '今週の予定を1つだけ軽量化し、リフレッシュ用の空き時間を作りましょう。',
          ],
        ),
      SelfBurnoutRiskLevel.low => SelfBurnoutRiskReport(
          windowDays: windowDays,
          entryCount: count,
          averageMood: avgMood,
          averageFatigue: avgFatigue,
          lowMoodDays: lowMoodDays,
          highFatigueDays: highFatigueDays,
          consecutiveHighStrainDays: trailingStreak,
          level: level,
          headline: '安定稼働中: 心身のコンディションは良好な水準です',
          suggestions: const <String>[
            '現在の睡眠・休憩リズムを維持しつつ、週次でタスク負荷を見直しましょう。',
          ],
        ),
    };
  }

  static int _trailingHighStrainDays(List<SelfMentalHealthCheck> sortedAsc) {
    var streak = 0;
    for (var i = sortedAsc.length - 1; i >= 0; i--) {
      if (sortedAsc[i].isHighStrain) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
