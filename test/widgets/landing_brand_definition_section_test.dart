import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/landing_brand_definition_section.dart';

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
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'renders brand definition, principles, and philosophy CTA at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = 0;

    await tester.pumpWidget(
      _wrapAt360x800(
        child: LandingBrandDefinitionSection(
          onPhilosophyTap: () => tapped++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('landing_brand_definition')), findsOneWidget);
    expect(find.text('自分株式会社とは'), findsOneWidget);
    expect(find.text('自分が人生のCEOとして決める'), findsOneWidget);
    expect(find.text('時間・お金・スキルを資産として育てる'), findsOneWidget);
    expect(find.text('他人ではなく昨日の自分をKPIにする'), findsOneWidget);

    final linkFinder = find.byKey(const Key('landing_brand_philosophy_link'));
    await tester.ensureVisible(linkFinder);
    await tester.tap(linkFinder);
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without overflow in dark theme at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        brightness: Brightness.dark,
        child: const LandingBrandDefinitionSection(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9つの基本理念を見る'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
