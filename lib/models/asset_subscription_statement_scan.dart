import 'dart:typed_data';

import 'asset_liability_workbook.dart';

/// クレジットカード明細から推定した請求周期。
enum AssetSubscriptionBillingCycle { monthly, annual, unknown }

/// 解析対象として選択された明細画像。
///
/// 画像バイト列は解析中だけメモリに置き、永続化しない。
class AssetSubscriptionStatementImage {
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  const AssetSubscriptionStatementImage({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });
}

/// 明細画像から抽出されたサブスク候補。
///
/// AI が返した金額・周期を入力とし、月額換算はこのモデルで決定論的に行う。
class AssetSubscriptionStatementCandidate {
  final String id;
  final String serviceName;
  final double chargedAmountJpy;
  final DateTime? chargedAt;
  final AssetSubscriptionBillingCycle billingCycle;
  final AssetSubscriptionBillingGateway billingGateway;
  final double confidence;
  final String evidence;

  const AssetSubscriptionStatementCandidate({
    required this.id,
    required this.serviceName,
    required this.chargedAmountJpy,
    required this.chargedAt,
    required this.billingCycle,
    required this.billingGateway,
    required this.confidence,
    required this.evidence,
  });

  /// 年払いだけ12分割し、不明は過少計上を避けて1回の請求額を月額候補とする。
  double get monthlyEquivalentJpy => switch (billingCycle) {
        AssetSubscriptionBillingCycle.annual => chargedAmountJpy / 12,
        AssetSubscriptionBillingCycle.monthly ||
        AssetSubscriptionBillingCycle.unknown =>
          chargedAmountJpy,
      };

  double get annualEquivalentJpy => monthlyEquivalentJpy * 12;

  int get paymentDay {
    final day = chargedAt?.day ?? 1;
    return day.clamp(1, 31).toInt();
  }

  AssetRecurringFixedCost toRecurringFixedCost({
    required String id,
    required AssetSubscriptionReviewDecision reviewDecision,
    String? sourceAccountId,
  }) {
    return AssetRecurringFixedCost(
      id: id,
      name: serviceName,
      amount: monthlyEquivalentJpy.roundToDouble(),
      paymentDay: paymentDay,
      cadence: AssetRecurringFixedCostCadence.monthly,
      sourceAccountId: sourceAccountId,
      category: AssetRecurringFixedCostCategory.subscription,
      billingGateway: billingGateway,
      subscriptionReviewDecision: reviewDecision,
    );
  }
}
