import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_liability_card_statement_import_service.dart';

/// カード明細再取得の最終ステータス種別 (#3299)。
enum CardStatementImportResultStatus {
  idle,
  success,
  failed;

  String get label => switch (this) {
        CardStatementImportResultStatus.idle => '未実行',
        CardStatementImportResultStatus.success => '取得成功',
        CardStatementImportResultStatus.failed => '取得失敗',
      };
}

/// カード請求ホスト単位の明細再取得状態 (#3299)。
class CardStatementImportStatus {
  final String billingAccountId;
  final String billingAccountName;
  final DateTime lastAttemptAt;
  final CardStatementImportResultStatus lastResult;
  final String provider;
  final String failureReason;
  final int importedCount;

  const CardStatementImportStatus({
    required this.billingAccountId,
    required this.billingAccountName,
    required this.lastAttemptAt,
    required this.lastResult,
    required this.provider,
    this.failureReason = '',
    this.importedCount = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'billing_account_id': billingAccountId,
        'billing_account_name': billingAccountName,
        'last_attempt_at': lastAttemptAt.toIso8601String(),
        'last_result': lastResult.name,
        'provider': provider,
        'failure_reason': failureReason,
        'imported_count': importedCount,
      };
}

/// カード明細再取得の結果 (#3299)。
class CardStatementRefetchResult {
  final CardStatementImportStatus status;
  final List<AssetLiabilityCardStatementLine> importedLines;
  final String message;

  const CardStatementRefetchResult({
    required this.status,
    required this.importedLines,
    required this.message,
  });
}

typedef CardStatementRefetchHandler = Future<CardStatementRefetchResult>
    Function(
  AssetLiabilityCardStatementReconciliationGroup group,
  DateTime now,
);

/// カード明細の即時再取得と失敗理由の診断・手動入力誘導を提供する (#3299)。
class CardStatementRefetchService {
  const CardStatementRefetchService._();

  static Future<CardStatementRefetchResult> refetchForGroup({
    required AssetLiabilityCardStatementReconciliationGroup group,
    required DateTime now,
    String rawImportText = '',
    CardStatementRefetchHandler? customHandler,
  }) async {
    if (customHandler != null) {
      try {
        return await customHandler(group, now);
      } catch (error) {
        final reason = '明細の再取得に失敗しました: $error';
        return CardStatementRefetchResult(
          status: CardStatementImportStatus(
            billingAccountId: group.billingAccountId,
            billingAccountName: group.billingAccountName,
            lastAttemptAt: now,
            lastResult: CardStatementImportResultStatus.failed,
            provider: 'external_provider',
            failureReason: reason,
          ),
          importedLines: const <AssetLiabilityCardStatementLine>[],
          message: reason,
        );
      }
    }

    final trimmed = rawImportText.trim();
    if (trimmed.isNotEmpty) {
      final parsed = const AssetLiabilityCardStatementImportService().parse(
        rawText: trimmed,
        defaultBillingAccountId: group.billingAccountId,
        defaultBillingAccountName: group.billingAccountName,
      );
      if (parsed.hasAcceptedRows) {
        final msg =
            '${group.billingAccountName} の明細を ${parsed.lines.length} 件取り込みました。';
        return CardStatementRefetchResult(
          status: CardStatementImportStatus(
            billingAccountId: group.billingAccountId,
            billingAccountName: group.billingAccountName,
            lastAttemptAt: now,
            lastResult: CardStatementImportResultStatus.success,
            provider: 'csv_paste',
            importedCount: parsed.lines.length,
          ),
          importedLines: parsed.lines,
          message: msg,
        );
      }
      final rejectedHint = parsed.hasRejectedRows
          ? parsed.rejectedRows.first.reason
          : '有効な明細行を読み取れませんでした';
      final reason = 'CSV解析に失敗しました（$rejectedHint）。手動明細入力から内訳を登録してください。';
      return CardStatementRefetchResult(
        status: CardStatementImportStatus(
          billingAccountId: group.billingAccountId,
          billingAccountName: group.billingAccountName,
          lastAttemptAt: now,
          lastResult: CardStatementImportResultStatus.failed,
          provider: 'csv_paste',
          failureReason: reason,
        ),
        importedLines: const <AssetLiabilityCardStatementLine>[],
        message: reason,
      );
    }

    const reason =
        '自動連携プロバイダが未接続のため再取得できませんでした。CSV貼付または「手動で明細を入力」から内訳を登録してください。';
    return CardStatementRefetchResult(
      status: CardStatementImportStatus(
        billingAccountId: group.billingAccountId,
        billingAccountName: group.billingAccountName,
        lastAttemptAt: now,
        lastResult: CardStatementImportResultStatus.failed,
        provider: 'manual_or_csv',
        failureReason: reason,
      ),
      importedLines: const <AssetLiabilityCardStatementLine>[],
      message: reason,
    );
  }
}
