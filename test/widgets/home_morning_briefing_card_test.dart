import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_morning_briefing_card.dart';

void main() {
  const mobileViewport = Size(360, 800);

  Widget wrapMobile2x(Widget child, {ThemeData? theme}) {
    return MediaQuery(
      data: const MediaQueryData(
        size: mobileViewport,
        textScaler: TextScaler.linear(2.0),
      ),
      child: MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('HomeMorningBriefingCard @ 360x800 2.0x', () {
    testWidgets('renders normal state and fires onTap without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = 0;
      await tester.pumpWidget(
        wrapMobile2x(
          HomeMorningBriefingCard(onTap: () => tapped++),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(HomeMorningBriefingCard.cardKey), findsOneWidget);
      expect(find.text('モーニング・ブリーフィング'), findsOneWidget);
      expect(find.text('今日のタスクと優先順位を確認します。'), findsOneWidget);

      await tester.ensureVisible(find.byKey(HomeMorningBriefingCard.cardKey));
      await tester.tap(find.byKey(HomeMorningBriefingCard.cardKey));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('renders highlighted priority state in dark theme',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapMobile2x(
          HomeMorningBriefingCard(
            isHighlighted: true,
            onTap: () {},
          ),
          theme: ThemeData.dark(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('モーニング・ブリーフィング（最優先）'), findsOneWidget);
      expect(find.text('まず朝の優先順位を固定してください。'), findsOneWidget);
    });

    testWidgets('hides card when isVisible is false', (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapMobile2x(
          HomeMorningBriefingCard(
            isVisible: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(HomeMorningBriefingCard.cardKey), findsNothing);
    });
  });
}
