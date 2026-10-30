import 'package:flutter/material.dart';

class SeaShelterSurface extends StatelessWidget {
  const SeaShelterSurface({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        '潮灯のシェルターはWeb版のmy_web_appで遊べます。',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
