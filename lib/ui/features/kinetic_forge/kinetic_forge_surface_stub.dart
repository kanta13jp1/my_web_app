import 'package:flutter/material.dart';

class KineticForgeSurface extends StatelessWidget {
  const KineticForgeSurface({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '描画実験室はWeb版のmy_web_appで利用できます。',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
