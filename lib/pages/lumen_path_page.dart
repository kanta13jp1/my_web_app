import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/features/lumen_path/lumen_path_surface.dart';

/// A leaf route: no AI requests, persistence, authentication or billing changes.
class LumenPathPage extends StatelessWidget {
  const LumenPathPage({super.key});

  static const assetPath = '/labs/lumen-path/index.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('光の道 · LUMEN PATH'),
        actions: [
          IconButton(
            tooltip: '光のパズルを別タブで開く',
            icon: const Icon(Icons.open_in_new),
            onPressed: () async {
              final opened = await launchUrl(
                Uri.base.resolve(assetPath),
                webOnlyWindowName: '_blank',
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('別タブを開けませんでした。')),
                );
              }
            },
          ),
        ],
      ),
      body: const SafeArea(child: LumenPathSurface()),
    );
  }
}
