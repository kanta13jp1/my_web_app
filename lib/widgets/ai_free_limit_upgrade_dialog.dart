import 'package:flutter/material.dart';

import '../services/ai_service.dart';

Future<bool> showAiFreeLimitUpgradeDialog(
  BuildContext context,
  AIServiceException error,
) async {
  if (!error.isFreeLimitReached) {
    return false;
  }

  final route = _upgradeRoute(error.upgradeUrl);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('ai_free_limit_upgrade_dialog'),
        title: const Text('無料枠の上限に達しました'),
        content: Text(
          error.message.isEmpty
              ? '今月の無料AI質問枠を使い切りました。Proプランに切り替えると、上限を気にせずAI機能を使えます。'
              : error.message,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('あとで'),
          ),
          FilledButton.icon(
            key: const Key('ai_free_limit_upgrade_primary_button'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamed(route);
            },
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: const Text('Proプランを見る'),
          ),
        ],
      );
    },
  );
  return true;
}

String _upgradeRoute(String? rawUrl) {
  final value = rawUrl?.trim();
  if (value == null || value.isEmpty) {
    return '/billing';
  }
  final parsed = Uri.tryParse(value);
  final path = parsed?.path.trim();
  if (path == null || path.isEmpty) {
    return '/billing';
  }
  return path.startsWith('/') ? path : '/$path';
}
