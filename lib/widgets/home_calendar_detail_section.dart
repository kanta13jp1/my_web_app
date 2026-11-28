import 'package:flutter/material.dart';

/// ホーム画面カレンダー詳細モーダル内のセクションカード（タイトルと箇条書き・空状態を表示する）。
class HomeCalendarDetailSection extends StatelessWidget {
  const HomeCalendarDetailSection({
    super.key,
    required this.title,
    required this.accent,
    required this.items,
    required this.emptyLabel,
  });

  final String title;
  final Color accent;
  final List<String> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: accent,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(emptyLabel)
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('・$item'),
              ),
            ),
        ],
      ),
    );
  }
}
