import 'package:flutter/material.dart';

/// マネーカレンダーのセル内に借入受取・リボ利用・Debt Guard違反を目立たせるバッジ。
class AssetBorrowingCalendarBadge extends StatelessWidget {
  const AssetBorrowingCalendarBadge({
    super.key,
    required this.hasBorrowing,
    required this.hasRevolvingUsage,
    required this.hasDebtGuardViolation,
    this.preserveTextScale = false,
  });

  final bool hasBorrowing;
  final bool hasRevolvingUsage;
  final bool hasDebtGuardViolation;
  final bool preserveTextScale;

  /// カレンダーセルの背景強調色（既存反映・ショート背景がない日に適用）。
  static Color? cellBackgroundFor({
    required bool hasBorrowing,
    required bool hasRevolvingUsage,
    required bool hasDebtGuardViolation,
  }) {
    if (hasRevolvingUsage || hasDebtGuardViolation) {
      return const Color(0xFFFFE4E6);
    }
    if (hasBorrowing) {
      return const Color(0xFFFEF3C7);
    }
    return null;
  }

  /// 表示対象となる短いバッジ文言リスト。
  static List<String> labelsFor({
    required bool hasBorrowing,
    required bool hasRevolvingUsage,
    required bool hasDebtGuardViolation,
  }) {
    return <String>[
      if (hasBorrowing) '借入',
      if (hasRevolvingUsage) 'リボ',
      if (hasDebtGuardViolation) '借金違反',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!hasBorrowing && !hasRevolvingUsage && !hasDebtGuardViolation) {
      return const SizedBox.shrink();
    }

    final pills = <Widget>[
      if (hasBorrowing)
        const _DebtBadgePill(
          label: '借入',
          backgroundColor: Color(0xFFFEF3C7),
          borderColor: Color(0xFFD97706),
          textColor: Color(0xFF92400E),
        ),
      if (hasRevolvingUsage)
        const _DebtBadgePill(
          label: 'リボ',
          backgroundColor: Color(0xFFFFE4E6),
          borderColor: Color(0xFFE11D48),
          textColor: Color(0xFF9F1239),
        ),
      if (hasDebtGuardViolation)
        const _DebtBadgePill(
          label: '借金違反',
          backgroundColor: Color(0xFFFEE2E2),
          borderColor: Color(0xFFB91C1C),
          textColor: Color(0xFF991B1B),
        ),
    ];

    final tooltipParts = <String>[
      if (hasBorrowing) '借入受取（キャッシング・収入集計外）',
      if (hasRevolvingUsage) 'リボ払い利用（現金引落なし）',
      if (hasDebtGuardViolation) '追加借金ルール違反（Debt Guard）',
    ];

    final spacedPills = <Widget>[
      for (var i = 0; i < pills.length; i++) ...[
        if (i > 0) const SizedBox(width: 2),
        pills[i],
      ],
    ];

    return Tooltip(
      message: tooltipParts.join(' / '),
      child: preserveTextScale
          ? Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              runSpacing: 2,
              children: pills,
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: spacedPills,
              ),
            ),
    );
  }
}

class _DebtBadgePill extends StatelessWidget {
  const _DebtBadgePill({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.3,
        ),
      ),
    );
  }
}
