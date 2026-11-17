import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/flow_city_page.dart';
import 'package:my_web_app/utils/feature_route_labels.dart';

import '../routes/app_route_names.dart';

void main() {
  testWidgets('Flow City exposes a named page and native fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FlowCityPage()));

    expect(find.text('交通実験室 · FLOW CITY'), findsOneWidget);
    expect(
      find.text('交通実験室はWeb版のmy_web_appで利用できます。'),
      findsOneWidget,
    );
    expect(find.byTooltip('交通比較を別タブで開く'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  test('Flow City has a stable same-origin asset and feature label', () {
    expect(
      kAllAppRoutes.where((route) => route == '/flow-city'),
      hasLength(1),
    );
    expect(FlowCityPage.assetPath, '/labs/flow-city/index.html');
    expect(featureLabelForRoute('/flow-city'), '交通実験室 · FLOW CITY');
    expect(
      featureLabelForRoute('/flow-city?from=home'),
      '交通実験室 · FLOW CITY',
    );
    expect(canonicalFeatureRoutePath('/flow-city'), '/flow-city');
  });
}
