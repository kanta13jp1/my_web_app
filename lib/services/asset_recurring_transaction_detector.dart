import '../models/asset_liability_workbook.dart';

/// 検出の信頼度。
enum RecurringTransactionConfidence { high, medium }

/// 定期取引検出に渡す 1 件の支出観測(description パース + 正規化済み)。
///
/// [label] は `AssetRecurringTransactionDetector.buildLabel` 等で正規化した
/// グルーピング用のキー。[amount] は円(正の整数)。[occurredAt] はローカル日時。
/// [sourceName] は引落元口座の表示名(`[...]` を外したもの / 任意 / 振替元 prefill 用)。
class RecurringTransactionObservation {
  const RecurringTransactionObservation({
    required this.label,
    required this.amount,
    required this.occurredAt,
    this.sourceName = '',
  });

  final String label;
  final int amount;
  final DateTime occurredAt;
  final String sourceName;
}

/// 検出された定期取引(= 固定費登録の候補)。
class DetectedRecurringTransaction {
  const DetectedRecurringTransaction({
    required this.label,
    required this.typicalAmount,
    required this.typicalPaymentDay,
    required this.occurrenceCount,
    required this.monthsObserved,
    required this.confidence,
    required this.cadence,
    required this.lastSeen,
    this.suggestedSourceName,
  });

  /// 表示名兼グルーピングキー(例: 電気代)。
  final String label;

  /// 金額の中央値(円)。
  final int typicalAmount;

  /// 発生日の中央値(1..31)。
  final int typicalPaymentDay;

  /// 検出窓内の総観測数。
  final int occurrenceCount;

  /// 観測された distinct 月数。
  final int monthsObserved;

  final RecurringTransactionConfidence confidence;

  /// 推定される発生周期(毎月 / 隔月偶数月 / 隔月奇数月)。
  final AssetRecurringFixedCostCadence cadence;

  /// 直近の観測日時。
  final DateTime lastSeen;

  /// 最頻の引落元口座名(振替元 prefill 用 / 不明なら null)。
  final String? suggestedSourceName;
}

/// フロー履歴から「毎月/隔月◯日頃に約◯円」の繰り返し支出を検出する純関数サービス。
///
/// description のパース(口座名/使途/浪費マーカー除去)はページ側で行い、
/// 正規化済みの [RecurringTransactionObservation] 列を渡す想定。スキーマ非依存・
/// 完全テスト可。収入側の定期検出はスコープ外(将来候補)。
class AssetRecurringTransactionDetector {
  const AssetRecurringTransactionDetector();

