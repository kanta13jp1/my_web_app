/// 資産アラートの重要度。数値が大きいほど緊急。
enum AssetAlertSeverity {
  info,
  warning,
  critical,
}

extension AssetAlertSeverityMeta on AssetAlertSeverity {
  /// ソート用の重み (大きいほど上位)。
  int get weight {
    switch (this) {
      case AssetAlertSeverity.critical:
        return 3;
      case AssetAlertSeverity.warning:
        return 2;
      case AssetAlertSeverity.info:
        return 1;
    }
  }

  String get label {
    switch (this) {
      case AssetAlertSeverity.critical:
        return '緊急';
      case AssetAlertSeverity.warning:
        return '注意';
      case AssetAlertSeverity.info:
        return '情報';
    }
  }
}

/// アラートの発生源カテゴリ。
enum AssetAlertCategory {
  /// 支払期日超過 (延滞)。
  overduePayment,

  /// 口座残高ショート見込み。
  accountShortfall,

  /// 支払日前リマインダー (#2453)。
  paymentDue,

  /// 支払原資未設定。
  paymentSourceMissing,

  /// 異常検知 (第2弾D / #2476-#2477)。将来の外部注入用。
  anomaly,
}

extension AssetAlertCategoryMeta on AssetAlertCategory {
  String get storageId {
    switch (this) {
      case AssetAlertCategory.overduePayment:
        return 'overdue_payment';
      case AssetAlertCategory.accountShortfall:
        return 'account_shortfall';
      case AssetAlertCategory.paymentDue:
        return 'payment_due';
      case AssetAlertCategory.paymentSourceMissing:
        return 'payment_source_missing';
      case AssetAlertCategory.anomaly:
        return 'anomaly';
    }
  }
}

/// 統合アラートパネル (Issue #2475) の 1 件。
///
/// 複数の発生源 (延滞・口座ショート・支払リマインダー・原資未設定・異常検知) を
/// 単一のリストへ集約するための正規化モデル。[id] は dismiss 永続化の鍵であり、
/// 「同じ発生事象」には安定、期日など状態が変われば別値になるよう構築する
/// (= 解消後に再発した事象は新しい id で再表示される)。
class AssetAlert {
  final String id;
  final AssetAlertSeverity severity;
  final AssetAlertCategory category;
  final String title;
  final String detail;

  /// 並び替えの第2キー (期日等)。null は末尾寄せ。
  final DateTime? occurredAt;

  /// 関連口座 ID (任意)。
  final String? accountId;

  const AssetAlert({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.detail,
    this.occurredAt,
    this.accountId,
  });
}
