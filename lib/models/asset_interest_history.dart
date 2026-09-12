/// Confirmed statement allocations, never inferred from debt balance changes.
class AssetInterestMonth {
  final String month;
  final Map<String, int> amounts;
  final bool complete;
  final String evidence;
  final String? revision;

  AssetInterestMonth(
      {required this.month,
      required Map<String, int> amounts,
      required this.complete,
      required this.evidence,
      this.revision})
      : amounts = Map.unmodifiable(amounts) {
    if (!RegExp(r'^20\d{2}-(0[1-9]|1[0-2])$').hasMatch(month) ||
        amounts.isEmpty ||
        amounts.length > 100 ||
        evidence.trim().isEmpty ||
        evidence.length > 500 ||
        amounts.entries.any((e) =>
            e.key.trim().isEmpty ||
            e.key.length > 100 ||
            e.value < 0 ||
            e.value > 100000000)) {
      throw const FormatException('年月・口座別金額・確認根拠を確認してください');
    }
  }

  int get total => amounts.values.fold(0, (a, b) => a + b);
  Map<String, dynamic> toJson() => {
        'month': month,
        'amounts': amounts,
        'complete': complete,
        'evidence': evidence
      };
  factory AssetInterestMonth.fromJson(Map<String, dynamic> json,
          {String? revision}) =>
      AssetInterestMonth(
          month: json['month'] as String,
          amounts: Map<String, int>.from(json['amounts'] as Map),
          complete: json['complete'] == true,
          evidence: json['evidence'] as String,
          revision: revision);

  /// Positive means reduced cost. Compare only adjacent, closed, complete months
  /// with the same explicitly listed account scope (including zero-interest ones).
  int? reductionFrom(AssetInterestMonth? previous, DateTime now) {
    if (previous == null || !complete || !previous.complete) return null;
    final date = DateTime.parse('$month-01');
    if (!date.isBefore(DateTime(now.year, now.month))) return null;
    if (monthKey(DateTime(date.year, date.month - 1)) != previous.month)
      return null;
    if (amounts.length != previous.amounts.length ||
        !amounts.keys.every(previous.amounts.containsKey)) return null;
    return previous.total - total;
  }

  static String monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  static Map<String, int> parseAmounts(String text) {
    final result = <String, int>{};
    for (final line in text.split('\n').where((s) => s.trim().isNotEmpty)) {
      final parts = line.split('=');
      if (parts.length != 2)
        throw const FormatException('各行を「口座名=利息円」で入力してください');
      final name = parts[0].trim();
      final raw = parts[1].trim();
      if (!RegExp(r'^\d+$').hasMatch(raw) || result.containsKey(name)) {
        throw const FormatException('金額は0以上の整数、口座名は重複なしで入力してください');
      }
      result[name] = int.parse(raw);
    }
    return result;
  }
}
