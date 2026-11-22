import 'package:flutter/material.dart';

/// Keeps earlier opt-in records accessible without proposing a single-food rule.
class AssetLegacyMealRuleCard extends StatelessWidget {
  const AssetLegacyMealRuleCard({
    super.key,
    required this.hasHistory,
    required this.isEnabled,
    required this.entries,
    required this.onPause,
  });

  final bool hasHistory;
  final bool isEnabled;
  final List<String> entries;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    if (!hasHistory) return const SizedBox.shrink();
    return ExpansionTile(
      key: const Key('legacy-meal-rule-history'),
      title: const Text('以前の食費ルール（任意）'),
      subtitle: Text(isEnabled ? '継続設定あり・中断できます' : '中断中・履歴を保持しています'),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        const Text('以前の記録を参照できます。一律に食事を制限する提案は行いません。保存済みの履歴は変更しません。'),
        for (final entry in entries) ListTile(title: Text(entry)),
        if (entries.isEmpty) const Text('振り返りの記録はありません。'),
        if (isEnabled)
          OutlinedButton.icon(
            onPressed: onPause,
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('以前の食費ルールを中断'),
          ),
      ],
    );
  }
}
