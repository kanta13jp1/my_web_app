import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/features/sound_bloom/sound_bloom_surface.dart';

/// A leaf route: no AI requests, persistence, authentication or billing changes.
class SoundBloomPage extends StatelessWidget {
  const SoundBloomPage({super.key});

  static const assetPath = '/labs/sound-bloom/index.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音と光の庭 · SOUND BLOOM'),
        actions: [
          IconButton(
            tooltip: '音の庭を別タブで開く',
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
      body: const SafeArea(child: SoundBloomSurface()),
    );
  }
}
