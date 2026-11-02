import 'package:flutter/material.dart';

class SoundBloomSurface extends StatelessWidget {
  const SoundBloomSurface({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '音と光の庭はWeb版のmy_web_appで利用できます。',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
