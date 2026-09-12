import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/note_version_history_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '11111111-1111-4111-8111-111111111111';
String versionId(int number) =>
    '22222222-2222-4222-8222-${number.toString().padLeft(12, '0')}';
Map<String, dynamic> row(int number, {String source = 'native'}) => {
      'id': versionId(number),
      'title': 'History $number',
      'saved_at': '2026-09-12T00:00:00.123456+00:00',
      'source_system': source,
      'source_verified_at': null,
    };

class _Auth extends Fake implements GoTrueClient {
  String? ownerId = owner;
  @override
  User? get currentUser => ownerId == null
      ? null
      : User(
          id: ownerId!,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01',
        );
}

class _Client extends Fake implements SupabaseClient {
  _Client(this.delegate);
  final SupabaseClient delegate;
  @override
  final _Auth auth = _Auth();
  @override
  SupabaseQueryBuilder from(String table) => delegate.from(table);
}

void main() {
  late SupabaseClient delegate;
  late _Client client;
  late SupabaseNoteVersionHistoryRepository repository;
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) response;

  setUp(() {
    requests.clear();
    response = (_) async => http.Response('[]', 200);
    delegate = SupabaseClient(
      'https://example.invalid',
      'synthetic-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        final result = await response(request);
        return http.Response.bytes(
          result.bodyBytes,
          result.statusCode,
          headers: result.headers,
          request: request,
        );
      }),
    );
    client = _Client(delegate);
    repository = SupabaseNoteVersionHistoryRepository(client);
  });
  tearDown(() async => delegate.dispose());

  test('page loads metadata only, with owner/note and stable ordering',
      () async {
    response =
        (_) async => http.Response(jsonEncode(List.generate(31, row)), 200);
    final page = await repository.loadPage('42');
    expect(page.items, hasLength(30));
    expect(page.hasMore, isTrue);
    final query = requests.single.url.queryParameters;
    expect(query['user_id'], 'eq.$owner');
    expect(query['note_id'], 'eq.42');
    expect(
      query['select'],
      SupabaseNoteVersionHistoryRepository.summaryColumns,
    );
    expect(query['select'], isNot(contains('content')));
    expect(query['order'], contains('saved_at.desc.nullslast'));
    expect(query['order'], contains('id.desc'));
    expect(query['limit'], '31');
    expect(requests.single.method, 'GET');
  });

  test('keyset preserves raw microseconds, tie breaker and nullable dates',
      () async {
    final cursor = NoteVersionSummary.fromJson(row(8)).cursor;
    await repository.loadPage('42', before: cursor);
    final filter = requests.single.url.queryParameters['or']!;
    expect(filter, contains('saved_at.lt.2026-09-12T00:00:00.123456+00:00'));
    expect(filter, contains('id.lt.${versionId(8)}'));
    expect(filter, contains('saved_at.is.null'));
    expect(requests.single.url.queryParameters, isNot(contains('offset')));
  });

  test('null-date cursor only requests older null-date ids', () async {
    final cursor = NoteVersionCursor(id: versionId(7), savedAt: null);
    await repository.loadPage('42', before: cursor);
    expect(
      requests.single.url.queryParameters['or'],
      '(and(saved_at.is.null,id.lt.${versionId(7)}))',
    );
  });

  test('cursor rejects raw filter injection before any request', () {
    expect(
      () => NoteVersionCursor(id: 'x),id.gt.0', savedAt: null),
      throwsFormatException,
    );
    expect(
      () => NoteVersionCursor(id: versionId(1), savedAt: 'x),id.gt.0'),
      throwsFormatException,
    );
    expect(requests, isEmpty);
  });

  test('empty final page is reported without another page', () async {
    final page = await repository.loadPage('42');
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
  });

  test('signed-out requests fail before accessing history', () async {
    client.auth.ownerId = null;
    await expectLater(repository.loadPage('42'), throwsStateError);
    await expectLater(
      repository.loadDetail('42', versionId(1)),
      throwsStateError,
    );
    expect(requests, isEmpty);
  });

  test('session changes discard in-flight private results', () async {
    response = (_) async {
      client.auth.ownerId = 'other-owner';
      return http.Response(jsonEncode([row(1)]), 200);
    };
    await expectLater(repository.loadPage('42'), throwsStateError);
  });

  test('native body is lazy and no attachment request is made', () async {
    response = (_) async =>
        http.Response(jsonEncode({...row(1), 'content': '**old body**'}), 200);
    final detail = await repository.loadDetail('42', versionId(1));
    expect(detail.content, '**old body**');
    expect(detail.attachments, isEmpty);
    expect(requests, hasLength(1));
    expect(requests.single.url.queryParameters['id'], 'eq.${versionId(1)}');
  });

  test('Evernote attachment metadata is paged beyond the API default',
      () async {
    response = (request) async {
      if (request.url.path.endsWith('/note_versions')) {
        return http.Response(
          jsonEncode({
            ...row(1, source: 'evernote'),
            'content': '![image](attachment:private-reference)',
            'source_tags': ['source-tag'],
          }),
          200,
        );
      }
      final after = int.parse(
        (request.url.queryParameters['id'] ?? 'gt.0').substring(3),
      );
      final remaining = 1001 - after;
      final count = remaining > 100 ? 100 : remaining;
      return http.Response(
        jsonEncode(
          List.generate(
            count,
            (index) => {
              'id': after + index + 1,
              'file_name': 'synthetic.png',
              'mime_type': 'image/png',
              'file_size': 10,
            },
          ),
        ),
        200,
      );
    };
    final detail = await repository.loadDetail('42', versionId(1));
    expect(detail.attachments, hasLength(1001));
    expect(detail.tags, ['source-tag']);
    expect(requests, hasLength(12));
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.url.queryParameters['user_id'], 'eq.$owner');
      expect(request.url.queryParameters['note_id'], 'eq.42');
    }
    for (final request in requests.skip(1)) {
      expect(
        request.url.queryParameters['note_version_id'],
        'eq.${versionId(1)}',
      );
      expect(
        request.url.queryParameters['select'],
        isNot(contains('file_path')),
      );
    }
  });

  test('attachment failure is not misrepresented as a complete preview',
      () async {
    response = (request) async => request.url.path.endsWith('/note_versions')
        ? http.Response(
            jsonEncode({...row(1, source: 'evernote'), 'content': 'body'}),
            200,
          )
        : http.Response('{"message":"synthetic failure","code":"42501"}', 403);
    await expectLater(
      repository.loadDetail('42', versionId(1)),
      throwsA(isA<PostgrestException>()),
    );
  });
}
