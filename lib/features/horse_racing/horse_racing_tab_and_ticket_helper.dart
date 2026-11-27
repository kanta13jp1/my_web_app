import 'package:flutter/material.dart';

class HorseRacingTabRouteHelper {
  const HorseRacingTabRouteHelper._();

  static String routeForTabIndex(int index) {
    return switch (index) {
      1 => '/horse-racing/history',
      2 => '/horse-racing/analysis',
      3 => '/horse-racing/bets',
      _ => '/horse-racing',
    };
  }

  static int tabIndexFromUri(Uri uri) {
    final tabParam = uri.queryParameters['tab']?.trim().toLowerCase();
    if (tabParam != null && tabParam.isNotEmpty) {
      return switch (tabParam) {
        'history' || '1' => 1,
        'analysis' || 'accuracy' || '2' => 2,
        'bets' || 'tickets' || '3' => 3,
        _ => 0,
      };
    }
    final path = uri.path.toLowerCase();
    if (path.endsWith('/history')) return 1;
    if (path.endsWith('/analysis')) return 2;
    if (path.endsWith('/bets')) return 3;
    return 0;
  }
}

class HorseRacingTicketValidationResult {
  final int totalAmount;
  final int projectedDailyTotal;
  final int remainingBudget;
  final bool isSkipRecord;
  final bool exceedsBudget;
  final bool isValid;
  final String? errorMessage;

  const HorseRacingTicketValidationResult({
    required this.totalAmount,
    required this.projectedDailyTotal,
    required this.remainingBudget,
    required this.isSkipRecord,
    required this.exceedsBudget,
    required this.isValid,
    this.errorMessage,
  });

  static HorseRacingTicketValidationResult evaluate({
    required List<int> lineAmounts,
    required bool isSkipRecord,
    required int recordedToday,
    required int dailyBudgetYen,
  }) {
    final total = lineAmounts.fold<int>(
      0,
      (sum, amount) => sum + (amount > 0 ? amount : 0),
    );
    final projected = isSkipRecord ? recordedToday : recordedToday + total;
    final remaining = dailyBudgetYen - projected;
    final exceeds = !isSkipRecord && projected > dailyBudgetYen;

    String? error;
    if (!isSkipRecord && total <= 0) {
      error = '購入金額は1円以上で入力してください。';
    } else if (exceeds) {
      error = '1日の予算上限（¥$dailyBudgetYen）を超えています。';
    }

    return HorseRacingTicketValidationResult(
      totalAmount: total,
      projectedDailyTotal: projected,
      remainingBudget: remaining,
      isSkipRecord: isSkipRecord,
      exceedsBudget: exceeds,
      isValid: error == null,
      errorMessage: error,
    );
  }
}

class HorseRacingTicketBudgetBanner extends StatelessWidget {
  final int sampleCount;
  final int minimumSampleSize;
  final int recordedToday;
  final int dailyBudgetYen;
  final HorseRacingTicketValidationResult validation;

  const HorseRacingTicketBudgetBanner({
    super.key,
    required this.sampleCount,
    this.minimumSampleSize = 30,
    required this.recordedToday,
    required this.dailyBudgetYen,
    required this.validation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sampleReady = sampleCount >= minimumSampleSize;
    final borderColor = validation.exceedsBudget
        ? colorScheme.error
        : colorScheme.outlineVariant;

    return Container(
      key: const Key('horse_racing_ticket_budget_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(
                  sampleReady
                      ? '検証サンプル: $sampleCount件 (基準到達)'
                      : '検証サンプル: $sampleCount/$minimumSampleSize件',
                ),
              ),
              Chip(
                label: Text(
                  '本日記録: ¥$recordedToday / 上限 ¥$dailyBudgetYen',
                ),
              ),
            ],
          ),
          if (validation.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              validation.errorMessage!,
              style: TextStyle(
                color: colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
