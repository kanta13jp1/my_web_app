import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/vibe_sim_lab_page.dart';

void main() {
  testWidgets('renders cleanly at desktop (1280x800) and mobile (390x844)', (
    final tester,
  ) async {
    for (final size in const <Size>[Size(1280, 800), Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: VibeSimLabPage()));
      await tester.pumpAndSettle();

      expect(find.text('Vibe Sim 物理破綻診断ラボ'), findsOneWidget);
      expect(find.byKey(const Key('vibe-sim-risk-summary')), findsOneWidget);
      expect(find.textContaining('危険'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'happy, error, and recovery user flows update diagnosis and snippet',
      (final tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: VibeSimLabPage()));
    await tester.pumpAndSettle();

    // 1. Happy path: switch to v3_audited
    await tester.ensureVisible(find.byKey(const Key('vibe-sim-preset-v3')));
    await tester.tap(find.byKey(const Key('vibe-sim-preset-v3')));
    await tester.pumpAndSettle();

    expect(find.textContaining('安全（監査基準準拠レベル）'), findsOneWidget);
    final copyEnabled = tester.widget<FilledButton>(
      find.byKey(const Key('vibe-sim-copy-snippet')),
    );
    expect(copyEnabled.onPressed, isNotNull);

    // 2. Error path: enter invalid negative timestep
    await tester
        .ensureVisible(find.byKey(const Key('vibe-sim-field-timestep')));
    await tester.enterText(
      find.byKey(const Key('vibe-sim-field-timestep')),
      '-1',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vibe-sim-error-banner')), findsOneWidget);
    final copyDisabled = tester.widget<FilledButton>(
      find.byKey(const Key('vibe-sim-copy-snippet')),
    );
    expect(copyDisabled.onPressed, isNull);

    // 3. Recovery path: tap restore v3_audited button
    await tester.ensureVisible(find.byKey(const Key('vibe-sim-recover-v3')));
    await tester.tap(find.byKey(const Key('vibe-sim-recover-v3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vibe-sim-error-banner')), findsNothing);
    expect(find.textContaining('安全（監査基準準拠レベル）'), findsOneWidget);
    final copyRecovered = tester.widget<FilledButton>(
      find.byKey(const Key('vibe-sim-copy-snippet')),
    );
    expect(copyRecovered.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  test('route, catalog, feature label, and route registry stay wired', () {
    final main = File('lib/main.dart').readAsStringSync();
    final catalog = File('lib/data/home_tool_catalog.dart').readAsStringSync();
    final labels =
        File('lib/utils/feature_route_labels.dart').readAsStringSync();
    final routeNames =
        File('test/routes/app_route_names.dart').readAsStringSync();

    expect(main, contains("case '/vibe-sim-lab':"));
    expect(main, contains('const VibeSimLabPage()'));
    expect(catalog, contains("id: 'vibe-sim-lab'"));
    expect(labels, contains("'/vibe-sim-lab': 'Vibe Sim 物理破綻診断ラボ'"));
    expect(routeNames, contains("'/vibe-sim-lab',"));
  });
}
