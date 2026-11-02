import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/features/aero_lab/aero_lab_surface.dart';

/// A leaf route: no AI requests, persistence, authentication or billing changes.
class AeroLabPage extends StatelessWidget {
  const AeroLabPage({super.key});

  static const assetPath = '/labs/aero-lab/index.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D実験室 · AERO LAB'),
        actions: [
          IconButton(
            tooltip: '実験室を別タブで開く',
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
      body: const SafeArea(child: AeroLabSurface()),
    );
  }
}
