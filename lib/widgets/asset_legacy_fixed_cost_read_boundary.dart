import 'package:flutter/material.dart';

/// Marks aggregates whose legacy subscription source has not been read.
/// It does not change records, amounts, or the child's editable state.
class AssetLegacyFixedCostReadBoundary extends StatelessWidget {
  const AssetLegacyFixedCostReadBoundary({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.child,
  });

  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final failed = hasError && !isLoading;
    final textColor =
        failed ? colors.onErrorContainer : colors.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoading || hasError)
          Card(
            color:
                failed ? colors.errorContainer : colors.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? '旧固定費を確認中です' : '旧固定費を読み取れませんでした',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '以下の合計・収支計画・残高見込みは、旧固定費が未取得の参考値です。'
                    '未登録や0円とは確定できません。',
                    style: TextStyle(color: textColor),
                  ),
                  if (hasError && !isLoading)
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('旧固定費を再読込'),
                    ),
                ],
              ),
            ),
          ),
        KeyedSubtree(
          key: const ValueKey('legacy-fixed-cost-read-content'),
          child: child,
        ),
      ],
    );
  }
}
