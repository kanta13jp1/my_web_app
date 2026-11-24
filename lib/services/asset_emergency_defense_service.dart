import '../models/asset_liability_workbook.dart';

/// 生活防衛モード用の集計サマリ (#3289)。
class AssetEmergencyDefenseSummary {
  final double essentialTotal;
  final double essentialUnpaidTotal;
  final double deferrableTotal;
  final double cashAfterEssentials;
  final double shortageAmount;
  final List<AssetLiabilityCashflowRow> essentialRows;
  final List<AssetLiabilityCashflowRow> deferrableRows;

  const AssetEmergencyDefenseSummary({
    required this.essentialTotal,
    required this.essentialUnpaidTotal,
    required this.deferrableTotal,
    required this.cashAfterEssentials,
    required this.shortageAmount,
    required this.essentialRows,
    required this.deferrableRows,
  });

  bool get hasShortage => shortageAmount > 0;
}

/// 食費・通勤・住居・通信・光熱・医療などの必須生活支出を判定し、
/// 資金繰りの必要最低限合計と必須支出後残高を算出する (#3289)。
class AssetEmergencyDefenseService {
  const AssetEmergencyDefenseService._();

  static const List<String> _essentialKeywords = <String>[
    '家賃',
    '住居',
    '水道',
    '電気',
    'ガス',
    '光熱',
    '通信',
    '携帯',
    'kddi',
    '食費',
    '通勤',
    '定期',
    '医療',
    '病院',
    '薬局',
    '生活費',
    '保育',
    '学費',
  ];

  static final RegExp _auTelecomPattern = RegExp(
    r'(?:^|[^a-z])au(?:回線|携帯|ひかり|でんき|モバイル|[^a-z]|$)',
    caseSensitive: false,
  );

  /// 資金繰り行が生活防衛上の必須項目かどうかを判定する。
  /// 収入行は常に残し、負債系クレジットカード名 (`auPAYカード` 等) は除外する。
  static bool isEssentialCashflowRow(AssetLiabilityCashflowRow row) {
    if (row.isIncome) {
      return true;
    }
    return isEssentialAccountName(row.accountName);
  }

  /// 口座/支出名称が生活必須支出に該当するか判定する。
  static bool isEssentialAccountName(String accountName) {
    final normalized = accountName.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final lower = normalized.toLowerCase();
    for (final keyword in _essentialKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }
    final isCardDebt = lower.contains('aupay') ||
        lower.contains('auペイ') ||
        lower.contains('au pay') ||
        lower.contains('カード') ||
        lower.contains('card');
    if (isCardDebt) {
      return false;
    }
    return _auTelecomPattern.hasMatch(normalized);
  }

  /// ワークブック全体の必須支出・繰延可能支出・必須支出後残高を集計する。
  static AssetEmergencyDefenseSummary summarize(
    AssetLiabilityWorkbook workbook,
  ) {
    return summarizeRows(
      cashLikeTotal: workbook.cashLikeTotal,
      monthlyUnreceivedIncomeTotal: workbook.monthlyUnreceivedIncomeTotal,
      cashflowRows: workbook.cashflowRows,
    );
  }

  /// 行リスト単位で必須支出サマリを算出する。
  static AssetEmergencyDefenseSummary summarizeRows({
    required double cashLikeTotal,
    required double monthlyUnreceivedIncomeTotal,
    required List<AssetLiabilityCashflowRow> cashflowRows,
  }) {
    final essentialRows = <AssetLiabilityCashflowRow>[];
    final deferrableRows = <AssetLiabilityCashflowRow>[];
    var essentialTotal = 0.0;
    var essentialUnpaidTotal = 0.0;
    var deferrableTotal = 0.0;

    for (final row in cashflowRows) {
      final essential = isEssentialCashflowRow(row);
      if (essential) {
        essentialRows.add(row);
        if (row.isPayment && !row.includedInBillingAccount) {
          essentialTotal += row.paymentAmount;
          if (!row.paid && row.isDirectCashflowTarget) {
            essentialUnpaidTotal += row.paymentAmount;
          }
        }
      } else {
        deferrableRows.add(row);
        if (row.isPayment && !row.includedInBillingAccount) {
          deferrableTotal += row.paymentAmount;
        }
      }
    }

    final cashAfterEssentials =
        cashLikeTotal + monthlyUnreceivedIncomeTotal - essentialUnpaidTotal;
    final shortageAmount =
        cashAfterEssentials < 0 ? cashAfterEssentials.abs() : 0.0;

    return AssetEmergencyDefenseSummary(
      essentialTotal: essentialTotal,
      essentialUnpaidTotal: essentialUnpaidTotal,
      deferrableTotal: deferrableTotal,
      cashAfterEssentials: cashAfterEssentials,
      shortageAmount: shortageAmount,
      essentialRows:
          List<AssetLiabilityCashflowRow>.unmodifiable(essentialRows),
      deferrableRows: List<AssetLiabilityCashflowRow>.unmodifiable(
        deferrableRows,
      ),
    );
  }
}
