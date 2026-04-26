import 'package:flutter/material.dart';

import '../services/web_reload.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 220),
                child: Text(
                  '新しいバージョンが利用可能です',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  triggerWebReload();
                  onDismiss();
                },
                child: const Text('更新する'),
              ),
              TextButton(
                onPressed: onDismiss,
                child: const Text('あとで'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
