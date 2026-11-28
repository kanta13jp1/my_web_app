import 'package:flutter/material.dart';

class RelatedComparisonItem {
  final String competitorKey;
  final String emoji;
  final String name;
  final String searchKeyword;

  const RelatedComparisonItem({
    required this.competitorKey,
    required this.emoji,
    required this.name,
    required this.searchKeyword,
  });
}

class ComparisonRelatedComparisonsSection extends StatelessWidget {
  final List<RelatedComparisonItem> items;
  final ValueChanged<String>? onSelectCompetitor;
  final VoidCallback? onOpenLandscape;

  static const sectionKey = Key('comparison-related-comparisons-section');
  static const landscapeButtonKey = Key('comparison-landscape-button');

  const ComparisonRelatedComparisonsSection({
    super.key,
    required this.items,
    this.onSelectCompetitor,
    this.onOpenLandscape,
  });

  @override
  Widget build(BuildContext context) {
    const surfacePrimary = Color(0xFF0F172A);
    const surfaceMuted = Color(0xFF162033);
    const borderColor = Color(0xFF26334D);
    const textPrimary = Color(0xFFF5F7FB);
    const textSecondary = Color(0xFFB2BDD3);

    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '他の比較ページも見る',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.72,
                  color: textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '比較検討の途中なら、近いカテゴリの競合ページもすぐ見比べられます。',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items
                    .map(
                      (item) => InkWell(
                        key: Key('related-comparison-${item.competitorKey}'),
                        onTap: () {
                          final handler = onSelectCompetitor;
                          if (handler != null) {
                            handler(item.competitorKey);
                          } else {
                            Navigator.of(context)
                                .pushNamed('/vs-${item.competitorKey}');
                          }
                        },
                        borderRadius: BorderRadius.circular(18),
                        child: Ink(
                          width: 190,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfacePrimary,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.emoji} ${item.name}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.searchKeyword,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 20),
              InkWell(
                key: landscapeButtonKey,
                onTap: () {
                  final handler = onOpenLandscape;
                  if (handler != null) {
                    handler();
                  } else {
                    Navigator.of(context).pushNamed('/competitors');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: textSecondary,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '全294社の競合ランドスケープを見る →',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary,
                            height: 1.5,
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
      ),
    );
  }
}
