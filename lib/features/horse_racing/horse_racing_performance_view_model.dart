import 'dart:math' as math;

class HorseRacingConfidenceInterval {
  const HorseRacingConfidenceInterval(this.lowerPercent, this.upperPercent);

  final double lowerPercent;
  final double upperPercent;

  String get label =>
      '${lowerPercent.toStringAsFixed(1)}–${upperPercent.toStringAsFixed(1)}%';
}

class HorseRacingBetTypeEvidence {
  const HorseRacingBetTypeEvidence({
    required this.betType,
    required this.sampleSize,
    required this.hits,
    required this.hitRatePercent,
    required this.stakeYen,
    required this.payoutYen,
    required this.roiPercent,
    required this.confidenceInterval,
  });

  final String betType;
  final int sampleSize;
  final int hits;
  final double hitRatePercent;
  final int stakeYen;
  final int? payoutYen;
  final double? roiPercent;
  final HorseRacingConfidenceInterval? confidenceInterval;
}

class HorseRacingPerformanceViewModel {
  const HorseRacingPerformanceViewModel({
    required this.totalStakeYen,
    required this.totalPayoutYen,
    required this.netYen,
    required this.roiPercent,
    required this.resultCount,
    required this.hits,
    required this.hitRatePercent,
    required this.predictedProbabilityPercent,
    required this.calibrationGapPoints,
    required this.confidenceInterval,
    required this.periodLabel,
    required this.rankingOnHold,
    required this.betTypes,
  });

  factory HorseRacingPerformanceViewModel.from({
    required Map<String, dynamic> accuracyStats,
    required List<Map<String, dynamic>> betTickets,
  }) {
    final resultCount = _asInt(accuracyStats['total_results']);
    final hits = _asInt(accuracyStats['correct_count']);
    final hitRate =
        _asDouble(accuracyStats['hit_rate_pct']) ??
        (resultCount > 0 ? hits / resultCount * 100 : 0);
    final predictedProbability = _predictedProbability(accuracyStats);
    final ticketSummary = _summarizeTickets(betTickets);
    final roi = ticketSummary.stake > 0
        ? (ticketSummary.payout - ticketSummary.stake) /
              ticketSummary.stake *
              100
        : null;
    final interval = _wilson(hits: hits, total: resultCount);

    final betTypeRows = _mapList(accuracyStats['bet_type_accuracy']);
    final betTypes = <HorseRacingBetTypeEvidence>[];
    for (final row in betTypeRows) {
      final betType = row['bet_type']?.toString() ?? '-';
      final sampleSize = _asInt(row['total_predictions']);
      final typeHits = _asInt(row['hits']);
      final typeRate =
          _asDouble(row['hit_rate_pct']) ??
          (sampleSize > 0 ? typeHits / sampleSize * 100 : 0);
      final typeStake = ticketSummary.stakesByType[betType] ?? 0;
      final payoutIsKnown = !ticketSummary.ambiguousPayoutTypes.contains(
        betType,
      );
      final typePayout = payoutIsKnown
          ? ticketSummary.payoutsByType[betType] ?? 0
          : null;
      final typeRoi = typeStake > 0 && typePayout != null
          ? (typePayout - typeStake) / typeStake * 100
          : null;
      betTypes.add(
        HorseRacingBetTypeEvidence(
          betType: betType,
          sampleSize: sampleSize,
          hits: typeHits,
          hitRatePercent: typeRate,
          stakeYen: typeStake,
          payoutYen: typePayout,
          roiPercent: typeRoi,
          confidenceInterval: _wilson(hits: typeHits, total: sampleSize),
        ),
      );
    }

    return HorseRacingPerformanceViewModel(
      totalStakeYen: ticketSummary.stake,
      totalPayoutYen: ticketSummary.payout,
      netYen: ticketSummary.payout - ticketSummary.stake,
      roiPercent: roi,
      resultCount: resultCount,
      hits: hits,
      hitRatePercent: hitRate,
      predictedProbabilityPercent: predictedProbability,
      calibrationGapPoints: predictedProbability == null
          ? null
          : (predictedProbability - hitRate).abs(),
      confidenceInterval: interval,
      periodLabel: ticketSummary.periodLabel,
      rankingOnHold:
          resultCount < 30 ||
          ticketSummary.stake <= 0 ||
          predictedProbability == null,
      betTypes: betTypes,
    );
  }

