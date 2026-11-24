import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/neon_showcase_page.dart';

void main() {
  testWidgets('shows a usable non-web fallback at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: NeonShowcasePage()));
    expect(find.text('Gemini 4 作品館 · NEON SHOWCASE'), findsOneWidget);
    expect(
      find.text('Gemini 4 作品館（NEON SHOWCASE）はWeb版のmy_web_appで利用できます。'),
      findsOneWidget,
    );
    expect(find.byTooltip('作品館を別タブで開く'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('route, catalog, self-hosted assets and demos stay connected', () {
    final main = File('lib/main.dart').readAsStringSync();
    final catalog = File('lib/data/home_tool_catalog.dart').readAsStringSync();
    expect(main, contains("case '/neon-showcase':"));
    expect(main, contains('const NeonShowcasePage()'));
    expect(catalog, contains("id: 'neon-showcase'"));
    expect(File('web${NeonShowcasePage.assetPath}').existsSync(), isTrue);
    final page = File('web${NeonShowcasePage.assetPath}').readAsStringSync();
    expect(page, contains('NEON SHOWCASE'));
    expect(page, isNot(contains('localhost')));
    final demosDir = Directory('web/labs/neon-showcase/demos');
    expect(demosDir.existsSync(), isTrue);
    final htmlCount = demosDir
        .listSync()
        .where((e) => e is File && e.path.endsWith('.html'))
        .length;
    expect(htmlCount, greaterThanOrEqualTo(2));
    final catalogJs = File(
      'web/labs/neon-showcase/catalog.js',
    ).readAsStringSync();
    final slugs = RegExp(
      r"slug:\s*'([a-z0-9-]+)'",
    ).allMatches(catalogJs).map((m) => m.group(1)!).toList();
    expect(slugs.length, equals(htmlCount));
    for (final slug in slugs) {
      expect(
        File('web/labs/neon-showcase/demos/$slug.html').existsSync(),
        isTrue,
      );
    }
  });
}
