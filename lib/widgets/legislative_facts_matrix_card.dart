import 'package:flutter/material.dart';
import 'package:my_web_app/services/legislative_facts_service.dart';

/// Side-by-side legislative facts comparison matrix card (#2806).
class LegislativeFactsMatrixCard extends StatelessWidget {
  const LegislativeFactsMatrixCard({
    super.key,
    required this.matrix,
    this.onOpenSource,
  });

  final LegislativeFactComparisonMatrix matrix;
  final void Function(String sourceUrl)? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              matrix.topicKey,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (matrix.columns.isEmpty)
              Text(
                '登録済みの立法事実はありません。',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final col in matrix.columns)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                col.factionName,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              for (final fact in col.facts)
                                _FactItemTile(
                                  fact: fact,
                                  onOpenSource: onOpenSource,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FactItemTile extends StatelessWidget {
  const _FactItemTile({
    required this.fact,
    required this.onOpenSource,
  });

  final LegislativeFactEntry fact;
  final void Function(String sourceUrl)? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '[${fact.stance.label}] ${fact.summary}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                fact.sourceTitle,
                style: theme.textTheme.bodySmall,
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48),
                ),
                onPressed: onOpenSource == null
                    ? null
                    : () => onOpenSource!(fact.sourceUrl),
                child: const Text('出典'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