  final int totalStakeYen;
  final int totalPayoutYen;
  final int netYen;
  final double? roiPercent;
  final int resultCount;
  final int hits;
  final double hitRatePercent;
  final double? predictedProbabilityPercent;
  final double? calibrationGapPoints;
  final HorseRacingConfidenceInterval? confidenceInterval;
  final String periodLabel;
  final bool rankingOnHold;
  final List<HorseRacingBetTypeEvidence> betTypes;
}

class _TicketSummary {
  const _TicketSummary({
    required this.stake,
    required this.payout,
    required this.periodLabel,
    required this.stakesByType,
    required this.payoutsByType,
    required this.ambiguousPayoutTypes,
  });

  final int stake;
  final int payout;
  final String periodLabel;
  final Map<String, int> stakesByType;
  final Map<String, int> payoutsByType;
  final Set<String> ambiguousPayoutTypes;
}

_TicketSummary _summarizeTickets(List<Map<String, dynamic>> tickets) {
  var stake = 0;
  var payout = 0;
  final dates = <DateTime>[];
  final stakesByType = <String, int>{};
  final payoutsByType = <String, int>{};
  final ambiguousPayoutTypes = <String>{};

  for (final ticket in tickets) {
    final metadata = _asMap(ticket['metadata']);
    final ticketStake = _asInt(metadata['total_amount']);
    final ticketPayout = _asInt(metadata['payout_amount']);
    stake += ticketStake;
    payout += ticketPayout;
    final date = DateTime.tryParse(metadata['race_date']?.toString() ?? '');
    if (date != null) dates.add(date);

    final ticketTypes = <String>{};
    for (final line in _mapList(metadata['lines'])) {
      final betType = line['bet_type']?.toString() ?? '';
      if (betType.isEmpty || betType == '購入しない') continue;
      ticketTypes.add(betType);
      stakesByType.update(
        betType,
        (value) => value + _asInt(line['amount']),
        ifAbsent: () => _asInt(line['amount']),
      );
    }
    if (ticketTypes.length == 1) {
      final betType = ticketTypes.single;
      payoutsByType.update(
        betType,
        (value) => value + ticketPayout,
        ifAbsent: () => ticketPayout,
      );
    } else if (ticketTypes.length > 1) {
      ambiguousPayoutTypes.addAll(ticketTypes);
    }
  }

  dates.sort();
  final periodLabel = dates.isEmpty
      ? '記録なし'
      : dates.first == dates.last
      ? _dateLabel(dates.first)
      : '${_dateLabel(dates.first)}〜${_dateLabel(dates.last)}';
  return _TicketSummary(
    stake: stake,
    payout: payout,
    periodLabel: periodLabel,
    stakesByType: stakesByType,
    payoutsByType: payoutsByType,
    ambiguousPayoutTypes: ambiguousPayoutTypes,
  );
}

double? _predictedProbability(Map<String, dynamic> stats) {
  final learning = _asMap(stats['learning']);
  final calibration = _asMap(learning['calibration']);
  final raw = _firstNumber([
    stats['average_predicted_probability_pct'],
    stats['avg_predicted_probability_pct'],
    stats['average_confidence_pct'],
    stats['avg_confidence_pct'],
    calibration['predicted_probability_pct'],
    calibration['average_predicted_probability_pct'],
  ]);
  if (raw == null) return null;
  return raw <= 1 ? raw * 100 : raw;
}

HorseRacingConfidenceInterval? _wilson({
  required int hits,
  required int total,
}) {
  if (total <= 0) return null;
  const z = 1.96;
  final proportion = math.max(0, math.min(hits, total)) / total;
  final denominator = 1 + z * z / total;
  final center = (proportion + z * z / (2 * total)) / denominator;
  final margin =
      z /
      denominator *
      math.sqrt(
        proportion * (1 - proportion) / total + z * z / (4 * total * total),
      );
  return HorseRacingConfidenceInterval(
    (math.max(0, center - margin) * 100).toDouble(),
    (math.min(1, center + margin) * 100).toDouble(),
  );
}

String _dateLabel(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

Map<String, dynamic> _asMap(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(_asMap)
      .where((row) => row.isNotEmpty)
      .toList();
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

double? _firstNumber(List<dynamic> values) {
  for (final value in values) {
    final parsed = _asDouble(value);
    if (parsed != null) return parsed;
  }
  return null;
}
