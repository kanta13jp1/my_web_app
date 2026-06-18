/// 検出の信頼度。
enum RecurringTransactionConfidence { high, medium }

/// 定期取引検出に渡す 1 件の支出観測(description パース + 正規化済み)。
///
/// [label] は `AssetRecurringTransactionDetector.buildLabel` 等で正規化した
/// グルーピング用のキー。[amount] は円(正の整数)。[occurredAt] はローカル日時。
class RecurringTransactionObservation {
  const RecurringTransactionObservation({
    required this.label,
    required this.amount,
    required this.occurredAt,
  });

  final String label;
  final int amount;
  final DateTime occurredAt;
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
    required this.lastSeen,
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

  /// 直近の観測日時。
  final DateTime lastSeen;
}

/// フロー履歴から「毎月◯日頃に約◯円」の繰り返し支出を検出する純関数サービス。
///
/// description のパース(口座名/使途/浪費マーカー除去)はページ側で行い、
/// 正規化済みの [RecurringTransactionObservation] 列を渡す想定。スキーマ非依存・
/// 完全テスト可。隔月(bimonthly)検出や収入側はスコープ外(将来候補)。
class AssetRecurringTransactionDetector {
  const AssetRecurringTransactionDetector();

  /// [observations] から定期支出を検出する。
  ///
  /// - 直近 [lookbackMonths] カレンダー月([asOf] 月を含む)に限定。
  /// - [label] でグループ化し distinct 月数 >= [minMonthlyOccurrences] を候補に。
  /// - 全観測が中央値の ±[amountTolerance] に収まる(= 金額安定)候補のみ採用。
  /// - 中央値が [minTypicalAmount] 未満の小額ノイズは除外。
  /// - 金額(中央値)降順でソートして返す。
  static List<DetectedRecurringTransaction> detect({
    required List<RecurringTransactionObservation> observations,
    required DateTime asOf,
    int lookbackMonths = 4,
    int minMonthlyOccurrences = 3,
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
      if (months.length < minMonthlyOccurrences) {
        return;
      }

      final amounts = <int>[for (final obs in group) obs.amount.abs()];
      final typicalAmount = _median(amounts);
      if (typicalAmount < minTypicalAmount) {
        return;
      }
      if (!_isAmountStable(amounts, typicalAmount, amountTolerance)) {
        return;
      }

      final days = <int>[for (final obs in group) obs.occurredAt.day];
      final typicalDay = _median(days).clamp(1, 31);

      final lastSeen = group
          .map((obs) => obs.occurredAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      final confidence = months.length >= lookbackMonths
          ? RecurringTransactionConfidence.high
          : RecurringTransactionConfidence.medium;

      detected.add(
        DetectedRecurringTransaction(
          label: label,
          typicalAmount: typicalAmount,
          typicalPaymentDay: typicalDay,
          occurrenceCount: group.length,
          monthsObserved: months.length,
          confidence: confidence,
          lastSeen: lastSeen,
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
    final cleanedSource = source.replaceAll(RegExp(r'[\[\]]'), '').trim();
    return cleanedSource;
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
