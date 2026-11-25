import 'package:my_web_app/models/asset_liability_workbook.dart';

/// 差分入力・手動明細追加の反映結果をプレビューする値オブジェクト。
class CardStatementAdjustmentPreview {
  final double currentConfiguredTotal;
  final double projectedConfiguredTotal;
  final double currentConfiguredDifference;
  final double projectedConfiguredDifference;
  final double currentStatementTotal;
  final double projectedStatementTotal;
  final double currentStatementDifference;
  final double projectedStatementDifference;
  final bool isBalanced;
  final bool isOvershoot;
  final bool resolvesAlert;
  final String statusMessage;

  const CardStatementAdjustmentPreview({
    required this.currentConfiguredTotal,
    required this.projectedConfiguredTotal,
    required this.currentConfiguredDifference,
    required this.projectedConfiguredDifference,
    required this.currentStatementTotal,
    required this.projectedStatementTotal,
    required this.currentStatementDifference,
    required this.projectedStatementDifference,
    required this.isBalanced,
    required this.isOvershoot,
    required this.resolvesAlert,
    required this.statusMessage,
  });
}

/// カード明細手動照合・手動明細整合チェック・仮内訳の決定論的コア。
class CardStatementReconciliationPlanner {
  const CardStatementReconciliationPlanner._();

  static const double balanceTolerance = 0.5;

  /// 不足分を補う推奨調整額を返す（超過・リボ払いは 0）。
  static double suggestedBalancingAmount(
    AssetLiabilityCardStatementReconciliationGroup group,
  ) {
    if (group.isRevolving) {
      return 0;
    }
    if (group.configuredDifference < -balanceTolerance) {
      return group.billedAmount - group.configuredDetailTotal;
    }
    if (group.statementDifference < -balanceTolerance) {
      return group.billedAmount - group.statementLineTotal;
    }
    return 0;
  }

  /// 追加金額を適用した際の請求額との一致状態・超過・アラート解消見込みを計算する。
  static CardStatementAdjustmentPreview previewAdjustment({
    required AssetLiabilityCardStatementReconciliationGroup group,
    required double additionalAmount,
    bool applyToConfigured = true,
    bool applyToStatement = true,
  }) {
    final currentConfiguredTotal = group.configuredDetailTotal;
    final projectedConfiguredTotal = applyToConfigured
        ? currentConfiguredTotal + additionalAmount
        : currentConfiguredTotal;
    final currentConfiguredDifference = group.configuredDifference;
    final projectedConfiguredDifference =
        projectedConfiguredTotal - group.billedAmount;

    final currentStatementTotal = group.statementLineTotal;
    final baselineIncluded = applyToStatement &&
        applyToConfigured &&
        !group.hasStatementLines &&
        currentConfiguredTotal > 0 &&
        (currentConfiguredTotal + additionalAmount - group.billedAmount)
                .abs() <=
            balanceTolerance;
    final projectedStatementTotal = applyToStatement
        ? (baselineIncluded
            ? currentConfiguredTotal + additionalAmount
            : currentStatementTotal + additionalAmount)
        : currentStatementTotal;
    final currentStatementDifference = group.statementDifference;
    final projectedStatementDifference =
        projectedStatementTotal - group.billedAmount;

    final isBalanced = projectedConfiguredDifference.abs() <= balanceTolerance;
    final isOvershoot = projectedConfiguredDifference > balanceTolerance;
    final resolvesAlert = !group.isRevolving &&
        projectedConfiguredDifference.abs() <= balanceTolerance &&
        projectedStatementDifference.abs() <= balanceTolerance;

    final String statusMessage;
    if (group.isRevolving) {
      statusMessage = 'リボ払いカードのため一括照合アラート対象外です。';
    } else if (resolvesAlert) {
      statusMessage = '請求額と一致します。保存するとアラートが解消されます。';
    } else if (isOvershoot) {
      statusMessage = '請求額を超過しています。金額を見直してください。';
    } else if (isBalanced) {
      statusMessage = '設定内訳合計は請求額と一致します（明細側のみ差分が残ります）。';
    } else {
      statusMessage = 'まだ請求額と差額があります。';
    }

    return CardStatementAdjustmentPreview(
      currentConfiguredTotal: currentConfiguredTotal,
      projectedConfiguredTotal: projectedConfiguredTotal,
      currentConfiguredDifference: currentConfiguredDifference,
      projectedConfiguredDifference: projectedConfiguredDifference,
      currentStatementTotal: currentStatementTotal,
      projectedStatementTotal: projectedStatementTotal,
      currentStatementDifference: currentStatementDifference,
      projectedStatementDifference: projectedStatementDifference,
      isBalanced: isBalanced,
      isOvershoot: isOvershoot,
      resolvesAlert: resolvesAlert,
      statusMessage: statusMessage,
    );
  }

