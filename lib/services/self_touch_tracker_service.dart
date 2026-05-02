import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SelfTouchEvent {
  const SelfTouchEvent({
    required this.id,
    required this.occurredAt,
    required this.trigger,
    required this.intensity,
    this.note = '',
    this.replacementAction = '',
  });

  factory SelfTouchEvent.fromJson(Map<String, dynamic> json) {
    return SelfTouchEvent(
      id: json['id'] as String? ?? '',
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      trigger: json['trigger'] as String? ?? 'unknown',
      intensity: (json['intensity'] as num?)?.toInt().clamp(1, 5) ?? 3,
      note: json['note'] as String? ?? '',
      replacementAction: json['replacement_action'] as String? ?? '',
    );
  }

  final String id;
  final DateTime occurredAt;
  final String trigger;
  final int intensity;
  final String note;
  final String replacementAction;

  Map<String, dynamic> toJson() => {
        'id': id,
        'occurred_at': occurredAt.toIso8601String(),
        'trigger': trigger,
        'intensity': intensity,
        'note': note,
        'replacement_action': replacementAction,
      };
}

class SelfTouchFrequencyBucket {
  const SelfTouchFrequencyBucket({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;
}

class SelfTouchStats {
  const SelfTouchStats({
    required this.totalCount,
    required this.todayCount,
    required this.last7DaysCount,
    required this.last30MinutesCount,
    required this.dailyCounts,
    required this.weeklyCounts,
  });

  final int totalCount;
  final int todayCount;
  final int last7DaysCount;
  final int last30MinutesCount;
  final Map<DateTime, int> dailyCounts;
  final Map<DateTime, int> weeklyCounts;

  bool get shouldPromptReplacement =>
      last30MinutesCount >= 3 || todayCount >= 8;
}

class SelfTouchSnapshot {
  const SelfTouchSnapshot({
    required this.events,
    required this.stats,
  });

  final List<SelfTouchEvent> events;
  final SelfTouchStats stats;
}

class SelfTouchReplacementPlan {
  const SelfTouchReplacementPlan({
    required this.title,
    required this.steps,
    required this.durationSeconds,
  });

  final String title;
  final List<String> steps;
  final int durationSeconds;
}

class SelfTouchTrackerService {
  const SelfTouchTrackerService();

  static const String storageKey = 'self_touch_tracker_events_v1';
  static const int maxStoredEvents = 300;

  Future<SelfTouchSnapshot> loadSnapshot({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final events = _decodeEvents(resolvedPrefs.getString(storageKey));
    return SelfTouchSnapshot(
      events: events,
      stats: buildStats(events, now: now ?? DateTime.now()),
    );
  }

  Future<SelfTouchSnapshot> recordEvent({
    required String trigger,
    required int intensity,
    String note = '',
    String replacementAction = '',
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final timestamp = now ?? DateTime.now();
    final events = _decodeEvents(resolvedPrefs.getString(storageKey));
    final event = SelfTouchEvent(
      id: 'self-touch-${timestamp.microsecondsSinceEpoch}',
      occurredAt: timestamp,
      trigger: trigger,
      intensity: intensity.clamp(1, 5),
      note: note.trim(),
      replacementAction: replacementAction.trim(),
    );
    final updated = <SelfTouchEvent>[event, ...events]
        .take(maxStoredEvents)
        .toList(growable: false);
    await _saveEvents(resolvedPrefs, updated);
    return SelfTouchSnapshot(
      events: updated,
      stats: buildStats(updated, now: timestamp),
    );
  }

  Future<SelfTouchSnapshot> deleteEvent({
    required String id,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
    final updated = _decodeEvents(resolvedPrefs.getString(storageKey))
        .where((event) => event.id != id)
        .toList(growable: false);
    await _saveEvents(resolvedPrefs, updated);
    return SelfTouchSnapshot(
      events: updated,
      stats: buildStats(updated, now: now ?? DateTime.now()),
    );
  }

  SelfTouchStats buildStats(
    List<SelfTouchEvent> events, {
    required DateTime now,
  }) {
    final today = _dayStart(now);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));
    final dailyCounts = <DateTime, int>{};
    final weeklyCounts = <DateTime, int>{};
    var todayCount = 0;
    var last7DaysCount = 0;
    var last30MinutesCount = 0;

    for (final event in events) {
      final day = _dayStart(event.occurredAt);
      dailyCounts[day] = (dailyCounts[day] ?? 0) + 1;

      final week = _weekStart(event.occurredAt);
      weeklyCounts[week] = (weeklyCounts[week] ?? 0) + 1;

      if (day == today) todayCount += 1;
      if (!day.isBefore(sevenDaysAgo) && !day.isAfter(today)) {
        last7DaysCount += 1;
      }
      if (!event.occurredAt.isBefore(thirtyMinutesAgo) &&
          !event.occurredAt.isAfter(now)) {
        last30MinutesCount += 1;
      }
    }

    return SelfTouchStats(
      totalCount: events.length,
      todayCount: todayCount,
      last7DaysCount: last7DaysCount,
      last30MinutesCount: last30MinutesCount,
      dailyCounts: Map.unmodifiable(dailyCounts),
      weeklyCounts: Map.unmodifiable(weeklyCounts),
    );
  }

  List<SelfTouchFrequencyBucket> dailyBuckets({
    required SelfTouchStats stats,
    required DateTime now,
    int days = 7,
  }) {
    final today = _dayStart(now);
    return List<SelfTouchFrequencyBucket>.generate(days, (index) {
      final day = today.subtract(Duration(days: days - index - 1));
      return SelfTouchFrequencyBucket(
        label: '${day.month}/${day.day}',
        count: stats.dailyCounts[day] ?? 0,
      );
    });
  }

  List<SelfTouchFrequencyBucket> weeklyBuckets({
    required SelfTouchStats stats,
    required DateTime now,
    int weeks = 4,
  }) {
    final thisWeek = _weekStart(now);
    return List<SelfTouchFrequencyBucket>.generate(weeks, (index) {
      final week = thisWeek.subtract(Duration(days: 7 * (weeks - index - 1)));
      return SelfTouchFrequencyBucket(
        label: '${week.month}/${week.day}週',
        count: stats.weeklyCounts[week] ?? 0,
      );
    });
  }

  List<SelfTouchReplacementPlan> replacementPlans({
    required String trigger,
    required int intensity,
  }) {
    final base = <SelfTouchReplacementPlan>[
      const SelfTouchReplacementPlan(
        title: '手をふさぐ代替動作',
        durationSeconds: 60,
        steps: [
          'ペン、ストレスボール、タオルのどれかを片手で持つ',
          '肩を下げて、息を4秒吸って6秒吐く',
          '触りたい衝動が下がるまで机の上に手を置く',
        ],
      ),
      const SelfTouchReplacementPlan(
        title: '状況ラベルをつける',
        durationSeconds: 45,
        steps: [
          'いまの状態を「不安」「退屈」「言葉探し」のどれかで呼ぶ',
          'ラベルだけをメモし、原因探しは後回しにする',
          '次の1手を15分以内の作業に縮める',
        ],
      ),
    ];

    if (trigger == 'word_search' || trigger == 'stuck') {
      return <SelfTouchReplacementPlan>[
        const SelfTouchReplacementPlan(
          title: '言葉探しの外部化',
          durationSeconds: 90,
          steps: [
            '思い出したい言葉の周辺語を3つ書く',
            '文の空欄に「あとで埋める」と置いて先に進む',
            '2分後に戻る時刻を決める',
          ],
        ),
        ...base,
      ];
    }
    if (trigger == 'stress' || intensity >= 4) {
      return <SelfTouchReplacementPlan>[
        const SelfTouchReplacementPlan(
          title: '緊張を下げる短いリセット',
          durationSeconds: 120,
          steps: [
            '首と肩に力が入っていないか確認する',
            '足裏を床につけ、視線を遠くへ移す',
            '飲み物を一口飲んでから作業へ戻る',
          ],
        ),
        ...base,
      ];
    }
    return base;
  }

  List<SelfTouchEvent> _decodeEvents(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const <SelfTouchEvent>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SelfTouchEvent>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => SelfTouchEvent.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where((event) => event.id.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    } catch (_) {
      return const <SelfTouchEvent>[];
    }
  }

  Future<void> _saveEvents(
    SharedPreferences prefs,
    List<SelfTouchEvent> events,
  ) {
    return prefs.setString(
      storageKey,
      jsonEncode(events.map((event) => event.toJson()).toList()),
    );
  }

  DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _weekStart(DateTime value) {
    final day = _dayStart(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }
}
