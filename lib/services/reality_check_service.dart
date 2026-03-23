import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RealityCheckTemplate {
  const RealityCheckTemplate({
    required this.id,
    required this.title,
    required this.prompt,
  });

  final String id;
  final String title;
  final String prompt;
}

class RealityCheckEntry {
  const RealityCheckEntry({
    required this.id,
    required this.category,
    required this.claim,
    required this.observableFacts,
    required this.interpretation,
    required this.nextAction,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String claim;
  final String observableFacts;
  final String interpretation;
  final String nextAction;
  final DateTime createdAt;

  factory RealityCheckEntry.fromJson(Map<String, dynamic> json) {
    return RealityCheckEntry(
      id: json['id']?.toString() ?? '',
      category:
          json['category']?.toString() ?? RealityCheckService.otherCategory,
      claim: json['claim']?.toString() ?? '',
      observableFacts: json['observable_facts']?.toString() ?? '',
      interpretation: json['interpretation']?.toString() ?? '',
      nextAction: json['next_action']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'category': category,
      'claim': claim,
      'observable_facts': observableFacts,
      'interpretation': interpretation,
      'next_action': nextAction,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class RealityCheckStats {
  const RealityCheckStats({
    required this.reviewedTodayCount,
    required this.currentStreak,
    required this.lastReviewedDateKey,
    required this.categoriesCoveredToday,
  });

  factory RealityCheckStats.empty() {
    return const RealityCheckStats(
      reviewedTodayCount: 0,
      currentStreak: 0,
      lastReviewedDateKey: null,
      categoriesCoveredToday: <String>{},
    );
  }

  final int reviewedTodayCount;
  final int currentStreak;
  final String? lastReviewedDateKey;
  final Set<String> categoriesCoveredToday;
}

class RealityCheckAddResult {
  const RealityCheckAddResult({
    required this.entries,
    required this.stats,
    required this.entry,
  });

  final List<RealityCheckEntry> entries;
  final RealityCheckStats stats;
  final RealityCheckEntry entry;
}

class RealityCheckService {
  const RealityCheckService({
    this.nowProvider,
  });

  static const String otherCategory = 'その他';

  static const List<String> builtinCategories = <String>[
    '権力と構造',
    '仕事と金',
    '人間関係',
    '能力と言論',
    otherCategory,
  ];

  static const List<RealityCheckTemplate> builtinTemplates =
      <RealityCheckTemplate>[
    RealityCheckTemplate(
      id: 'power',
      title: '権力と構造',
      prompt: '自分の願望ではなく、構造上の制約は何か。',
    ),
    RealityCheckTemplate(
      id: 'work_money',
      title: '仕事と金',
      prompt: '今の収入構造と生活費から見て、何が現実的か。',
    ),
    RealityCheckTemplate(
      id: 'relationships',
      title: '人間関係',
      prompt: '孤独感や願望ではなく、観測できる関係の事実は何か。',
    ),
    RealityCheckTemplate(
      id: 'competence',
      title: '能力と言論',
      prompt: '勝敗の感情ではなく、実績・弱点・改善余地は何か。',
    ),
  ];

  static const String _entriesKey = 'reality_check_entries_v1';
  static const String _lastReviewedDateKey =
      'reality_check_last_reviewed_date_v1';
  static const String _streakKey = 'reality_check_streak_v1';
  static const String _todayDateKey = 'reality_check_today_date_v1';
  static const String _todayCategoriesKey = 'reality_check_today_categories_v1';
  static const String _todayCountKey = 'reality_check_today_count_v1';

  final DateTime Function()? nowProvider;

  DateTime _now() => nowProvider?.call() ?? DateTime.now();

  Future<List<RealityCheckEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) {
      return const <RealityCheckEntry>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <RealityCheckEntry>[];
      }

      final entries = decoded
          .whereType<Map>()
          .map(
            (entry) =>
                RealityCheckEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where(
            (entry) =>
                entry.id.isNotEmpty &&
                entry.claim.isNotEmpty &&
                entry.observableFacts.isNotEmpty &&
                entry.nextAction.isNotEmpty,
          )
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    } catch (_) {
      return const <RealityCheckEntry>[];
    }
  }

  Future<RealityCheckStats> loadStats({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _dayKey(now ?? _now());
    final storedTodayKey = prefs.getString(_todayDateKey);
    final isToday = storedTodayKey == todayKey;

    return RealityCheckStats(
      reviewedTodayCount: isToday ? (prefs.getInt(_todayCountKey) ?? 0) : 0,
      currentStreak: prefs.getInt(_streakKey) ?? 0,
      lastReviewedDateKey: prefs.getString(_lastReviewedDateKey),
      categoriesCoveredToday: isToday
          ? (prefs.getStringList(_todayCategoriesKey) ?? const <String>[])
              .toSet()
          : <String>{},
    );
  }

  Future<RealityCheckAddResult> addEntry({
    required String category,
    required String claim,
    required String observableFacts,
    required String interpretation,
    required String nextAction,
    DateTime? now,
  }) async {
    final trimmedClaim = claim.trim();
    final trimmedFacts = observableFacts.trim();
    final trimmedNextAction = nextAction.trim();
    if (trimmedClaim.isEmpty) {
      throw ArgumentError('claim must not be empty');
    }
    if (trimmedFacts.isEmpty) {
      throw ArgumentError('observableFacts must not be empty');
    }
    if (trimmedNextAction.isEmpty) {
      throw ArgumentError('nextAction must not be empty');
    }

    final normalizedCategory = builtinCategories.contains(category.trim())
        ? category.trim()
        : otherCategory;
    final createdAt = now ?? _now();
    final prefs = await SharedPreferences.getInstance();
    final currentEntries = await loadEntries();

    final entry = RealityCheckEntry(
      id: 'reality_check_${createdAt.microsecondsSinceEpoch}_${currentEntries.length}',
      category: normalizedCategory,
      claim: trimmedClaim,
      observableFacts: trimmedFacts,
      interpretation: interpretation.trim(),
      nextAction: trimmedNextAction,
      createdAt: createdAt,
    );

    final nextEntries = <RealityCheckEntry>[
      entry,
      ...currentEntries,
    ];
    await prefs.setString(
      _entriesKey,
      jsonEncode(nextEntries.map((item) => item.toJson()).toList()),
    );

    final stats = await _markReviewed(
      prefs,
      category: normalizedCategory,
      now: createdAt,
    );

    return RealityCheckAddResult(
      entries: nextEntries,
      stats: stats,
      entry: entry,
    );
  }

  Future<RealityCheckStats> _markReviewed(
    SharedPreferences prefs, {
    required String category,
    required DateTime now,
  }) async {
    final todayKey = _dayKey(now);
    final storedTodayKey = prefs.getString(_todayDateKey);
    final isToday = storedTodayKey == todayKey;
    final previousCount = isToday ? (prefs.getInt(_todayCountKey) ?? 0) : 0;
    final previousCategories = isToday
        ? (prefs.getStringList(_todayCategoriesKey) ?? const <String>[])
        : <String>[];

    final updatedCategories = <String>{...previousCategories, category}.toList()
      ..sort();
    final updatedCount = previousCount + 1;

    var streak = prefs.getInt(_streakKey) ?? 0;
    final lastReviewedDateKey = prefs.getString(_lastReviewedDateKey);

    if (!isToday) {
      if (_isPreviousDay(lastReviewedDateKey, todayKey)) {
        streak += 1;
      } else {
        streak = 1;
      }
    } else if (streak == 0) {
      streak = 1;
    }

    await prefs.setString(_todayDateKey, todayKey);
    await prefs.setInt(_todayCountKey, updatedCount);
    await prefs.setStringList(_todayCategoriesKey, updatedCategories);
    await prefs.setString(_lastReviewedDateKey, todayKey);
    await prefs.setInt(_streakKey, streak);

    return RealityCheckStats(
      reviewedTodayCount: updatedCount,
      currentStreak: streak,
      lastReviewedDateKey: todayKey,
      categoriesCoveredToday: updatedCategories.toSet(),
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
