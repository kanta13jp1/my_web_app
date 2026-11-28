import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_emergency_meeting_card.dart';

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

  group('HomeEmergencyMeetingCard @ 360x800 2.0x', () {
    testWidgets('renders normal state and fires onTap without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = 0;
      await tester.pumpWidget(
        wrapMobile2x(
          HomeEmergencyMeetingCard(onTap: () => tapped++),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(HomeEmergencyMeetingCard.cardKey), findsOneWidget);
      expect(find.text('緊急役員会議'), findsOneWidget);
      expect(
        find.text('CEOとして全AI役員を招集し、直面している課題を解決します。'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(HomeEmergencyMeetingCard.cardKey));
      await tester.tap(find.byKey(HomeEmergencyMeetingCard.cardKey));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('renders cleanly in dark theme', (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapMobile2x(
          HomeEmergencyMeetingCard(onTap: () {}),
          theme: ThemeData.dark(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(HomeEmergencyMeetingCard.cardKey), findsOneWidget);
      expect(find.text('緊急役員会議'), findsOneWidget);
    });

    testWidgets('hides card when isVisible is false', (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapMobile2x(
          HomeEmergencyMeetingCard(
            isVisible: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(HomeEmergencyMeetingCard.cardKey), findsNothing);
    });
  });
}
