import 'package:flutter_test/flutter_test.dart';

import '../../lib/utils/home_calendar_visible_range.dart';

void main() {
  final cases = <(DateTime, DateTime, DateTime)>[
    (DateTime(2024, 2), DateTime(2024, 1, 28), DateTime(2024, 3, 2)),
    (DateTime(2025, 2), DateTime(2025, 1, 26), DateTime(2025, 3, 1)),
    (DateTime(2026, 2), DateTime(2026, 2, 1), DateTime(2026, 2, 28)),
    (DateTime(2026, 5), DateTime(2026, 4, 26), DateTime(2026, 6, 6)),
    (DateTime(2025, 12), DateTime(2025, 11, 30), DateTime(2026, 1, 3)),
    (DateTime(2026, 1), DateTime(2025, 12, 28), DateTime(2026, 1, 31)),
    (DateTime(2000, 2), DateTime(2000, 1, 30), DateTime(2000, 3, 4)),
    (DateTime(2100, 2), DateTime(2100, 1, 31), DateTime(2100, 3, 6)),
    (DateTime(2026, 8), DateTime(2026, 7, 26), DateTime(2026, 9, 5)),
  ];
  for (final (month, start, end) in cases) {
    test('pads ${month.year}-${month.month} to full weeks', () {
      final range = HomeCalendarVisibleRange.forMonth(month);
      expect(range.monthAnchor, DateTime(month.year, month.month, 1));
      expect(range.startDay, start);
      expect(range.endDay, end);
    });
  }

  test('uses local calendar dates for UTC and timed input', () {
    for (final month in [
      DateTime(2024, 2, 29, 23, 59),
      DateTime.utc(2024, 2, 29, 23, 59),
    ]) {
      final range = HomeCalendarVisibleRange.forMonth(month);
      expect(range.monthAnchor, DateTime(2024, 2, 1));
      expect(range.startDay, DateTime(2024, 1, 28));
      expect(range.endDay, DateTime(2024, 3, 2));
      expect(range.monthAnchor.isUtc, isFalse);
      expect(range.startDay.isUtc, isFalse);
      expect(range.endDay.isUtc, isFalse);
    }
  });

  test('matches the previous range across 168 month inputs', () {
    for (final year in [1999, 2000, 2024, 2025, 2026, 2099, 2100]) {
      for (var month = 1; month <= 12; month++) {
        for (final anchor in [
          DateTime(year, month, 15, 12),
          DateTime.utc(year, month, 28, 23),
        ]) {
          final range = HomeCalendarVisibleRange.forMonth(anchor);
          final legacy = _legacyRange(anchor);
          expect(range.monthAnchor, legacy.$1, reason: '$anchor');
          expect(range.startDay, legacy.$2, reason: '$anchor');
          expect(range.endDay, legacy.$3, reason: '$anchor');
        }
      }
    }
  });
}

// Migration oracle: Home at 573a724a78a51b8d25e2604d6f43ca467f6d451d.
// Keep the original local DateTime and Duration semantics, including DST.
(DateTime, DateTime, DateTime) _legacyRange(DateTime month) {
  final anchor = DateTime(month.year, month.month, 1);
  final first = DateTime(anchor.year, anchor.month, 1);
  final last = DateTime(anchor.year, anchor.month + 1, 0);
  return (
    anchor,
    first.subtract(Duration(days: first.weekday % 7)),
    last.add(Duration(days: 6 - (last.weekday % 7))),
  );
}
