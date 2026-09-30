import 'package:flutter/material.dart';

class FlowCitySurface extends StatelessWidget {
  const FlowCitySurface({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '交通実験室はWeb版のmy_web_appで利用できます。',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
