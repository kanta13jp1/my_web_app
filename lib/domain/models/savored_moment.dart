/// A moment the user savored without spending money, kept as one sentence.
///
/// The model intentionally has no score, rating or category. Prison mode is
/// built around observing and counting oneself; this record is the one place
/// that asks for nothing but the experience itself.
class SavoredMoment {
  const SavoredMoment({
    required this.id,
    required this.note,
    required this.momentDate,
    required this.createdAt,
  });

  final int id;
  final String note;
  final DateTime momentDate;
  final DateTime createdAt;
}

/// Mirrors the database check on `prison_savored_moments.note`.
const savoredMomentMaxLength = 200;

/// Returns the note to save, or null when it is blank or too long.
///
/// Length is measured after trimming, the same way the database measures it,
/// so the client never sends a row the server will reject.
String? normalizeSavoredMomentNote(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.length > savoredMomentMaxLength) return null;
  return trimmed;
}

/// Today's moments plus a few recent ones to recall.
///
/// There is no count, streak or trend here on purpose: recall shows past
/// sentences as they were written, without turning them into a metric.
class SavoredMomentDigest {
  const SavoredMomentDigest._({required this.today, required this.recent});

  /// How far back the recall reaches, today included.
  static const windowDays = 14;

  /// How many past moments are shown for recall.
  static const recentLimit = 3;

  factory SavoredMomentDigest.fromMoments({
    required Iterable<SavoredMoment> moments,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = windowStart(now);
    final seenIds = <int>{};
    final todays = <SavoredMoment>[];
    final past = <SavoredMoment>[];
    for (final moment in moments) {
      if (!seenIds.add(moment.id)) continue;
      final day = DateTime(
        moment.momentDate.year,
        moment.momentDate.month,
        moment.momentDate.day,
      );
      if (day == today) {
        todays.add(moment);
      } else if (day.isBefore(today) && !day.isBefore(firstDay)) {
        past.add(moment);
      }
    }
    todays.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    past.sort((a, b) {
      final byDay = b.momentDate.compareTo(a.momentDate);
      if (byDay != 0) return byDay;
      return b.id.compareTo(a.id);
    });
    return SavoredMomentDigest._(
      today: List.unmodifiable(todays),
      recent: List.unmodifiable(past.take(recentLimit)),
    );
  }

  static const empty = SavoredMomentDigest._(
    today: <SavoredMoment>[],
    recent: <SavoredMoment>[],
  );

  /// Today's moments, oldest first, so the list reads as the day went.
  final List<SavoredMoment> today;

  /// Up to [recentLimit] moments from before today, newest first.
  final List<SavoredMoment> recent;

  /// The first day (local midnight) included in the recall window.
  static DateTime windowStart(DateTime now) {
    // Calendar arithmetic, not a Duration, so a DST shift cannot move the day.
    return DateTime(now.year, now.month, now.day - (windowDays - 1));
  }
}
