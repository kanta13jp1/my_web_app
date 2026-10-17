import 'package:flutter/material.dart';

class LumenPathSurface extends StatelessWidget {
  const LumenPathSurface({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '光の道はWeb版のmy_web_appで利用できます。',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
