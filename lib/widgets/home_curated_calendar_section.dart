import 'package:flutter/material.dart';

import 'collapsible_home_section.dart';

/// キュレーション済みホーム画面に表示する折りたたみ可能な月次カレンダーセクション。
class HomeCuratedCalendarSection extends StatelessWidget {
  final bool isCompact;
  final Widget calendarChild;
  final VoidCallback onOpenAssetManagement;

  const HomeCuratedCalendarSection({
    super.key,
    required this.isCompact,
    required this.calendarChild,
    required this.onOpenAssetManagement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor =
        isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);

    return CollapsibleHomeSection(
      key: const Key('home_curated_operations_calendar'),
      storageKey: 'home_curated_operations_calendar',
      title: '月次カレンダー（収支・借入/違反）',
      icon: Icons.calendar_month,
      iconColor: accentColor,
      initiallyExpanded: !isCompact,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            calendarChild,
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                key: const Key(
                  'home_curated_calendar_open_asset_management_button',
                ),
                onPressed: onOpenAssetManagement,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor),
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 18),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '資産管理のマネーカレンダー・借入/リボ記録を開く',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
