import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/aero_lab_page.dart';

void main() {
  testWidgets('shows a usable non-web fallback at narrow width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: AeroLabPage()));
    expect(find.text('3D実験室 · AERO LAB'), findsOneWidget);
    expect(find.text('3D実験室はWeb版のmy_web_appで利用できます。'), findsOneWidget);
    expect(find.byTooltip('実験室を別タブで開く'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('route, catalog and self-hosted asset stay connected', () {
    final main = File('lib/main.dart').readAsStringSync();
    final catalog = File('lib/data/home_tool_catalog.dart').readAsStringSync();
    expect(main, contains("case '/aero-lab':"));
    expect(main, contains('const AeroLabPage()'));
    expect(catalog, contains("id: 'aero-lab'"));
    expect(File('web${AeroLabPage.assetPath}').existsSync(), isTrue);
    final page = File('web${AeroLabPage.assetPath}').readAsStringSync();
    expect(page, contains('実機の性能や物理シミュレーションではありません'));
    expect(page, isNot(contains('localhost')));
  });
}