  /// [observations] から定期支出を検出する。
  ///
  /// - 直近 [lookbackMonths] カレンダー月([asOf] 月を含む)に限定。
  /// - [label] でグループ化し、毎月(distinct 月数 >= [minMonthlyOccurrences])または
  ///   隔月(同パリティ月のみ・月間隔がすべて 2・distinct 月数 >= [minBimonthlyOccurrences])
  ///   のいずれかを満たす候補を採用。
  /// - 全観測が中央値の ±[amountTolerance] に収まる(= 金額安定)候補のみ採用。
  /// - 中央値が [minTypicalAmount] 未満の小額ノイズは除外。
  /// - 金額(中央値)降順でソートして返す。
  static List<DetectedRecurringTransaction> detect({
    required List<RecurringTransactionObservation> observations,
    required DateTime asOf,
    int lookbackMonths = 6,
    int minMonthlyOccurrences = 4,
    int minBimonthlyOccurrences = 3,
    int minTypicalAmount = 1000,
    double amountTolerance = 0.25,
  }) {
    final asOfIndex = _monthIndex(asOf);
    final windowStartIndex = asOfIndex - (lookbackMonths - 1);

    final grouped = <String, List<RecurringTransactionObservation>>{};
    for (final obs in observations) {
      final label = obs.label.trim();
      if (label.isEmpty) {
        continue;
      }
      final index = _monthIndex(obs.occurredAt);
      if (index < windowStartIndex || index > asOfIndex) {
        continue;
      }
      grouped.putIfAbsent(label, () => <RecurringTransactionObservation>[]).add(
            obs,
          );
    }

    final detected = <DetectedRecurringTransaction>[];
    grouped.forEach((label, group) {
      final months = group.map((obs) => _monthIndex(obs.occurredAt)).toSet();

      final amounts = <int>[for (final obs in group) obs.amount.abs()];
      final typicalAmount = _median(amounts);
      if (typicalAmount < minTypicalAmount) {
        return;
      }
      if (!_isAmountStable(amounts, typicalAmount, amountTolerance)) {
        return;
      }

      final cadenceResult = _resolveCadence(
        months: months,
        windowStartIndex: windowStartIndex,
        asOfIndex: asOfIndex,
        minMonthlyOccurrences: minMonthlyOccurrences,
        minBimonthlyOccurrences: minBimonthlyOccurrences,
      );
      if (cadenceResult == null) {
        return;
      }

      final days = <int>[for (final obs in group) obs.occurredAt.day];
      final typicalDay = _median(days).clamp(1, 31);

      final lastSeen = group
          .map((obs) => obs.occurredAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      detected.add(
        DetectedRecurringTransaction(
          label: label,
          typicalAmount: typicalAmount,
          typicalPaymentDay: typicalDay,
          occurrenceCount: group.length,
          monthsObserved: months.length,
          confidence: cadenceResult.highCoverage
              ? RecurringTransactionConfidence.high
              : RecurringTransactionConfidence.medium,
          cadence: cadenceResult.cadence,
          lastSeen: lastSeen,
          suggestedSourceName: _dominantSourceName(group),
        ),
      );
    });

    detected.sort((a, b) {
      final byAmount = b.typicalAmount.compareTo(a.typicalAmount);
      if (byAmount != 0) {
        return byAmount;
      }
      return a.label.compareTo(b.label);
    });
    return detected;
  }

  /// パース結果(`source` = `[口座名]` / `memo` = 使途)から表示・グルーピング用の
  /// ラベルを作る。日付/数字断片(`6月分`/`2026`/`06/15` 等)を除去し空白を圧縮。
  /// memo が空なら source の `[...]` を外した名称を使う。
  static String buildLabel({required String source, required String memo}) {
    final cleanedMemo = _stripVariableTokens(memo);
    if (cleanedMemo.isNotEmpty) {
      return cleanedMemo;
    }
    return stripAccountBrackets(source);
  }

  /// `[口座名]` から括弧を外して口座名だけにする。
  static String stripAccountBrackets(String source) =>
      source.replaceAll(RegExp(r'[\[\]]'), '').trim();

  static _CadenceResult? _resolveCadence({
    required Set<int> months,
    required int windowStartIndex,
    required int asOfIndex,
    required int minMonthlyOccurrences,
    required int minBimonthlyOccurrences,
  }) {
    if (months.length >= minMonthlyOccurrences) {
      final lookback = asOfIndex - windowStartIndex + 1;
      return _CadenceResult(
        cadence: AssetRecurringFixedCostCadence.monthly,
        highCoverage: months.length >= lookback,
      );
    }
    if (months.length < minBimonthlyOccurrences) {
      return null;
    }
    final sorted = months.toList()..sort();
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] != 2) {
        return null; // 毎月でも厳密隔月でもない(不規則)。
      }
    }
    final monthOfYear = (sorted.first % 12) + 1;
    final isEven = monthOfYear.isEven;
    final sameParityInWindow = _sameParityMonthCount(
      windowStartIndex: windowStartIndex,
      asOfIndex: asOfIndex,
      even: isEven,
    );
    return _CadenceResult(
      cadence: isEven
          ? AssetRecurringFixedCostCadence.bimonthlyEvenMonth
          : AssetRecurringFixedCostCadence.bimonthlyOddMonth,
      highCoverage: months.length >= sameParityInWindow,
    );
  }

  static int _sameParityMonthCount({
    required int windowStartIndex,
    required int asOfIndex,
    required bool even,
  }) {
    var count = 0;
    for (var idx = windowStartIndex; idx <= asOfIndex; idx++) {
      final monthOfYear = (idx % 12) + 1;
      if (monthOfYear.isEven == even) {
        count += 1;
      }
    }
    return count;
  }

  static String? _dominantSourceName(
    List<RecurringTransactionObservation> group,
  ) {
    final counts = <String, int>{};
    for (final obs in group) {
      final name = obs.sourceName.trim();
      if (name.isEmpty) {
        continue;
      }
      counts[name] = (counts[name] ?? 0) + 1;
    }
    if (counts.isEmpty) {
      return null;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return sorted.first.key;
  }

  static int _monthIndex(DateTime dt) => dt.year * 12 + (dt.month - 1);

  static int _median(List<int> values) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  static bool _isAmountStable(List<int> amounts, int median, double tolerance) {
    if (median <= 0) {
      return false;
    }
    final allowed = median * tolerance;
    for (final amount in amounts) {
      if ((amount - median).abs() > allowed) {
        return false;
      }
    }
    return true;
  }

  /// 全角数字を半角化し、日付/数値断片を除去して空白を圧縮する。
  static String _stripVariableTokens(String input) {
    var text = _normalizeFullWidthDigits(input.trim());
    // 日付 (2026/06/15, 6-15, 6.15 等)。
    text = text.replaceAll(
      RegExp(r'\d{1,4}\s*[/／.\-]\s*\d{1,2}(?:\s*[/／.\-]\s*\d{1,2})?'),
      ' ',
    );
    // 「6月分」「2026年」「15日」「第3回」等の数値 + 単位。
    text = text.replaceAll(
      RegExp(r'\d+\s*(?:年|ヶ月|か月|月分|月|日分|日|回目|回|号)'),
      ' ',
    );
    text = text.replaceAll(RegExp(r'第\s*\d+'), ' ');
    // 残った純粋な数値トークンを除去(単語の一部の数字は残す)。
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty && !RegExp(r'^\d+$').hasMatch(token))
        .toList();
    return tokens.join(' ').trim();
  }

  static String _normalizeFullWidthDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0xFF10 && rune <= 0xFF19) {
        buffer.writeCharCode(rune - 0xFF10 + 0x30);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}

/// `_resolveCadence` の内部結果(周期 + 窓内フルカバレッジか)。
class _CadenceResult {
  const _CadenceResult({required this.cadence, required this.highCoverage});

  final AssetRecurringFixedCostCadence cadence;
  final bool highCoverage;
}
