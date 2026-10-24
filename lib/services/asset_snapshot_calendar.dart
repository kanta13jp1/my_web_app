import 'package:intl/intl.dart';

/// Only a real adjacent calendar month is a month-over-month baseline.
String? previousSnapshotCalendarMonthKey(String monthKey) {
  final current = DateTime.tryParse('$monthKey-01');
  final formatter = DateFormat('yyyy-MM');
  if (current == null || formatter.format(current) != monthKey) return null;
  return formatter.format(DateTime(current.year, current.month - 1));
}
