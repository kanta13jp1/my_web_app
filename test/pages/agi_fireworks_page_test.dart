import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/agi_fireworks_page.dart';

void main() {
  Widget subject({double width = 800, double height = 1000}) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: const AgiFireworksPage(),
      ),
    );
  }

  testWidgets('動画の概要、集計値、プライバシー注意を表示する', (tester) async {
    await tester.pumpWidget(subject());

    expect(find.text('AGI Fireworks'), findsOneWidget);
    expect(find.text('2026/07/15 – 08/14'), findsOneWidget);
    expect(find.text('1,129 shells'), findsOneWidget);
    expect(find.text('25 active nights'), findsOneWidget);
    expect(find.text('46,571 tool calls'), findsOneWidget);
    expect(find.byKey(const Key('agi-fireworks-video-frame')), findsOneWidget);
    expect(
      find.byKey(const Key('agi-fireworks-privacy-notice')),
      findsOneWidget,
    );
    expect(find.text('動画を別タブで開く'), findsOneWidget);
  });

  testWidgets('スマホ幅でも横方向にオーバーフローしない', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(subject(width: 375, height: 900));

    final page = tester.getRect(find.byType(Scaffold));
    final hero = tester.getRect(find.byKey(const Key('agi-fireworks-hero')));
    final video = tester.getRect(
      find.byKey(const Key('agi-fireworks-video-frame')),
    );

    expect(hero.left, greaterThanOrEqualTo(page.left));
    expect(hero.right, lessThanOrEqualTo(page.right));
    expect(video.left, greaterThanOrEqualTo(page.left));
    expect(video.right, lessThanOrEqualTo(page.right));
    expect(tester.takeException(), isNull);
  });
}
