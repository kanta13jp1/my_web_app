import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/wiki_database_page.dart';
import 'package:my_web_app/repositories/wiki_repository.dart';

void main() {
  testWidgets(
      'selecting page renders subpages, table rows, truncation hints, and adds row',
      (tester) async {
    final rows = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'row-1',
        'created_at': '2026-11-24T00:00:00Z',
        'metadata': <String, dynamic>{
          'sheet_id': 'page-1',
          'data': <String, dynamic>{'content': '既存テーブル行'},
        },
      },
    ];
    final repository = WikiRepository((body) async {
      switch (body['action']) {
        case 'wiki.list':
          return {
            'success': true,
            'pages': [
              {
                'id': 'page-1',
                'created_at': '2026-11-24T00:00:00Z',
                'metadata': {'title': '親ページ', 'content': '本文テキスト'},
              },
            ],
            'next_offset': null,
          };
        case 'wiki.get':
          if (body['id'] == 'child-1') {
            return {
              'success': true,
              'page': {
                'id': 'child-1',
                'metadata': {'title': '子ページ詳細', 'content': '子ページ本文'},
              },
              'children': <dynamic>[],
              'children_has_more': false,
              'table_rows': <dynamic>[],
              'table_rows_has_more': false,
            };
          }
          return {
            'success': true,
            'page': {
              'id': 'page-1',
              'metadata': {'title': '親ページ', 'content': '本文テキスト'},
            },
            'children': [
              {
                'id': 'child-1',
                'metadata': {'title': '子ページ1', 'parent_id': 'page-1'},
              },
            ],
            'children_has_more': true,
            'table_rows': List<Map<String, dynamic>>.from(rows),
            'table_rows_has_more': true,
          };
        case 'sheet.add_row':
          final data = body['data'] as Map<String, dynamic>;
          final created = <String, dynamic>{
            'id': 'row-2',
            'created_at': '2026-11-25T00:00:00Z',
            'metadata': <String, dynamic>{
              'sheet_id': body['sheet_id'],
              'data': data,
            },
          };
          rows.add(created);
          return <String, dynamic>{'success': true, 'row': created};
      }
      throw StateError('Unexpected action ${body['action']}');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WikiDatabasePage(
          wikiRepository: repository,
          isAuthenticatedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('親ページ'), findsOneWidget);

    await tester.tap(find.text('親ページ'));
    await tester.pumpAndSettle();

    expect(find.text('本文テキスト'), findsOneWidget);
    expect(find.text('子ページ1'), findsOneWidget);
    expect(find.text('既存テーブル行'), findsOneWidget);
    expect(
      find.text('※ サブページは最大100件まで表示しています。未表示のページがあります。'),
      findsOneWidget,
    );
    expect(
      find.text('※ テーブル行は最大100件まで表示しています。未表示の行があります。'),
      findsOneWidget,
    );

    await tester.tap(find.text('行を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新規テーブル行');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    expect(find.text('新規テーブル行'), findsOneWidget);

    await tester.tap(find.text('子ページ1'));
    await tester.pumpAndSettle();
    expect(find.text('子ページ詳細'), findsOneWidget);
    expect(find.text('子ページ本文'), findsOneWidget);
  });

  testWidgets('detail failure recovers on retry at 320px with large text',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var getAttempts = 0;
      final repository = WikiRepository((body) async {
        if (body['action'] == 'wiki.list') {
          return {
            'success': true,
            'pages': [
              {
                'id': 'page-1',
                'metadata': {'title': 'ナロー画面ページ'},
              },
            ],
            'next_offset': null,
          };
        }
        if (++getAttempts == 1) throw StateError('offline');
        return {
          'success': true,
          'page': {
            'id': 'page-1',
            'metadata': {'title': 'ナロー画面ページ', 'content': '復旧後の本文'},
          },
          'children': <dynamic>[],
          'table_rows': <dynamic>[],
        };
      });

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WikiDatabasePage(
            wikiRepository: repository,
            isAuthenticatedOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ナロー画面ページ'));
      await tester.pumpAndSettle();
      expect(
        find.text('ページ詳細を取得できませんでした。ページを選び直してください。'),
        findsOneWidget,
      );

      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();
      expect(find.text('復旧後の本文'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
