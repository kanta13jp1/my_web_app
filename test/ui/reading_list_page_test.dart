import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/reading_list_page.dart';
import '../support/reading_fixture_repository.dart';

void main() {
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
      find.textContaining('延べ 0 ページ / 区間記録済み 0 / 総 100 ページ'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await repository.changes.close();
  });
}
