import 'dart:convert';

/// A personal, monthly execution plan. Dates are local civil dates, not instants.
class BusinessExecutionPlan {
  BusinessExecutionPlan({
    required this.id,
    required this.issue,
    required this.owner,
    required this.outcome,
    required this.outcomeUnit,
    required this.outcomeTarget,
    required this.action,
    required this.actionUnit,
    required this.dailyTarget,
    required this.startDate,
    required this.dueDate,
    Map<String, BusinessDailyReport> reports = const {},
    this.reflection = '',
    this.archived = false,
  }) : reports = Map.unmodifiable(reports) {
    _text(id, 80);
    _text(issue, 500);
    _text(owner, 80);
    _text(outcome, 120);
    _text(outcomeUnit, 20);
    _text(action, 120);
    _text(actionUnit, 20);
    _number(outcomeTarget, positive: true);
    _number(dailyTarget, positive: true);
    final start = parseDay(startDate);
    final end = parseDay(dueDate);
    if (start.isAfter(end) ||
        start.year != end.year ||
        start.month != end.month ||
        reports.length > 31 ||
        reflection.length > 1000) {
      throw const FormatException('計画は同じ月の開始日〜期限で設定してください。');
    }
    for (final entry in reports.entries) {
      final day = parseDay(entry.key);
      if (day.isBefore(start) || day.isAfter(end)) {
        throw const FormatException('実績の日付が計画期間外です。');
      }
    }
  }

  final String id;
  final String issue;
  final String owner;
  final String outcome;
  final String outcomeUnit;
  final double outcomeTarget;
  final String action;
  final String actionUnit;
  final double dailyTarget;
  final String startDate;
  final String dueDate;
  final Map<String, BusinessDailyReport> reports;
  final String reflection;
  final bool archived;

  BusinessExecutionPlan withReport(String date, BusinessDailyReport report) =>
      _copy(reports: {...reports, date: report});

  BusinessExecutionPlan withReflection(String value) =>
      _copy(reflection: value.trim());

  BusinessExecutionPlan withArchived(bool value) => _copy(archived: value);

  BusinessExecutionPlan _copy({
    Map<String, BusinessDailyReport>? reports,
    String? reflection,
    bool? archived,
  }) =>
      BusinessExecutionPlan(
        id: id,
        issue: issue,
        owner: owner,
        outcome: outcome,
        outcomeUnit: outcomeUnit,
        outcomeTarget: outcomeTarget,
        action: action,
        actionUnit: actionUnit,
        dailyTarget: dailyTarget,
        startDate: startDate,
        dueDate: dueDate,
        reports: reports ?? this.reports,
        reflection: reflection ?? this.reflection,
        archived: archived ?? this.archived,
      );

  List<String> expectedDates(DateTime now) {
    final today = parseDay(dayKey(now));
    final end = parseDay(dueDate);
    final last = today.isBefore(end) ? today : end;
    final dates = <String>[];
    for (var day = parseDay(startDate);
        !day.isAfter(last);
        day = DateTime(day.year, day.month, day.day + 1)) {
      dates.add(dayKey(day));
    }
    return dates;
  }

  List<String> missingDates(DateTime now) =>
      expectedDates(now).where((day) => !reports.containsKey(day)).toList();

  double get totalActions =>
      reports.values.fold(0.0, (sum, report) => sum + report.actual);

  MapEntry<String, BusinessDailyReport>? get latestOutcome {
    final entries = reports.entries
        .where((entry) => entry.value.outcomeActual != null)
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries.isEmpty ? null : entries.first;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'issue': issue,
        'owner': owner,
        'outcome': outcome,
        'outcomeUnit': outcomeUnit,
        'outcomeTarget': outcomeTarget,
        'action': action,
        'actionUnit': actionUnit,
        'dailyTarget': dailyTarget,
        'startDate': startDate,
        'dueDate': dueDate,
        'reports': reports.map((day, report) => MapEntry(day, report.toJson())),
        'reflection': reflection,
        'archived': archived,
      };

