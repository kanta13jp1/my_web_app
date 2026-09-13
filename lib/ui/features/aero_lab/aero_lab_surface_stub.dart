import 'package:flutter/material.dart';

class AeroLabSurface extends StatelessWidget {
  const AeroLabSurface({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '3D実験室はWeb版のmy_web_appで利用できます。',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
