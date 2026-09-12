import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/lumen_path_page.dart';
import 'package:my_web_app/utils/feature_route_labels.dart';

import '../routes/app_route_names.dart';

void main() {
  testWidgets('Lumen Path exposes a named page and native fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LumenPathPage()));

    expect(find.text('光の道 · LUMEN PATH'), findsOneWidget);
    expect(
      find.text('光の道はWeb版のmy_web_appで利用できます。'),
      findsOneWidget,
    );
    expect(find.byTooltip('光のパズルを別タブで開く'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  test('Lumen Path has a stable same-origin asset and feature label', () {
    expect(
        kAllAppRoutes.where((route) => route == '/lumen-path'), hasLength(1));
    expect(LumenPathPage.assetPath, '/labs/lumen-path/index.html');
    expect(featureLabelForRoute('/lumen-path'), '光の道 · LUMEN PATH');
    expect(
      featureLabelForRoute('/lumen-path?from=home'),
      '光の道 · LUMEN PATH',
    );
    expect(canonicalFeatureRoutePath('/lumen-path'), '/lumen-path');
  });
}
