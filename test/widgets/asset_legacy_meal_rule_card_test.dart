import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_legacy_meal_rule_card.dart';

void main() {
  for (final width in [1200.0, 390.0]) {
    for (final mode in ['none', 'active', 'paused']) {
      testWidgets('legacy meal rule $mode at $width', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var pauses = 0;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetLegacyMealRuleCard(
                hasHistory: mode != 'none',
                isEnabled: mode == 'active',
                entries: const ['合成の以前の振り返り'],
                onPause: () => pauses++,
              ),
            ),
          ),
        ));
        if (mode == 'none') {
          expect(find.byType(ExpansionTile), findsNothing);
          expect(find.textContaining('うどん'), findsNothing);
        } else {
          await tester.tap(find.text('以前の食費ルール（任意）'));
          await tester.pumpAndSettle();
          expect(find.text('合成の以前の振り返り'), findsOneWidget);
          final pause = find.text('以前の食費ルールを中断');
          if (mode == 'active') {
            await tester.tap(pause);
            expect(pauses, 1);
          } else {
            expect(pause, findsNothing);
            expect(pauses, 0);
          }
          expect(find.textContaining('誓い'), findsNothing);
          expect(find.textContaining('全額返済'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
