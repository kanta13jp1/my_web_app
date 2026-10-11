import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/reading_book_lookup.dart';
import 'package:my_web_app/data/services/reading_book_search.dart';
import 'package:my_web_app/domain/models/philosophy_reading.dart';

void main() {
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
