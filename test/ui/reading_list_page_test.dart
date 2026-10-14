import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/reading_list_page.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';
import '../support/reading_fixture_repository.dart';

void main() {
  testWidgets('320px duplicate works have one card and keep both stored records', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ReadingFixtureRepository();
    const author = PhilosophyAuthor(id: 'plato', name: 'プラトン');
    for (final id in ['plato:republic', 'legacy:republic']) {
      repository.items[id] = ReadingRecord(id: id, work: PhilosophyWork(id: id, title: '国家', author: author), cycles: [ReadingCycle(id: 'same-cycle', startedAt: '2026-10-14', edition: ReadingEdition(publisher: id, totalPages: 100), entries: [ReadingEntry(id: 'entry', date: '2026-10-14', pages: 10, endPage: 10, impression: id)])]);
    }
    final before = {for (final record in repository.items.values) record.id: record.savePayload()};
    await tester.pumpWidget(MaterialApp(home: ReadingListPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '国家');
    await tester.pumpAndSettle();
    expect(find.text('プラトン'), findsOneWidget);
    await tester.tap(find.text('プラトン'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '国家'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, '国家'));
    await tester.pumpAndSettle();
    expect(find.textContaining('同じ著作の記録をまとめて表示'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect({for (final record in repository.items.values) record.id: record.savePayload()}, before);
    await repository.changes.close();
  });

  testWidgets(
      '320px author search finds a work title and opens its matching work',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ReadingFixtureRepository();
    await tester
        .pumpWidget(MaterialApp(home: ReadingListPage(repository: repository)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '国家');
    await tester.pumpAndSettle();
    expect(find.text('プラトン'), findsOneWidget);
    expect(find.textContaining(RegExp(r'該当する著作: 国家$')), findsOneWidget);
    await tester.tap(find.text('プラトン'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '国家'), findsOneWidget);
    expect(find.text('饗宴'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repository.changes.close();
  });

  testWidgets('work memo saves at 320px without starting reading',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ReadingFixtureRepository();
    await tester.pumpWidget(
      MaterialApp(home: ReadingListPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('プラトン'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('国家'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('著作にメモを追記'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reading-field-memo')),
      '画像確認メモ',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('画像確認メモ'), findsWidgets);
    expect(find.text('読書を始める'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repository.changes.close();
  });

  testWidgets('quick page update keeps failed input and works at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ReadingFixtureRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ReadingListPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('プラトン'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('国家'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('読書を始める'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('reading-field-total')),
      '160',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('reading-reached-page'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '85');
    repository.failNextSave = true;
    await tester.tap(find.text('進捗を更新'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(input).controller!.text, '85');
    expect(find.textContaining('入力を保持しています'), findsWidgets);
    await tester.tap(find.text('進捗を更新'));
    await tester.pumpAndSettle();
    expect(find.text('85ページまでの進捗を保存しました'), findsOneWidget);
    expect(find.text('85ページまで／全160ページ・53.1％'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repository.changes.close();
  });

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
    expect(
      tester
          .widget<FilledButton>(
            find.byWidgetPredicate(
              (widget) => widget is FilledButton,
            ),
          )
          .onPressed,
      isNull,
    );
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
      find.byKey(const ValueKey('reading-field-total')),
      '100',
    );
    repository.failNextSave = true;
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('読む版を登録'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('reading-field-total')),
          )
          .controller!
          .text,
      '100',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('読む版を登録'), findsNothing);
    expect(
      find.textContaining('0ページまで／全100ページ・0.0％'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await repository.changes.close();
  });
}
