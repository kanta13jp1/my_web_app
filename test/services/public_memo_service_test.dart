import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/models/public_memo.dart';
import 'package:my_web_app/services/public_memo_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('PublicMemoService URL builders', () {
    test('buildPublicMemoAppUrl returns the app detail route', () {
      final url = PublicMemoService.buildPublicMemoAppUrl(42);

      expect(
        url,
        'https://my-web-app-b67f4.web.app/public-memo?id=42&utm_source=public_memo&utm_medium=share&utm_campaign=growth_mission',
      );
    });

    test('buildPublicMemoUrl returns the app detail route', () {
      final url = PublicMemoService.buildPublicMemoUrl(42);

      expect(url, PublicMemoService.buildPublicMemoAppUrl(42));
    });

    test(
      'buildPublicMemoReaderUrl returns the bot-readable core-hub route',
      () {
        final url = PublicMemoService.buildPublicMemoReaderUrl(
          44,
          supabaseUrl: 'https://example.supabase.co',
        );

        expect(
          url,
          'https://example.supabase.co/functions/v1/core-hub'
          '?action=memo.public.view&id=44',
        );
      },
    );

    test('buildPublicMemoReaderUrl appends the requested format', () {
      final url = PublicMemoService.buildPublicMemoReaderUrl(
        44,
        format: 'json',
        supabaseUrl: 'https://example.supabase.co',
      );

      expect(
        url,
        'https://example.supabase.co/functions/v1/core-hub'
        '?action=memo.public.view&id=44&format=json',
      );
    });
  });

  group('PublicMemoService reaction contract', () {
    test('load request uses only memo.react.list', () {
      expect(PublicMemoService.buildLoadReactionsRequest(42), {
        'action': 'memo.react.list',
        'memo_id': 42,
      });
    });

    test('toggle request uses only memo.react.toggle', () {
      expect(
        PublicMemoService.buildToggleReactionRequest(
          memoId: 42,
          reaction: '👍',
        ),
        {'action': 'memo.react.toggle', 'memo_id': 42, 'reaction': '👍'},
      );
    });
  });

  group('PublicMemoService generated memo ownership', () {
    test('upserts an owner-backed note before the public memo', () async {
      final requests = <http.Request>[];
      final service = _service((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/notes')) {
          return _jsonResponse(request, <String, dynamic>{'id': 321});
        }
        return _jsonResponse(request, _memoRow(noteId: 321));
      });

      final memo = await service.upsertGeneratedMemo(
        sourceKey: ' local-election:90000007002027 ',
        userId: 'user-a',
        title: '統一地方選700 県連KPI一覧',
        content: '公開本文',
        category: '選挙ダッシュボード',
        metadata: const <String, dynamic>{
          'type': 'local_election_plan_dashboard',
        },
      );

      expect(memo?.noteId, 321);
      expect(requests, hasLength(2));
      final noteRequest = requests[0];
      expect(noteRequest.method, 'POST');
      expect(noteRequest.url.path, endsWith('/rest/v1/notes'));
      expect(
        noteRequest.url.queryParameters['on_conflict'],
        'user_id,source_key',
      );
      final noteBody = jsonDecode(noteRequest.body) as Map<String, dynamic>;
      expect(noteBody['user_id'], 'user-a');
      expect(noteBody['source_key'], 'local-election:90000007002027');
      expect(noteBody['capture_source'], 'public_memo_generated');

      final memoRequest = requests[1];
      expect(memoRequest.method, 'POST');
      expect(memoRequest.url.path, endsWith('/rest/v1/public_memos'));
      expect(
        memoRequest.url.queryParameters['on_conflict'],
        'note_id,user_id',
      );
      final memoBody = jsonDecode(memoRequest.body) as Map<String, dynamic>;
      expect(memoBody['note_id'], 321);
      expect(
        (memoBody['metadata'] as Map<String, dynamic>)['source_key'],
        'local-election:90000007002027',
      );
    });

    test('resolves a generated memo through its owner-scoped key', () async {
      final requests = <http.Request>[];
      final service = _service((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/notes')) {
          return _jsonResponse(request, <String, dynamic>{'id': 321});
        }
        return _jsonResponse(request, _memoRow(noteId: 321));
      });

      final memo = await service.getUserGeneratedPublicMemoBySourceKey(
        sourceKey: 'local-election:90000007002027',
        userId: 'user-a',
      );

      expect(memo?.id, 7);
      expect(requests, hasLength(2));
      expect(requests[0].method, 'GET');
      expect(requests[0].url.queryParameters['user_id'], 'eq.user-a');
      expect(
        requests[0].url.queryParameters['source_key'],
        'eq.local-election:90000007002027',
      );
      expect(requests[1].url.queryParameters['note_id'], 'eq.321');
      expect(requests[1].url.queryParameters['user_id'], 'eq.user-a');
    });

    test(
      'getLatestPreviousGeneratedPublicMemo queries public memos and selects strictly earlier snapshot',
      () async {
        final requests = <http.Request>[];
        final service = _service((request) async {
          requests.add(request);
          return _jsonResponse(request, <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 67,
              'note_id': 2730,
              'user_id': 'user-a',
              'title': '国民民主党 地方議員集計 2026/11/24',
              'content': '現職地方議員名簿',
              'category': '選挙ダッシュボード',
              'metadata': const <String, dynamic>{
                'type': 'local_election_snapshot',
                'source_key': 'local-election:90000020261124',
                'snapshotDate': '2026/11/24',
              },
              'like_count': 0,
              'view_count': 0,
              'is_public': true,
              'published_at': '2026-11-23T20:28:43Z',
              'created_at': '2026-11-23T20:28:43Z',
              'updated_at': '2026-11-24T08:01:46Z',
            },
            <String, dynamic>{
              'id': 65,
              'note_id': 564,
              'user_id': 'user-a',
              'title': '国民民主党 地方議員集計 2026/10/11',
              'content': '現職地方議員名簿',
              'category': '選挙ダッシュボード',
              'metadata': const <String, dynamic>{
                'type': 'local_election_snapshot',
                'source_key': 'local-election:90000020261011',
                'snapshotDate': '2026/10/11',
              },
              'like_count': 0,
              'view_count': 0,
              'is_public': true,
              'published_at': '2026-10-10T16:52:51Z',
              'created_at': '2026-10-10T16:52:51Z',
              'updated_at': '2026-11-14T06:53:56Z',
            },
            <String, dynamic>{
              'id': 66,
              'note_id': 567,
              'user_id': 'user-a',
              'title': '国民民主党 地方議員集計 2026/11/17',
              'content': '現職地方議員名簿',
              'category': '選挙ダッシュボード',
              'metadata': const <String, dynamic>{
                'type': 'local_election_snapshot',
                'source_key': 'local-election:90000020261117',
                'snapshotDate': '2026/11/17',
              },
              'like_count': 0,
              'view_count': 0,
              'is_public': true,
              'published_at': '2026-11-16T20:11:54Z',
              'created_at': '2026-11-16T20:11:54Z',
              'updated_at': '2026-11-16T20:11:55Z',
            },
          ]);
        });

        final memo = await service.getLatestPreviousGeneratedPublicMemo(
          userId: 'user-a',
          metadataType: 'local_election_snapshot',
          excludeSourceKey: 'local-election:90000020261124',
          beforeSnapshotDate: '2026/11/24',
          category: '選挙ダッシュボード',
        );

        expect(memo?.id, 66);
        expect(requests, hasLength(1));
        expect(requests.first.method, 'GET');
        expect(requests.first.url.path, endsWith('/rest/v1/public_memos'));
        expect(requests.first.url.queryParameters['user_id'], 'eq.user-a');
        expect(requests.first.url.queryParameters['is_public'], 'eq.true');
        expect(
          requests.first.url.queryParameters['category'],
          'eq.選挙ダッシュボード',
        );
      },
    );
  });

  group('PublicMemoService template cloning', () {
    test(
      'clonePublicMemoToNote inserts note with created_by and template_clone',
      () async {
        final requests = <http.Request>[];
        final service = _service((request) async {
          requests.add(request);
          return _jsonResponse(request, <String, dynamic>{'id': 901});
        });

        final memo = PublicMemo(
          id: 7,
          noteId: 321,
          userId: 'author-1',
          title: '家計管理テンプレート',
          content: '# テンプレート本文',
          likeCount: 3,
          viewCount: 15,
          isPublic: true,
          publishedAt: DateTime.utc(2026, 11, 20),
          createdAt: DateTime.utc(2026, 11, 20),
          updatedAt: DateTime.utc(2026, 11, 20),
        );

        final clonedId = await service.clonePublicMemoToNote(
          memo: memo,
          userId: 'user-a',
        );

        expect(clonedId, 901);
        expect(requests, hasLength(1));
        expect(requests.first.method, 'POST');
        expect(requests.first.url.path, endsWith('/rest/v1/notes'));
        final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
        expect(body['user_id'], 'user-a');
        expect(body['created_by'], 'user-a');
        expect(body['title'], '家計管理テンプレート');
        expect(body['content'], '# テンプレート本文');
        expect(body['capture_source'], 'template_clone');
        expect(body['tags'], <String>['template-clone']);
      },
    );

    test('recordShareSignal accepts publicMemoCloneSignal', () async {
      final requests = <http.Request>[];
      final service = _service((request) async {
        requests.add(request);
        return _jsonResponse(request, <String, dynamic>{'success': true});
      });

      await service.recordShareSignal(
        memoId: 7,
        signalKey: PublicMemoService.publicMemoCloneSignal,
        now: DateTime(2026, 11, 27),
      );

      expect(requests, hasLength(1));
      final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
      expect(body['signalKey'], PublicMemoService.publicMemoCloneSignal);
      expect(body['contextId'], 7);
    });
  });
}

PublicMemoService _service(
  Future<http.Response> Function(http.Request request) handler,
) {
  return PublicMemoService(
    SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      accessToken: () async => 'user-a-jwt',
      httpClient: MockClient(handler),
    ),
  );
}

http.Response _jsonResponse(http.Request request, Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: const <String, String>{'content-type': 'application/json'},
    request: request,
  );
}

Map<String, dynamic> _memoRow({required int noteId}) {
  return <String, dynamic>{
    'id': 7,
    'note_id': noteId,
    'user_id': 'user-a',
    'title': '統一地方選700 県連KPI一覧',
    'content': '公開本文',
    'category': '選挙ダッシュボード',
    'metadata': const <String, dynamic>{
      'type': 'local_election_plan_dashboard',
      'source_key': 'local-election:90000007002027',
    },
    'like_count': 0,
    'view_count': 0,
    'is_public': true,
    'published_at': '2026-08-30T00:00:00Z',
    'created_at': '2026-08-30T00:00:00Z',
    'updated_at': '2026-08-30T00:00:00Z',
  };
}
