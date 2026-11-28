import 'package:flutter/material.dart';

import 'home_primary_action_card.dart';

class HomeTodayActionSection extends StatelessWidget {
  const HomeTodayActionSection({
    super.key,
    required this.actionTypeName,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.onPressed,
    this.aiNudge,
    this.isAiNudgeLoading = false,
    this.pendingCriticalTaskCount = 0,
    this.pendingStockTaskCount = 0,
  });

  static const headerKey = Key('home_section_today_action');
  static const Color _headerColor = Color(0xFF4F46E5);

  final String actionTypeName;
  final Color accentColor;
  final IconData icon;
  final String title;
  final String detail;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String? aiNudge;
  final bool isAiNudgeLoading;
  final int pendingCriticalTaskCount;
  final int pendingStockTaskCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: headerKey,
          padding: const EdgeInsets.only(bottom: 12.0, left: 2, right: 2),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _headerColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.ads_click_outlined,
                  color: _headerColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Flexible(
                child: Text(
                  '今日の1件',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _headerColor,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  color: _headerColor.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
        HomePrimaryActionCard(
          key: Key('home_next_action_$actionTypeName'),
          accentColor: accentColor,
          icon: icon,
          title: title,
          detail: detail,
          buttonLabel: buttonLabel,
          onPressed: onPressed,
          aiNudge: aiNudge,
          isAiNudgeLoading: isAiNudgeLoading,
          pendingCriticalTaskCount: pendingCriticalTaskCount,
          pendingStockTaskCount: pendingStockTaskCount,
        ),
      ],
    );
  }
}
