import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ThoughtAnchorRecord {
  const ThoughtAnchorRecord({
    required this.id,
    required this.anchorText,
    required this.whyNow,
    required this.returnPhrase,
    required this.durationMinutes,
    required this.distractionNotes,
    required this.completedAt,
  });

  final String id;
  final String anchorText;
  final String whyNow;
  final String returnPhrase;
  final int durationMinutes;
  final List<String> distractionNotes;
  final DateTime completedAt;

  int get distractionCount => distractionNotes.length;

  factory ThoughtAnchorRecord.fromJson(Map<String, dynamic> json) {
    return ThoughtAnchorRecord(
      id: json['id']?.toString() ?? '',
      anchorText: json['anchor_text']?.toString() ?? '',
      whyNow: json['why_now']?.toString() ?? '',
      returnPhrase: json['return_phrase']?.toString() ?? '',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      distractionNotes: ((json['distraction_notes'] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      completedAt:
          DateTime.tryParse(json['completed_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'anchor_text': anchorText,
      'why_now': whyNow,
      'return_phrase': returnPhrase,
      'duration_minutes': durationMinutes,
      'distraction_notes': distractionNotes,
      'completed_at': completedAt.toUtc().toIso8601String(),
    };
  }
}

class ThoughtAnchorStats {
  const ThoughtAnchorStats({
    required this.sessionsCompletedToday,
    required this.currentStreak,
    required this.lastCompletedDateKey,
    required this.distractionNotesToday,
  });

  factory ThoughtAnchorStats.empty() {
    return const ThoughtAnchorStats(
      sessionsCompletedToday: 0,
      currentStreak: 0,
      lastCompletedDateKey: null,
      distractionNotesToday: 0,
    );
  }

  final int sessionsCompletedToday;
  final int currentStreak;
  final String? lastCompletedDateKey;
  final int distractionNotesToday;
}

class ThoughtAnchorCompleteResult {
  const ThoughtAnchorCompleteResult({
    required this.record,
    required this.records,
    required this.stats,
  });

  final ThoughtAnchorRecord record;
  final List<ThoughtAnchorRecord> records;
  final ThoughtAnchorStats stats;
}

class ThoughtAnchorService {
  const ThoughtAnchorService({
    this.nowProvider,
  });

  static const List<int> builtinDurations = <int>[3, 5, 10, 15, 25];

  static const String _recordsKey = 'thought_anchor_records_v1';
  static const String _todayDateKey = 'thought_anchor_today_date_v1';
  static const String _todayCountKey = 'thought_anchor_today_count_v1';
  static const String _todayDistractionsKey = 'thought_anchor_today_distractions_v1';
  static const String _lastCompletedDateKey = 'thought_anchor_last_completed_date_v1';
  static const String _streakKey = 'thought_anchor_streak_v1';

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  Future<List<ThoughtAnchorRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recordsKey);
    if (raw == null || raw.isEmpty) {
      return const <ThoughtAnchorRecord>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ThoughtAnchorRecord>[];
      }
      final records = decoded
          .whereType<Map>()
          .map(
            (item) =>
                ThoughtAnchorRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (item) =>
                item.id.isNotEmpty &&
                item.anchorText.isNotEmpty &&
                item.durationMinutes > 0,
          )
          .toList();
      records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return records;
    } catch (_) {
      return const <ThoughtAnchorRecord>[];
    }
  }

  Future<ThoughtAnchorStats> loadStats({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(now ?? _now());
    final storedTodayKey = prefs.getString(_todayDateKey);
    final isToday = storedTodayKey == todayKey;

    return ThoughtAnchorStats(
      sessionsCompletedToday: isToday ? (prefs.getInt(_todayCountKey) ?? 0) : 0,
      currentStreak: prefs.getInt(_streakKey) ?? 0,
      lastCompletedDateKey: prefs.getString(_lastCompletedDateKey),
      distractionNotesToday:
          isToday ? (prefs.getInt(_todayDistractionsKey) ?? 0) : 0,
    );
  }

  Future<ThoughtAnchorCompleteResult> completeSession({
    required String anchorText,
    required String whyNow,
    required String returnPhrase,
    required int durationMinutes,
    List<String> distractionNotes = const <String>[],
    DateTime? completedAt,
  }) async {
    final trimmedAnchorText = anchorText.trim();
    final trimmedReturnPhrase = returnPhrase.trim();
    if (trimmedAnchorText.isEmpty) {
      throw ArgumentError('anchorText must not be empty');
    }
    if (trimmedReturnPhrase.isEmpty) {
      throw ArgumentError('returnPhrase must not be empty');
    }
    if (durationMinutes <= 0) {
      throw ArgumentError('durationMinutes must be positive');
    }

    final now = completedAt ?? _now();
    final prefs = await SharedPreferences.getInstance();
    final currentRecords = await loadRecords();
    final sanitizedDistractions = distractionNotes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final record = ThoughtAnchorRecord(
      id: 'thought_anchor_${now.microsecondsSinceEpoch}_${currentRecords.length}',
      anchorText: trimmedAnchorText,
      whyNow: whyNow.trim(),
      returnPhrase: trimmedReturnPhrase,
      durationMinutes: durationMinutes,
      distractionNotes: sanitizedDistractions,
      completedAt: now,
    );

    final nextRecords = <ThoughtAnchorRecord>[
      record,
      ...currentRecords,
    ];
    await prefs.setString(
      _recordsKey,
      jsonEncode(nextRecords.map((item) => item.toJson()).toList()),
    );

    final stats = await _markCompleted(
      prefs,
      completedAt: now,
      distractionCount: sanitizedDistractions.length,
    );

    return ThoughtAnchorCompleteResult(
      record: record,
      records: nextRecords,
      stats: stats,
    );
  }

  Future<ThoughtAnchorStats> _markCompleted(
    SharedPreferences prefs, {
    required DateTime completedAt,
    required int distractionCount,
  }) async {
    final todayKey = _dayKey(completedAt);
    final storedTodayKey = prefs.getString(_todayDateKey);
    final isToday = storedTodayKey == todayKey;
    final previousCount = isToday ? (prefs.getInt(_todayCountKey) ?? 0) : 0;
    final previousDistractions =
        isToday ? (prefs.getInt(_todayDistractionsKey) ?? 0) : 0;

    var streak = prefs.getInt(_streakKey) ?? 0;
    final lastCompletedDateKey = prefs.getString(_lastCompletedDateKey);

    if (!isToday) {
      if (_isPreviousDay(lastCompletedDateKey, todayKey)) {
        streak += 1;
      } else {
        streak = 1;
      }
    } else if (streak == 0) {
      streak = 1;
    }

    final nextCount = previousCount + 1;
    final nextDistractions = previousDistractions + distractionCount;

    await prefs.setString(_todayDateKey, todayKey);
    await prefs.setInt(_todayCountKey, nextCount);
    await prefs.setInt(_todayDistractionsKey, nextDistractions);
    await prefs.setString(_lastCompletedDateKey, todayKey);
    await prefs.setInt(_streakKey, streak);

    return ThoughtAnchorStats(
      sessionsCompletedToday: nextCount,
      currentStreak: streak,
      lastCompletedDateKey: todayKey,
      distractionNotesToday: nextDistractions,
    );
  }

  String _dayKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  bool _isPreviousDay(String? previousDayKey, String currentDayKey) {
    if (previousDayKey == null) {
      return false;
    }
    final previous = DateTime.tryParse(previousDayKey);
    final current = DateTime.tryParse(currentDayKey);
    if (previous == null || current == null) {
      return false;
    }
    return current.difference(previous).inDays == 1;
  }
}
