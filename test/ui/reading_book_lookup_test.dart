import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/reading_book_lookup.dart';
import 'package:my_web_app/data/services/reading_book_search.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';

void main() {
  testWidgets('changing an automatic query discards its late response',
      (tester) async {
    final pending = Completer<List<ReadingBookResult>>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReadingBookLookup(
      initialQuery: '古い検索',
      onSelected: (_) {},
      search: (query) async => query == '古い検索' ? pending.future : [
        const ReadingBookResult('新しい結果', ReadingEdition()),
      ],
    ),),),);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '新しい検索');
    await tester.tap(find.text('書籍情報を検索'));
    await tester.pumpAndSettle();
    expect(find.text('新しい結果'), findsOneWidget);
    pending.complete([
      const ReadingBookResult('古い結果', ReadingEdition()),
    ],);
    await tester.pumpAndSettle();
    expect(find.text('古い結果'), findsNothing);
    expect(find.text('新しい結果'), findsOneWidget);
  });

  testWidgets(
      'initial title searches once without typing or selecting metadata',
      (tester) async {
    var calls = 0;
    ReadingEdition? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingBookLookup(
            initialQuery: '読書について',
            onSelected: (value) => selected = value,
            search: (query) async {
              calls++;
              expect(query, '読書について');
              return [
                const ReadingBookResult(
                  '岩波文庫',
                  ReadingEdition(publisher: '岩波書店'),
                ),
              ];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('岩波文庫'), findsOneWidget);
    expect(selected, isNull);
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets(
      'a result is applied only after confirmation; cancel keeps existing data',
      (tester) async {
    ReadingEdition? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingBookLookup(
            onSelected: (edition) => selected = edition,
            search: (_) async => [
              const ReadingBookResult(
                '検索候補',
                ReadingEdition(publisher: '出版社', isbn: '9781234567897'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '検索');
    await tester.tap(find.text('書籍情報を検索'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('検索候補'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    await tester.tap(find.text('検索候補'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('書籍情報を設定'));
    await tester.pumpAndSettle();
    expect(selected?.publisher, '出版社');
  });
  testWidgets('network failure leaves manual entry available and offers retry',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadingBookLookup(
            onSelected: (_) {},
            search: (_) async => throw Exception('offline'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('書籍情報を検索'));
    await tester.pumpAndSettle();
    expect(find.text('書籍情報を取得できませんでした。再検索または手入力できます。'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '書籍情報を検索'))
          .onPressed,
      isNotNull,
    );
  });
}
