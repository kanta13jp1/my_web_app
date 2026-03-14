import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

@immutable
class DailyCompletionGoalSnapshot {
  const DailyCompletionGoalSnapshot({
    required this.todayCompletedCount,
    required this.yesterdayCompletedCount,
  });

  final int todayCompletedCount;
  final int yesterdayCompletedCount;

  int get targetCount => yesterdayCompletedCount + 1;
  int get remainingCount => math.max(targetCount - todayCompletedCount, 0);
  int get deltaFromYesterday => todayCompletedCount - yesterdayCompletedCount;
  bool get isAchieved => todayCompletedCount >= targetCount;

  double get progress {
    if (targetCount <= 0) {
      return 0;
    }
    return (todayCompletedCount / targetCount).clamp(0.0, 1.0);
  }
}

class CompletionGoalService {
  const CompletionGoalService._();

  static DailyCompletionGoalSnapshot buildSnapshot({
    required List<Map<String, dynamic>> todos,
    DateTime? now,
  }) {
    final today = _startOfDay(now ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));

    return DailyCompletionGoalSnapshot(
      todayCompletedCount: countCompletedForDate(todos: todos, day: today),
      yesterdayCompletedCount:
          countCompletedForDate(todos: todos, day: yesterday),
    );
  }

  static int countCompletedForDate({
    required List<Map<String, dynamic>> todos,
    required DateTime day,
  }) {
    final targetDay = _startOfDay(day);

    return todos.where((todo) {
      if (todo['is_completed'] != true) {
        return false;
      }

      final completedAt = _parseDateTime(todo['completed_at']);
      if (completedAt != null) {
        return isSameDay(_startOfDay(completedAt), targetDay);
      }

      final taskDate = _parseDate(todo['task_date']);
      if (taskDate != null) {
        return isSameDay(taskDate, targetDay);
      }

      return false;
    }).length;
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime? _parseDateTime(dynamic rawValue) {
    final text = rawValue?.toString();
    if (text == null || text.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(text).toLocal();
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseDate(dynamic rawValue) {
    final text = rawValue?.toString();
    if (text == null || text.isEmpty) {
      return null;
    }

    try {
      final parsed = DateTime.parse(text);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }
}
