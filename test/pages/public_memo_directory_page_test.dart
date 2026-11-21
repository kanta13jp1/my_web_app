import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/public_memo_directory_page.dart';
import 'package:my_web_app/services/public_memo_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

late Future<http.Response> Function(http.Request request) _handler;
late SupabaseClient _client;

void main() {
  setUpAll(() {
    // Keep isolate initialization outside the widget test's fake async zone.
    _client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) => _handler(request)),
    );
  });

  tearDownAll(() => _client.dispose());

  testWidgets(
    'shows retry error state on HTTP 500 and reloads memos on retry',
    (tester) async {
      var shouldFail = true;
      final service = _createService((request) async {
        if (request.url.path == '/rest/v1/public_memos') {
          if (shouldFail) {
            return _errorResponse(request, 500);
          }
          if (request.url.queryParameters['select'] == 'category') {
            return _jsonResponse(request, const <Map<String, dynamic>>[]);
          }
          return _jsonResponse(request, <Map<String, dynamic>>[_memoRow()]);
        }
        return _jsonResponse(request, const <Map<String, dynamic>>[]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemoDirectoryPage(publicMemoService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public_memos_error_state')),
        findsOneWidget,
      );
      expect(
        find.textContaining('公開メモの読み込みに失敗しました'),
        findsOneWidget,
      );
      expect(find.textContaining('公開メモはまだありません'), findsNothing);
      expect(find.text('再試行'), findsOneWidget);

      shouldFail = false;
      await tester.ensureVisible(find.text('再試行'));
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('public_memos_error_state')), findsNothing);
      expect(find.text('テスト公開メモ'), findsOneWidget);
    },
  );

  testWidgets(
    'shows filtered empty state on empty search and resets filters',
    (tester) async {
      final service = _createService((request) async {
        if (request.url.path == '/rest/v1/public_memos') {
          if (request.url.queryParameters['select'] == 'category') {
            return _jsonResponse(request, const <Map<String, dynamic>>[]);
          }
          final orFilter = request.url.queryParameters['or'];
          if (orFilter != null && orFilter.isNotEmpty) {
            return _jsonResponse(request, const <Map<String, dynamic>>[]);
          }
          return _jsonResponse(request, <Map<String, dynamic>>[_memoRow()]);
        }
        return _jsonResponse(request, const <Map<String, dynamic>>[]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemoDirectoryPage(publicMemoService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('テスト公開メモ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '該当なし');
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public_memos_filtered_empty_state')),
        findsOneWidget,
      );
      expect(
        find.text('条件に一致する公開メモが見つかりませんでした。'),
        findsOneWidget,
      );
      expect(find.text('絞り込みをリセット'), findsOneWidget);
      expect(find.textContaining('公開メモはまだありません'), findsNothing);

      await tester.ensureVisible(find.text('絞り込みをリセット'));
      await tester.tap(find.text('絞り込みをリセット'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
      expect(
        find.byKey(const Key('public_memos_filtered_empty_state')),
        findsNothing,
      );
      expect(find.text('テスト公開メモ'), findsOneWidget);
    },
  );

  testWidgets(
    'shows default empty state when unfiltered memos are empty',
    (tester) async {
      final service = _createService((request) async {
        return _jsonResponse(request, const <Map<String, dynamic>>[]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemoDirectoryPage(publicMemoService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('公開メモはまだありません。まずはメモ一覧から 1 件公開してみてください。'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('public_memos_error_state')), findsNothing);
      expect(
        find.byKey(const Key('public_memos_filtered_empty_state')),
        findsNothing,
      );
    },
  );

  test(
    'getPublicMemos returns empty on throwOnError=false and throws when true',
    () async {
      final service = _createService((request) async {
        return _errorResponse(request, 500);
      });

      final fallback = await service.getPublicMemos(throwOnError: false);
      expect(fallback, isEmpty);

      await expectLater(
        service.getPublicMemos(throwOnError: true),
        throwsException,
      );
    },
  );

  test(
    'getPublicMemos escapes PostgREST filter delimiters in searchQuery',
    () async {
      final requests = <http.Request>[];
      final service = _createService((request) async {
        requests.add(request);
        return _jsonResponse(request, const <Map<String, dynamic>>[]);
      });

      await service.getPublicMemos(searchQuery: 'foo,(bar)');
      await service.getPublicMemos(searchQuery: ' ,() ');

      expect(requests, hasLength(2));
      expect(
        requests[0].url.queryParameters['or'],
        '(title.ilike.%foo  bar%,'
        'content.ilike.%foo  bar%,'
        'category.ilike.%foo  bar%)',
      );
      expect(requests[1].url.queryParameters.containsKey('or'), isFalse);
    },
  );

  testWidgets(
    'ignores stale reload completion when a newer reload finishes first',
    (tester) async {
      var listCalls = 0;
      final staleGate = Completer<void>();
      final service = _createService((request) async {
        if (request.url.path == '/rest/v1/public_memos') {
          if (request.url.queryParameters['select'] == 'category') {
            return _jsonResponse(request, const <Map<String, dynamic>>[]);
          }
          listCalls += 1;
          if (listCalls == 1) {
            await staleGate.future;
            return _jsonResponse(
              request,
              <Map<String, dynamic>>[_memoRow(title: '古い応答')],
            );
          }
          return _jsonResponse(
            request,
            <Map<String, dynamic>>[_memoRow(title: '新しい応答')],
          );
        }
        return _jsonResponse(request, const <Map<String, dynamic>>[]);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PublicMemoDirectoryPage(publicMemoService: service),
        ),
      );
      await tester.pump();
      expect(listCalls, 1);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('新しい応答'), findsOneWidget);

      staleGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('新しい応答'), findsOneWidget);
      expect(find.text('古い応答'), findsNothing);
    },
  );
}

PublicMemoService _createService(
  Future<http.Response> Function(http.Request request) handler,
) {
  _handler = handler;
  return PublicMemoService(_client);
}

http.Response _jsonResponse(http.Request request, Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
    request: request,
  );
}

http.Response _errorResponse(http.Request request, int statusCode) {
  return http.Response(
    jsonEncode(const <String, String>{'message': 'server error'}),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
    request: request,
  );
}

Map<String, dynamic> _memoRow({String title = 'テスト公開メモ'}) {
  return <String, dynamic>{
    'id': 1,
    'note_id': 101,
    'user_id': 'user-1',
    'title': title,
    'content': '公開メモの本文',
    'category': '開発',
    'metadata': const <String, dynamic>{},
    'like_count': 3,
    'view_count': 10,
    'is_public': true,
    'published_at': '2026-11-21T00:00:00Z',
    'created_at': '2026-11-21T00:00:00Z',
    'updated_at': '2026-11-21T00:00:00Z',
  };
}
