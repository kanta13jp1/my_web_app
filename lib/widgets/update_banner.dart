import 'package:flutter/material.dart';

import '../services/web_reload.dart';

class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: const Text('新しいバージョンが利用可能です'),
      actions: [
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
    );
  }
}
