import 'package:flutter/material.dart';

class ComparisonOutcomeCardItem {
  const ComparisonOutcomeCardItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
}

class ComparisonOutcomeCardsSection extends StatelessWidget {
  const ComparisonOutcomeCardsSection({
    super.key,
    required this.accentColor,
    this.items,
  });

  static const sectionKey = Key('comparison-outcome-cards-section');

  static const Color _surfacePrimary = Color(0xFF141821);
  static const Color _textPrimary = Color(0xFFF5F7FB);
  static const Color _textSecondary = Color(0xFFA8B3C7);
  static const Color _indigo = Color(0xFF3D5AFE);
  static const Color _orange = Color(0xFFFF6B35);

  final Color accentColor;
  final List<ComparisonOutcomeCardItem>? items;

  @override
  Widget build(BuildContext context) {
    final cards = items ??
        <ComparisonOutcomeCardItem>[
          ComparisonOutcomeCardItem(
            icon: Icons.hub_rounded,
            title: '日常の作業をひとつに集約',
            body: 'ノート・タスク・財務・習慣・AI大学まで、別アプリで分かれていた流れをまとめます。',
            accent: accentColor,
          ),
          const ComparisonOutcomeCardItem(
            icon: Icons.currency_yen_rounded,
            title: 'まず無料で始めて、必要になってから広げる',
            body: '比較検討の段階でも登録しやすく、月額の積み上がりを気にせず試せます。',
            accent: _orange,
          ),
          const ComparisonOutcomeCardItem(
            icon: Icons.auto_graph_rounded,
            title: 'AI が「今日やること」を1件に絞る',
            body: '判断・実行・振り返りまでを、ひとつの流れとして支援します。',
            accent: _indigo,
          ),
        ];

    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              if (compact) {
                return Column(
                  children: cards
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _OutcomeCard(item: item, fullWidth: true),
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(
                      child: _OutcomeCard(item: cards[i], fullWidth: false),
                    ),
                    if (i != cards.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.item,
    required this.fullWidth,
  });

  final ComparisonOutcomeCardItem item;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ComparisonOutcomeCardsSection._surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: item.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.accent),
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ComparisonOutcomeCardsSection._textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.body,
            style: const TextStyle(
              fontSize: 13,
              color: ComparisonOutcomeCardsSection._textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