  factory BusinessExecutionPlan.fromJson(Map<String, dynamic> json) =>
      BusinessExecutionPlan(
        id: json['id'] as String,
        issue: json['issue'] as String,
        owner: json['owner'] as String,
        outcome: json['outcome'] as String,
        outcomeUnit: json['outcomeUnit'] as String,
        outcomeTarget: (json['outcomeTarget'] as num).toDouble(),
        action: json['action'] as String,
        actionUnit: json['actionUnit'] as String,
        dailyTarget: (json['dailyTarget'] as num).toDouble(),
        startDate: json['startDate'] as String,
        dueDate: json['dueDate'] as String,
        reports: (json['reports'] as Map<String, dynamic>).map(
          (day, report) => MapEntry(
            day,
            BusinessDailyReport.fromJson(report as Map<String, dynamic>),
          ),
        ),
        reflection: json['reflection'] as String,
        archived: json['archived'] as bool? ?? false,
      );
}

class BusinessDailyReport {
  BusinessDailyReport({
    required this.actual,
    this.outcomeActual,
    required this.note,
  }) {
    _number(actual);
    if (outcomeActual != null) _number(outcomeActual!);
    if (note.length > 500) {
      throw const FormatException('振り返りは500文字以内で入力してください。');
    }
  }

  final double actual;
  final double? outcomeActual;
  final String note;

  Map<String, Object?> toJson() => {
        'actual': actual,
        'outcomeActual': outcomeActual,
        'note': note,
      };

  factory BusinessDailyReport.fromJson(Map<String, dynamic> json) =>
      BusinessDailyReport(
        actual: (json['actual'] as num).toDouble(),
        outcomeActual: (json['outcomeActual'] as num?)?.toDouble(),
        note: json['note'] as String,
      );
}

String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime parseDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('日付は YYYY-MM-DD で入力してください。');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || dayKey(parsed) != value) {
    throw const FormatException('存在する日付を入力してください。');
  }
  return parsed;
}

void _text(String value, int max) {
  if (value.trim().isEmpty || value.length > max) {
    throw FormatException('必須項目は1〜$max文字で入力してください。');
  }
}

void _number(double value, {bool positive = false}) {
  if (!value.isFinite ||
      value < 0 ||
      value > 1000000000 ||
      (positive && value == 0)) {
    throw FormatException(
      positive ? '目標は0より大きい10億以下の数値で入力してください。' : '実績は0〜10億で入力してください。',
    );
  }
}

/// Reject malformed/unsupported storage; never silently replace it with empty data.
class BusinessExecutionCodec {
  static const maxPlans = 24;
  static const maxCharacters = 1000000;

  static List<BusinessExecutionPlan> decode(String? raw) {
    if (raw == null) return const [];
    if (raw.length > maxCharacters) {
      throw const FormatException('保存データの上限を超えています。');
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('未対応の保存形式です。');
    }
    final plans = (json['plans'] as List)
        .map(
          (item) => BusinessExecutionPlan.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
    _validate(plans);
    return List.unmodifiable(plans);
  }

  static String encode(List<BusinessExecutionPlan> plans) {
    _validate(plans);
    final raw = jsonEncode({
      'version': 1,
      'plans': plans.map((plan) => plan.toJson()).toList(),
    });
    if (raw.length > maxCharacters) {
      throw const FormatException('保存データの上限を超えています。');
    }
    return raw;
  }

  static void _validate(List<BusinessExecutionPlan> plans) {
    if (plans.where((plan) => !plan.archived).length > maxPlans ||
        plans.length > 1000 ||
        plans.map((plan) => plan.id).toSet().length != plans.length) {
      throw const FormatException('実行中は24件、アーカイブを含めて1000件まで保存できます。');
    }
  }
}
