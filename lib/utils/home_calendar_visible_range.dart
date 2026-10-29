/// The Sunday-to-Saturday date range used by the Home calendar.
class HomeCalendarVisibleRange {
  final DateTime monthAnchor;
  final DateTime startDay;
  final DateTime endDay;

  const HomeCalendarVisibleRange({
    required this.monthAnchor,
    required this.startDay,
    required this.endDay,
  });

  /// Preserves Home's local-date and Duration-based week padding.
  factory HomeCalendarVisibleRange.forMonth(DateTime month) {
    final monthAnchor = DateTime(month.year, month.month, 1);
    final firstDayOfMonth = DateTime(monthAnchor.year, monthAnchor.month, 1);
    final lastDayOfMonth = DateTime(monthAnchor.year, monthAnchor.month + 1, 0);
    final startOffset = firstDayOfMonth.weekday % 7;
    final startDay = firstDayOfMonth.subtract(Duration(days: startOffset));
    final endOffset = 6 - (lastDayOfMonth.weekday % 7);
    final endDay = lastDayOfMonth.add(Duration(days: endOffset));
    return HomeCalendarVisibleRange(
      monthAnchor: monthAnchor,
      startDay: startDay,
      endDay: endDay,
    );
  }
}
