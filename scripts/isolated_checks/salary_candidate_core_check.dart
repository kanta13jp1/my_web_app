/// Unwired scratch only: no UI, storage, finance or network operations.
/// Dates without a verified, explicit fixed calendar offset fail closed.
library;

import 'dart:io' show exit, stderr;

enum CandidatePrecision { instant, dayOnly }

class CandidateDecision {
  const CandidateDecision._(this.eligible, this.precision);
  const CandidateDecision.excluded() : this._(false, null);
  const CandidateDecision.instant() : this._(true, CandidatePrecision.instant);
  const CandidateDecision.dayOnly() : this._(true, CandidatePrecision.dayOnly);
  final bool eligible;
  final CandidatePrecision? precision;
}

/// An explicit *fixed* calendar offset. Caller must verify independently that
/// it remains valid for the whole cycle, including historic DST transitions.
/// This type cannot prove the actual zone identity or that verification.
class ExplicitFixedCalendarOffset {
  ExplicitFixedCalendarOffset(this.offset) {
    if (offset.inMicroseconds != offset.inMinutes * Duration.microsecondsPerMinute ||
        offset.inMinutes < -12 * 60 || offset.inMinutes > 14 * 60) {
      throw ArgumentError('invalid fixed calendar offset');
    }
  }
  final Duration offset;
}

class CandidateWindow {
  CandidateWindow({
    required this.startUtc,
    required this.endExclusiveUtc,
    required this.asOfUtc,
    this.calendarOffset,
  }) {
    if (!startUtc.isUtc || !endExclusiveUtc.isUtc || !asOfUtc.isUtc ||
        !startUtc.isBefore(endExclusiveUtc) || asOfUtc.isBefore(startUtc) ||
        !asOfUtc.isBefore(endExclusiveUtc)) {
      throw ArgumentError('invalid UTC candidate window');
    }
  }
  final DateTime startUtc;
  final DateTime endExclusiveUtc;
  final DateTime asOfUtc;
  /// Null means calendar zone is not verified: no day-only candidates.
  final ExplicitFixedCalendarOffset? calendarOffset;
}

final _day = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$');
final _instant = RegExp(
  r'^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.[0-9]{1,6})?(Z|[+-][0-9]{2}:[0-9]{2})$',
);

bool _complete(RegExpMatch? m, String s) => m != null && m.start == 0 && m.end == s.length;
bool _validDate(int year, int month, int day) {
  if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1 || day > 31) return false;
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

