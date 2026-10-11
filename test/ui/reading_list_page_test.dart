import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/reading_list_page.dart';
import '../support/reading_fixture_repository.dart';

void main() {
  testWidgets(
      '320px guest layout browses author to works and empty progress without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ReadingFixtureRepository()..user = null;
    await tester
        .pumpWidget(MaterialApp(home: ReadingListPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プラトン'));
    await tester.pumpAndSettle();
    expect(find.text('国家'), findsOneWidget);
    await tester.tap(find.text('国家'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repository.changes.close();
  });
  testWidgets(
      'failed record save keeps entered edition and retries successfully',
      (tester) async {
    final repository = ReadingFixtureRepository();
    await tester
        .pumpWidget(MaterialApp(home: ReadingListPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プラトン'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('国家'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('読書を始める'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('reading-field-total')), '100',);
    repository.failNextSave = true;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('読む版を登録'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('reading-field-total')),)
            .controller!
            .text,
        '100',);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('読む版を登録'), findsNothing);
    expect(find.textContaining('総 100 ページ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await repository.changes.close();
  });
}
