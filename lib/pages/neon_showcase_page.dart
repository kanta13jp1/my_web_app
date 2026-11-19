import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/features/neon_showcase/neon_showcase_surface.dart';

/// A leaf route: no AI requests, persistence, authentication or billing changes.
class NeonShowcasePage extends StatelessWidget {
  const NeonShowcasePage({super.key});

  static const assetPath = '/labs/neon-showcase/index.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini 4 作品館 · NEON SHOWCASE'),
        actions: [
          IconButton(
            tooltip: '作品館を別タブで開く',
            icon: const Icon(Icons.open_in_new),
            onPressed: () async {
              final opened = await launchUrl(
                Uri.base.resolve(assetPath),
                webOnlyWindowName: '_blank',
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('別タブを開けませんでした。')));
              }
            },
          ),
        ],
      ),
      body: const SafeArea(child: NeonShowcaseSurface()),
    );
  }
}
