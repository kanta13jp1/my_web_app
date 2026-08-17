import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/philosophy_page.dart';

void main() {
  testWidgets('philosophy page explains the self-management operating model',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: PhilosophyPage()),
    );
    await tester.pump();

    expect(
      find.text('自分株式会社を30日で運営する実践ガイド'),
      findsOneWidget,
    );
    expect(find.text('個人の P/L・B/S'), findsOneWidget);
    expect(find.text('人生を6部署に分けて点検する'), findsOneWidget);
    expect(find.text('30日の運営サイクル'), findsOneWidget);
    expect(find.text('AIはCEOの代わりではなく伴走役'), findsOneWidget);
    expect(find.text('本社'), findsOneWidget);
    expect(find.text('人事'), findsOneWidget);
    expect(find.text('R&D'), findsOneWidget);
    expect(find.text('財務'), findsOneWidget);
    expect(find.text('マーケ営業'), findsOneWidget);
    expect(find.text('横断'), findsOneWidget);
    final documentTitle = find.byKey(const Key('philosophy_document_title'));
    expect(documentTitle, findsOneWidget);
    expect(
      tester.widget<Title>(documentTitle).title,
      philosophyDocumentTitle,
    );
    expect(tester.takeException(), isNull);
  });
}
