import 'package:flutter/material.dart';

class NeonShowcaseSurface extends StatelessWidget {
  const NeonShowcaseSurface({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Gemini 4 作品館（NEON SHOWCASE）はWeb版のmy_web_appで利用できます。',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
