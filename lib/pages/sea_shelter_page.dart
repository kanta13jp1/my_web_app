import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/features/sea_shelter/sea_shelter_surface.dart';

/// A local-only game with no authentication, billing or database writes.
class SeaShelterPage extends StatelessWidget {
  const SeaShelterPage({super.key});

  static const assetPath = '/labs/sea-shelter/index.html';

  @override
  Widget build(BuildContext context) => Scaffold(
        // The web game supplies its own compact header and viewport layout.
        appBar: kIsWeb ? null : AppBar(title: const Text('潮灯のシェルター')),
        body: const SafeArea(child: SeaShelterSurface()),
      );
}
