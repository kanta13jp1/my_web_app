import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/sea_shelter_page.dart';
import 'package:my_web_app/utils/feature_route_labels.dart';

import '../routes/app_route_names.dart';

void main() {
  testWidgets('sea shelter has a native fallback and disposes cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SeaShelterPage()));
    expect(find.text('潮灯のシェルター'), findsOneWidget);
    expect(find.text('潮灯のシェルターはWeb版のmy_web_appで遊べます。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  test('sea shelter has a unique route, stable asset and label', () {
    expect(
      kAllAppRoutes.where((route) => route == '/sea-shelter'),
      hasLength(1),
    );
    expect(SeaShelterPage.assetPath, '/labs/sea-shelter/index.html');
    expect(featureLabelForRoute('/sea-shelter?from=home'), '潮灯のシェルター');
  });
}
