import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/kinetic_forge_page.dart';
import 'package:my_web_app/utils/feature_route_labels.dart';

import '../routes/app_route_names.dart';

void main() {
  testWidgets('Kinetic Forge exposes a named page and native fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: KineticForgePage()));

    expect(find.text('描画実験室 · KINETIC FORGE'), findsOneWidget);
    expect(
      find.text('描画実験室はWeb版のmy_web_appで利用できます。'),
      findsOneWidget,
    );
    expect(find.byTooltip('描画実験室を別タブで開く'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  test('Kinetic Forge has a stable same-origin asset and feature label', () {
    expect(
      kAllAppRoutes.where((route) => route == '/kinetic-forge'),
      hasLength(1),
    );
    expect(KineticForgePage.assetPath, '/labs/kinetic-forge/index.html');
    expect(featureLabelForRoute('/kinetic-forge'), '描画実験室 · KINETIC FORGE');
    expect(
      featureLabelForRoute('/kinetic-forge?from=home'),
      '描画実験室 · KINETIC FORGE',
    );
    expect(canonicalFeatureRoutePath('/kinetic-forge'), '/kinetic-forge');
  });
}
