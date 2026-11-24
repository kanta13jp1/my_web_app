import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ui/features/flow_city/flow_city_surface.dart';

/// A leaf route: no AI requests, authentication or billing changes.
class FlowCityPage extends StatelessWidget {
  const FlowCityPage({super.key});

  static const assetPath = '/labs/flow-city/index.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('交通実験室 · FLOW CITY'),
        actions: [
          IconButton(
            tooltip: '交通比較を別タブで開く',
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
      body: const SafeArea(child: FlowCitySurface()),
    );
  }
}