/// dayOnly remains explicitly uncertain, even when it is today's date. It is
/// never a confirmed event or permission to call a writer.
CandidateDecision classifyCandidateTime(String? raw, CandidateWindow window) {
  if (raw == null) return const CandidateDecision.excluded();
  final date = _day.firstMatch(raw);
  if (_complete(date, raw)) {
    final year = int.parse(date![1]!);
    final month = int.parse(date[2]!);
    final day = int.parse(date[3]!);
    final zone = window.calendarOffset;
    if (!_validDate(year, month, day) || zone == null) return const CandidateDecision.excluded();
    final localDayStartAsUtc = DateTime.utc(year, month, day).subtract(zone.offset);
    final localDayEndAsUtc = localDayStartAsUtc.add(const Duration(days: 1));
    // The full local day must be inside the cycle. The day must have begun by
    // asOf; this permits an uncertain same-day observation, never a future day.
    if (localDayStartAsUtc.isBefore(window.startUtc) ||
        localDayEndAsUtc.isAfter(window.endExclusiveUtc) ||
        localDayStartAsUtc.isAfter(window.asOfUtc)) {
      return const CandidateDecision.excluded();
    }
    return const CandidateDecision.dayOnly();
  }
  final match = _instant.firstMatch(raw);
  if (!_complete(match, raw)) return const CandidateDecision.excluded();
  final year = int.parse(match![1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final hour = int.parse(match[4]!);
  final minute = int.parse(match[5]!);
  final second = int.parse(match[6]!);
  final offset = match[7]!;
  if (!_validDate(year, month, day) || hour > 23 || minute > 59 ||
      second > 59 || offset == '-00:00') return const CandidateDecision.excluded();
  if (offset != 'Z') {
    final offsetHour = int.parse(offset.substring(1, 3));
    final offsetMinute = int.parse(offset.substring(4, 6));
    if (offsetHour > 14 || offsetMinute > 59 ||
        (offsetHour == 14 && offsetMinute != 0)) return const CandidateDecision.excluded();
  }
  final instant = DateTime.tryParse(raw)?.toUtc();
  if (instant == null || instant.isBefore(window.startUtc) ||
      !instant.isBefore(window.endExclusiveUtc) || instant.isAfter(window.asOfUtc)) {
    return const CandidateDecision.excluded();
  }
  return const CandidateDecision.instant();
}
// BEGIN CORE-ONLY TEST HARNESS: run only with dart run --enable-asserts.
int _checks = 0;
void _check(bool condition, String label) {
  if (!condition) throw StateError('FAIL: $label');
  _checks++;
  print('PASS: $label');
}
CandidateWindow _window({Duration? offset, DateTime? asOf}) => CandidateWindow(
  startUtc: DateTime.utc(2026, 5, 24),
  endExclusiveUtc: DateTime.utc(2026, 6, 26),
  asOfUtc: asOf ?? DateTime.utc(2026, 6, 20, 3),
  calendarOffset: offset == null ? null : ExplicitFixedCalendarOffset(offset),
);
bool _throwsArgument(void Function() f) {
  try { f(); } on ArgumentError { return true; }
  return false;
}
void main(List<String> args) {
  var assertionsEnabled = false;
  assert(() { assertionsEnabled = true; return true; }());
  if (!assertionsEnabled) {
    stderr.writeln('PROBE_ASSERT_DISABLED');
    exit(71);
  }
  if (args.length == 1 && args[0] == '--probe-failure') {
    try {
      _check(false, 'forced-negative-probe');
    } on StateError catch (error) {
      if (error.message != 'FAIL: forced-negative-probe') rethrow;
      stderr.writeln('PROBE_EXPECTED_FAILURE');
      exit(72);
    }
    throw StateError('FAIL: forced check did not fail');
  } else if (args.isNotEmpty) {
    throw StateError('FAIL: unknown probe');
  }
  final noZone = _window();
  final plusNine = _window(offset: const Duration(hours: 9));
  final minusTen = _window(offset: const Duration(hours: -10));
  _check(!classifyCandidateTime('2026-06-20', noZone).eligible, 'unknown zone rejects today');
  _check(!classifyCandidateTime('2026-06-19', noZone).eligible, 'unknown zone rejects prior day');
  _check(classifyCandidateTime('2026-06-20T03:00:00Z', noZone).precision == CandidatePrecision.instant, 'instant works without calendar zone');
  _check(classifyCandidateTime('2026-06-20', plusNine).precision == CandidatePrecision.dayOnly, 'today remains day-only');
  _check(!classifyCandidateTime('2026-06-21', plusNine).eligible, 'future day denied');
  _check(!classifyCandidateTime('2026-06-24', plusNine).eligible, 'wrong independent future asOfDay impossible');
  _check(!classifyCandidateTime('2026-06-20', minusTen).eligible, 'negative offset is still previous local day');
  _check(classifyCandidateTime('2026-06-19', minusTen).precision == CandidatePrecision.dayOnly, 'negative offset prior local day');
  _check(classifyCandidateTime('2026-06-20T12:00:00+09:00', plusNine).precision == CandidatePrecision.instant, 'offset instant equals asOf');
  _check(classifyCandidateTime('2026-06-19T22:00:00-05:00', plusNine).precision == CandidatePrecision.instant, 'different offset equals asOf');
  _check(!classifyCandidateTime('2026-06-20T03:00:00.000001Z', plusNine).eligible, 'one microsecond after asOf denied');
  _check(classifyCandidateTime('2026-05-24T00:00:00Z', plusNine).eligible, 'cycle start inclusive');
  _check(!classifyCandidateTime('2026-05-23T23:59:59Z', plusNine).eligible, 'before cycle denied');
  _check(!classifyCandidateTime('2026-06-26T00:00:00Z', plusNine).eligible, 'exclusive end denied');
  final partial = CandidateWindow(startUtc: DateTime.utc(2026, 6, 19, 12),
    endExclusiveUtc: DateTime.utc(2026, 6, 21, 12), asOfUtc: DateTime.utc(2026, 6, 20, 23),
    calendarOffset: ExplicitFixedCalendarOffset(Duration.zero));
  _check(!classifyCandidateTime('2026-06-19', partial).eligible, 'partial start day denied');
  _check(classifyCandidateTime('2026-06-20', partial).precision == CandidatePrecision.dayOnly, 'complete day accepted with day precision');
  _check(!classifyCandidateTime('2026-06-21', partial).eligible, 'partial end day denied');
  for (final raw in <String?>[null, '', '2026-06-20T02:00:00', '2026-02-30',
      '2026-06-20T00:00:00-00:00', '2026-06-20\n', 'not-a-date',
      '2026-06-20T00:00:00+14:01', '2026-06-20T00:00:00+09:60']) {
    _check(!classifyCandidateTime(raw, plusNine).eligible, 'invalid input: ${raw ?? "null"}');
  }
  _check(_throwsArgument(() => ExplicitFixedCalendarOffset(const Duration(milliseconds: 1))), 'sub-minute offset rejected');
  _check(_throwsArgument(() => ExplicitFixedCalendarOffset(const Duration(hours: 15))), 'out-of-range offset rejected');
  _check(_throwsArgument(() => _window(asOf: DateTime(2026, 6, 20))), 'non-UTC window rejected');
  final leap = CandidateWindow(startUtc: DateTime.utc(2028, 2, 1),
    endExclusiveUtc: DateTime.utc(2028, 3, 1), asOfUtc: DateTime.utc(2028, 2, 29, 12),
    calendarOffset: ExplicitFixedCalendarOffset(const Duration(hours: 9)));
  _check(classifyCandidateTime('2028-02-29', leap).precision == CandidatePrecision.dayOnly, 'leap day accepted');
  _check(classifyCandidateTime('2028-02-29T14:00:00+14:00', leap).eligible, 'positive maximum offset accepted');
  _check(!classifyCandidateTime('2027-02-29', leap).eligible, 'invalid non-leap day rejected');
  _check(classifyCandidateTime('2026-06-20T02:59:59.123456Z', plusNine).eligible, 'six-digit precision accepted');
  _check(!classifyCandidateTime('2026-06-20T02:59:59.1234567Z', plusNine).eligible, 'unsupported precision rejected');
  _check(_throwsArgument(() => CandidateWindow(startUtc: DateTime.utc(2026, 6, 20), endExclusiveUtc: DateTime.utc(2026, 6, 20), asOfUtc: DateTime.utc(2026, 6, 20))), 'empty cycle window rejected');
  _check(_throwsArgument(() => CandidateWindow(startUtc: DateTime.utc(2026, 6, 21), endExclusiveUtc: DateTime.utc(2026, 6, 20), asOfUtc: DateTime.utc(2026, 6, 20))), 'reversed cycle window rejected');
  // This is a documented boundary, not a claim that +09:00 is the correct
  // timezone: an incorrectly supplied offset can admit the wrong local day.
  _check(classifyCandidateTime('2026-06-20', plusNine).eligible &&
    !classifyCandidateTime('2026-06-20', minusTen).eligible, 'caller must verify offset provenance');
  print('ALL CORE CHECKS PASSED: $_checks');
}