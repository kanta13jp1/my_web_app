import 'package:intl/intl.dart';

import 'asset_alert.dart';

/// Persisted deterministic anomaly result produced by the asset scan.
class AssetAnomalyDetection {
  const AssetAnomalyDetection({
    required this.id,
    required this.targetMonth,
    required this.category,
    required this.expected,
    required this.actual,
    required this.delta,
    required this.severity,
    required this.detectedAt,
    this.aiExplanation,
  });

  static const String alertIdPrefix = 'anomaly_detection:';

  final String id;
  final DateTime targetMonth;
  final String category;
  final double expected;
  final double actual;
  final double delta;
  final AssetAlertSeverity severity;
  final DateTime detectedAt;
  final String? aiExplanation;

  static final NumberFormat _yen = NumberFormat.decimalPattern();

  String get alertId => '$alertIdPrefix$id';

  double get deltaPercent => expected == 0 ? 0 : delta / expected * 100;

  factory AssetAnomalyDetection.fromMap(Map<String, dynamic> map) {
    return AssetAnomalyDetection(
      id: _requiredText(map, 'id'),
      targetMonth: _requiredDate(map, 'target_month'),
      category: _requiredText(map, 'category'),
      expected: _requiredNumber(map, 'expected'),
      actual: _requiredNumber(map, 'actual'),
      delta: _requiredNumber(map, 'delta'),
      severity: _severityFromStorage(_requiredText(map, 'severity')),
      detectedAt: _requiredDate(map, 'detected_at'),
      aiExplanation: _optionalText(map['ai_explanation']),
    );
  }

  AssetAlert toAlert() {
    final percent = deltaPercent;
    final signedPercent = percent > 0
        ? '+${percent.toStringAsFixed(1)}'
        : percent.toStringAsFixed(1);
    final explanation = aiExplanation;
    final detail = StringBuffer(
      '期待値 ¥${_yen.format(expected.round())} / '
      '実績 ¥${_yen.format(actual.round())} / '
      '差分 $signedPercent%',
    );
    if (explanation != null) {
      detail.write('\n$explanation');
    }
    return AssetAlert(
      id: alertId,
      severity: severity,
      category: AssetAlertCategory.anomaly,
      title: '${_displayCategory(category)}の支出に異常を検出',
      detail: detail.toString(),
      occurredAt: detectedAt,
    );
  }

  static bool isAnomalyAlertId(String value) =>
      value.startsWith(alertIdPrefix) && value.length > alertIdPrefix.length;

  static String detectionIdFromAlertId(String value) {
    if (!isAnomalyAlertId(value)) {
      throw FormatException('Invalid anomaly alert id: $value');
    }
    return value.substring(alertIdPrefix.length);
  }

  static AssetAlertSeverity _severityFromStorage(String value) {
    switch (value) {
      case 'high':
        return AssetAlertSeverity.critical;
      case 'medium':
        return AssetAlertSeverity.warning;
      case 'low':
        return AssetAlertSeverity.info;
      default:
        throw FormatException('Unknown anomaly severity: $value');
    }
  }

  static String _displayCategory(String value) {
    switch (value) {
      case 'food':
        return '食費';
      case 'transportation':
        return '交通費';
      case 'utilities':
        return '水道光熱費';
      case 'entertainment':
        return '娯楽費';
      case 'shopping':
        return '買い物';
      default:
        return value;
    }
  }
}

String _requiredText(Map<String, dynamic> map, String key) {
  final value = map[key]?.toString().trim() ?? '';
  if (value.isEmpty) {
    throw FormatException('$key is required');
  }
  return value;
}

double _requiredNumber(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) {
    return value.toDouble();
  }
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) {
    throw FormatException('$key must be a finite number');
  }
  return parsed;
}

DateTime _requiredDate(Map<String, dynamic> map, String key) {
  final parsed = DateTime.tryParse(map[key]?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('$key must be an ISO-8601 date');
  }
  return parsed;
}

String? _optionalText(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
