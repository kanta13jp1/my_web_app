import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/horse_racing_venue_header.dart';

Widget _wrapAt360x800({
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.indigo,
    ),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 800),
        textScaler: TextScaler.linear(2.0),
      ),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders JRA, NAR, and overseas venue badges at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HorseRacingVenueHeader(venue: '東京', raceCount: 12),
            HorseRacingVenueHeader(venue: '大井', raceCount: 11),
            HorseRacingVenueHeader(venue: 'Sha Tin', raceCount: 10),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('東京'), findsOneWidget);
    expect(find.text('JRA'), findsOneWidget);
    expect(find.text('12 R'), findsOneWidget);

    expect(find.text('大井'), findsOneWidget);
    expect(find.text('地方'), findsOneWidget);
    expect(find.text('11 R'), findsOneWidget);

    expect(find.text('Sha Tin'), findsOneWidget);
    expect(find.text('海外'), findsOneWidget);
    expect(find.text('10 R'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('handles long venue name in dark mode without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        brightness: Brightness.dark,
        child: const HorseRacingVenueHeader(
          venue: 'テスト長名称競馬場ああああああああああああああ',
          raceCount: 8,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('JRA'), findsOneWidget);
    expect(find.text('8 R'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
