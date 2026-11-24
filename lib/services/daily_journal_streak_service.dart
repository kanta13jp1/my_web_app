import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_journal_entry.dart';

typedef DailyJournalRemoteWriter = Future<bool> Function(
  DailyJournalEntry entry,
  UserStreakProfile profile,
);

class DailyJournalStreakService {
  static const String entriesPrefsKey = 'daily_journal_entries_v1';
  static const String profilePrefsKey = 'user_streak_profile_v1';
  static const int maxRetainedEntries = 180;

  final String entriesKey;
  final String profileKey;
  final DailyJournalRemoteWriter? _remoteWriter;

  const DailyJournalStreakService({
    this.entriesKey = entriesPrefsKey,
    this.profileKey = profilePrefsKey,
    DailyJournalRemoteWriter? remoteWriter,
  }) : _remoteWriter = remoteWriter;

  static String formatDateKey(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  static DateTime? parseDateKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime.utc(year, month, day);
  }

  Future<List<DailyJournalEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(entriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <DailyJournalEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <DailyJournalEntry>[];
      }
      final list = decoded
          .whereType<Map>()
          .map(
            (e) => DailyJournalEntry.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
      list.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return list;
    } catch (_) {
      return const <DailyJournalEntry>[];
    }
  }

  Future<UserStreakProfile> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(profileKey);
    if (raw == null || raw.trim().isEmpty) {
      return UserStreakProfile.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return UserStreakProfile.empty();
      }
      return UserStreakProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return UserStreakProfile.empty();
    }
  }

  Future<({DailyJournalEntry entry, UserStreakProfile profile, bool synced})>
      recordTaskCompletion({
    required String taskTitle,
    String summary = '',
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now().toUtc();
    final todayKey = formatDateKey(timestamp);
    final todayDayUtc = DateTime.utc(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    final priorProfile = await loadProfile();
    final priorLastKey = priorProfile.lastActiveDateKey;
    var nextStreak = 1;
    if (priorLastKey != null) {
      final priorDayUtc = parseDateKey(priorLastKey);
      if (priorDayUtc != null) {
        final diffDays = todayDayUtc.difference(priorDayUtc).inDays;
        if (diffDays == 0) {
          nextStreak = math.max(1, priorProfile.currentStreak);
        } else if (diffDays == 1) {
          nextStreak = priorProfile.currentStreak + 1;
        } else if (diffDays < 0) {
          nextStreak = math.max(1, priorProfile.currentStreak);
        } else {
          nextStreak = 1;
        }
      }
    }

    final nextLongest = math.max(priorProfile.longestStreak, nextStreak);
    final nextProfile = UserStreakProfile(
      currentStreak: nextStreak,
      longestStreak: nextLongest,
      totalCompletedTasks: priorProfile.totalCompletedTasks + 1,
      lastActiveDateKey: todayKey,
      updatedAt: timestamp,
    );

    final cleanTitle = taskTitle.trim().isEmpty ? '学習タスク完了' : taskTitle.trim();
    final cleanSummary = summary.trim().isEmpty
        ? '$cleanTitle を完了し、日次ジャーナルへ自動記録しました（連続 ${nextProfile.currentStreak}日目）'
        : summary.trim();

    final candidateEntry = DailyJournalEntry(
      id: 'journal_${timestamp.microsecondsSinceEpoch}',
      dateKey: todayKey,
      taskTitle: cleanTitle,
      summary: cleanSummary,
      completedAt: timestamp,
    );

    var synced = false;
    final writer = _remoteWriter;
    if (writer != null) {
      try {
        synced = await writer(candidateEntry, nextProfile);
      } catch (_) {
        synced = false;
      }
    }

    final savedEntry = DailyJournalEntry(
      id: candidateEntry.id,
      dateKey: candidateEntry.dateKey,
      taskTitle: candidateEntry.taskTitle,
      summary: candidateEntry.summary,
      completedAt: candidateEntry.completedAt,
      syncedToCloud: synced,
    );

    final priorEntries = await loadEntries();
    final nextEntries = <DailyJournalEntry>[savedEntry, ...priorEntries]
        .take(maxRetainedEntries)
        .toList(growable: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      entriesKey,
      jsonEncode(nextEntries.map((e) => e.toJson()).toList(growable: false)),
    );
    await prefs.setString(
      profileKey,
      jsonEncode(nextProfile.toProfileJson()),
    );

    return (entry: savedEntry, profile: nextProfile, synced: synced);
  }
}
