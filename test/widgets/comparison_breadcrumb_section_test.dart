import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/comparison_breadcrumb_section.dart';

Widget _wrapAt360x800({
  required Widget child,
  Brightness brightness = Brightness.dark,
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
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'renders breadcrumb items and invokes tap callbacks at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var homeTapped = 0;
    var competitorsTapped = 0;

    await tester.pumpWidget(
      _wrapAt360x800(
        child: ComparisonBreadcrumbSection(
          emoji: '📝',
          name: 'Notion',
          onHomeTap: () => homeTapped++,
          onCompetitorsTap: () => competitorsTapped++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('自分株式会社'), findsOneWidget);
    expect(find.text('競合比較'), findsOneWidget);
    expect(find.text('📝 Notion'), findsOneWidget);

    await tester.tap(find.text('自分株式会社'));
    await tester.tap(find.text('競合比較'));
    await tester.pumpAndSettle();

    expect(homeTapped, 1);
    expect(competitorsTapped, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps long competitor name cleanly in light mode at 360x800',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        brightness: Brightness.light,
        child: const ComparisonBreadcrumbSection(
          emoji: '📊',
          name: 'LongCompetitorComparisonNameForNarrowViewportTest',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('📊 LongCompetitorComparisonNameForNarrowViewportTest'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
