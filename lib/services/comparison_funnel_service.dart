/// Minimal anonymous stages for the comparison-page acquisition funnel (#4727).
enum ComparisonFunnelStage {
  comparisonArrival('comparison_arrival'),
  comparisonCta('comparison_cta'),
  registrationCompleted('registration_completed');

  const ComparisonFunnelStage(this.wireName);

  final String wireName;
}

/// Strictly anonymous funnel event containing no PII or user-entered text.
class ComparisonFunnelEvent {
  const ComparisonFunnelEvent({
    required this.competitorKey,
    required this.stage,
    required this.dateKey,
  });

  final String competitorKey;
  final ComparisonFunnelStage stage;
  final String dateKey;

  Map<String, String> toAnonymousPayload() {
    return <String, String>{
      'competitor_key': competitorKey,
      'stage': stage.wireName,
      'date_key': dateKey,
    };
  }
}

/// Aggregated conversion counts for a single competitor comparison page.
class ComparisonFunnelSummary {
  const ComparisonFunnelSummary({
    required this.competitorKey,
    required this.arrivals,
    required this.ctaClicks,
    required this.registrations,
  });

  final String competitorKey;
  final int arrivals;
  final int ctaClicks;
  final int registrations;

  double get ctaRate => arrivals <= 0 ? 0.0 : ctaClicks / arrivals;

  double get registrationRate => arrivals <= 0 ? 0.0 : registrations / arrivals;
}

typedef ComparisonFunnelSink = Future<void> Function(
  ComparisonFunnelEvent event,
);

/// Pure, opt-out-aware anonymous comparison funnel tracker & aggregator.
class ComparisonFunnelService {
  ComparisonFunnelService({
    ComparisonFunnelSink? sink,
    this.optedOut = false,
  }) : _sink = sink;

  final ComparisonFunnelSink? _sink;
  final bool optedOut;
  final List<ComparisonFunnelEvent> _recorded = <ComparisonFunnelEvent>[];

  static final RegExp _slugAllowList = RegExp(r'[^a-z0-9_-]');

  /// Normalizes [rawKey] into a safe lowercase slug with no PII or free text.
  static String sanitizeCompetitorKey(String rawKey) {
    final normalized =
        rawKey.trim().toLowerCase().replaceAll(_slugAllowList, '');
    if (normalized.isEmpty) {
      return 'unknown';
    }
    return normalized.length > 32 ? normalized.substring(0, 32) : normalized;
  }

  /// Formats [date] as YYYY-MM-DD in UTC so no sub-day timing leaks.
  static String formatUtcDateKey(DateTime date) {
    final utc = date.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Records an anonymous funnel stage unless [optedOut] or sink errors occur.
  Future<bool> recordStage({
    required String competitorKey,
    required ComparisonFunnelStage stage,
    DateTime? now,
  }) async {
    if (optedOut) {
      return false;
    }

    final event = ComparisonFunnelEvent(
      competitorKey: sanitizeCompetitorKey(competitorKey),
      stage: stage,
      dateKey: formatUtcDateKey(now ?? DateTime.now()),
    );

    final sink = _sink;
    if (sink != null) {
      try {
        await sink(event);
      } catch (_) {
        return false;
      }
    }

    _recorded.add(event);
    return true;
  }

  /// Read-only view of events recorded by this instance.
  List<ComparisonFunnelEvent> get recordedEvents =>
      List<ComparisonFunnelEvent>.unmodifiable(_recorded);

  /// Aggregates anonymous [events] per competitor key.
  List<ComparisonFunnelSummary> aggregateFunnel(
    List<ComparisonFunnelEvent> events,
  ) {
    final byCompetitor = <String, _FunnelCounts>{};
    for (final event in events) {
      final key = sanitizeCompetitorKey(event.competitorKey);
      final counts = byCompetitor.putIfAbsent(key, _FunnelCounts.new);
      switch (event.stage) {
        case ComparisonFunnelStage.comparisonArrival:
          counts.arrivals += 1;
        case ComparisonFunnelStage.comparisonCta:
          counts.ctaClicks += 1;
        case ComparisonFunnelStage.registrationCompleted:
          counts.registrations += 1;
      }
    }

    final keys = byCompetitor.keys.toList()..sort();
    return List<ComparisonFunnelSummary>.unmodifiable(
      <ComparisonFunnelSummary>[
        for (final key in keys)
          ComparisonFunnelSummary(
            competitorKey: key,
            arrivals: byCompetitor[key]!.arrivals,
            ctaClicks: byCompetitor[key]!.ctaClicks,
            registrations: byCompetitor[key]!.registrations,
          ),
      ],
    );
  }
}

class _FunnelCounts {
  int arrivals = 0;
  int ctaClicks = 0;
  int registrations = 0;
}