  /// 仮内訳が前月以前からの繰越（要確認対象）かどうかを判定する。
  static bool isProvisionalCarryOver(
    AssetLiabilityCardStatementLine line,
    DateTime now,
  ) {
    if (!line.isProvisional || line.createdAt == null) {
      return false;
    }
    final created = line.createdAt!;
    return created.year < now.year ||
        (created.year == now.year && created.month < now.month);
  }

  /// 手動照合・手動明細追加・昇格の新しい明細行を既存行へ安全に反映する。
  /// 既に明細合計が請求額と一致しており設定内訳だけ合わせる場合は
  /// `excludeFromStatementTotal = true` として明細合計の二重計上を防ぐ。
  static List<AssetLiabilityCardStatementLine> buildReconciledStatementLines({
    required List<AssetLiabilityCardStatementLine> existingLines,
    required AssetLiabilityCardStatementReconciliationGroup group,
    required List<AssetLiabilityCardStatementLine> newManualLines,
    required bool adjustConfiguredTotal,
  }) {
    final manualTotal = newManualLines.fold<double>(
      0,
      (sum, line) => sum + line.amount,
    );
    final statementAlreadyBalanced = group.hasStatementLines &&
        group.statementDifference.abs() <= balanceTolerance;

    final merged = <String, AssetLiabilityCardStatementLine>{
      for (final line in existingLines) line.id: line,
    };

    final shouldInsertConfiguredBaseline = !group.hasStatementLines &&
        adjustConfiguredTotal &&
        group.configuredDetailTotal > 0 &&
        (group.configuredDetailTotal + manualTotal - group.billedAmount)
                .abs() <=
            balanceTolerance;
    if (shouldInsertConfiguredBaseline) {
      final baselineId = 'manual_baseline_${group.billingAccountId}';
      merged[baselineId] = AssetLiabilityCardStatementLine(
        id: baselineId,
        billingAccountId: group.billingAccountId,
        billingAccountName: group.billingAccountName,
        postedAt: null,
        description: '設定済み内訳分（手動照合基準）',
        amount: group.configuredDetailTotal,
        isProvisional: false,
        isConfiguredAdjustment: false,
        excludeFromStatementTotal: false,
      );
    }

    for (final line in newManualLines) {
      final normalized = line.copyWith(
        billingAccountId: group.billingAccountId,
        billingAccountName: line.billingAccountName ?? group.billingAccountName,
        isProvisional: false,
        isConfiguredAdjustment: adjustConfiguredTotal,
        excludeFromStatementTotal:
            adjustConfiguredTotal && statementAlreadyBalanced,
      );
      merged[normalized.id] = normalized;
    }

    return merged.values.toList(growable: false);
  }

  /// 仮内訳を正式明細へ昇格させる（仮内訳からは除去し、整合条件に応じて内訳へ反映）。
  static List<AssetLiabilityCardStatementLine> promoteProvisionalLine({
    required List<AssetLiabilityCardStatementLine> existingLines,
    required AssetLiabilityCardStatementReconciliationGroup group,
    required String lineId,
    DateTime? promotedAt,
  }) {
    AssetLiabilityCardStatementLine? target;
    final remaining = <AssetLiabilityCardStatementLine>[];
    for (final line in existingLines) {
      if (line.id == lineId && line.isProvisional) {
        target = line;
      } else {
        remaining.add(line);
      }
    }
    if (target == null) {
      return List<AssetLiabilityCardStatementLine>.from(existingLines);
    }

    final adjustConfigured = group.configuredDifference < -balanceTolerance &&
        (group.configuredDetailTotal + target.amount <=
            group.billedAmount + balanceTolerance);
    final promoted = target.copyWith(
      isProvisional: false,
      postedAt: target.postedAt ?? promotedAt ?? target.createdAt,
    );

    return buildReconciledStatementLines(
      existingLines: remaining,
      group: group,
      newManualLines: <AssetLiabilityCardStatementLine>[promoted],
      adjustConfiguredTotal: adjustConfigured,
    );
  }
}
