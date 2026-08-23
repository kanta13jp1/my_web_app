import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_primary_action_card.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('fits a 390px viewport in $brightness mode', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final colorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F46E5),
        brightness: brightness,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomePrimaryActionCard(
                accentColor: const Color(0xFFFFC107),
                icon: Icons.wb_sunny,
                title: 'モーニング・ブリーフィングを先に実施',
                detail: '朝の優先順位を確定してから他のメニューへ進みます。',
                buttonLabel: 'ブリーフィングへ',
                onPressed: () {},
                aiNudge: '最初の10分で、確認先を1つに絞りましょう。',
                pendingCriticalTaskCount: 2,
              ),
            ),
          ),
        ),
      );

      expect(find.text('今日の1件'), findsOneWidget);
      expect(find.text('ブリーフィングへ'), findsOneWidget);
      expect(find.textContaining('AIの提案:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
