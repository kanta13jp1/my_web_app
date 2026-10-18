import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';
import 'package:my_web_app/services/import_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final items in <bool>[false, true]) {
    test('loads all owner ledger pages, items=$items', () async {
      final cursors = <int>[];
      final service = _service((request) async {
        expect(request.url.queryParameters['user_id'], 'eq.user-a');
        expect(request.url.queryParameters['order'], 'id.asc.nullslast');
        final cursor = int.parse(
          (request.url.queryParameters['id'] ?? 'gt.0').substring(3),
        );
        cursors.add(cursor);
        final rows = List<Map<String, dynamic>>.generate(205, (index) {
          return <String, dynamic>{
            ...(items ? _itemJson() : _batchJson()),
            'id': index + 1,
          };
        }).where((row) => (row['id'] as int) > cursor).take(50).toList();
        return http.Response(
          jsonEncode(rows),
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      });
      final ids = items
          ? (await service.loadItems(userId: 'user-a')).map((row) => row.id)
          : (await service.loadBatches(userId: 'user-a')).map((row) => row.id);
      expect(ids.toSet(), hasLength(205));
      expect(ids.first, 205);
      expect(cursors, <int>[0, 50, 100, 150, 200, 205]);
    });
  }
  test('retry after a partial manifest write reuses keys and preserves status',
      () async {
    var itemCalls = 0;
    final payloads = <List<Map<String, dynamic>>>[];
    final service = _service((request) async {
      if (request.url.path.endsWith('/evernote_migration_batches')) {
        return http.Response(
          jsonEncode(_batchJson()),
          201,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      }
      itemCalls += 1;
      payloads.add(
        (jsonDecode(request.body) as List<dynamic>)
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList(),
      );
      return http.Response(
        itemCalls == 2 ? '{"message":"synthetic transient failure"}' : '',
        itemCalls == 2 ? 500 : 201,
        headers: const {'content-type': 'application/json'},
        request: request,
      );
    });
    final preview = ImportPreviewResult(
      sourceType: 'evernote',
      sourceLabel: 'Evernote',
      fileName: 'retry.enex',
      sourceExportSha256: _hash('a'),
      notes: List<ImportedNoteDraft>.generate(101, (index) {
        return ImportedNoteDraft(
          title: 'Synthetic note',
          content: 'Synthetic body',
          source: 'evernote',
          sourceId: 'note-$index',
          sourceContentSha256: _hash('b'),
        );
      }),
    );
    await expectLater(
      service.recordPreview(userId: 'user-a', preview: preview),
      throwsA(isA<PostgrestException>()),
    );
    await service.recordPreview(userId: 'user-a', preview: preview);
    expect(payloads.map((rows) => rows.length).toList(), <int>[100, 1, 100, 1]);
    for (var page = 0; page < 2; page += 1) {
      expect(
        payloads[page].map((row) => row['source_item_key']).toList(),
        payloads[page + 2].map((row) => row['source_item_key']).toList(),
      );
    }
    for (final row in payloads.expand((rows) => rows)) {
      expect(row.containsKey('status'), isFalse);
      expect(row.containsKey('history_status'), isFalse);
      expect(row.containsKey('task_status'), isFalse);
      expect(row.containsKey('target_note_id'), isFalse);
    }
  });
  group('EvernoteMigrationProgress', () {
    test('reports transparent four-stage progress', () {
      final progress =
          EvernoteMigrationProgress.fromBatches(<EvernoteMigrationBatch>[
        _batch(
          sourceNoteCount: 10,
          importedNoteCount: 8,
          verifiedNoteCount: 4,
          sourceDeletedNoteCount: 2,
        ),
      ]);

      expect(progress.batchCount, 1);
      expect(progress.sourceNoteCount, 10);
      expect(progress.overallPercent, 60);
    });

    test('does not claim progress before an export is previewed', () {
      final progress = EvernoteMigrationProgress.fromBatches(
        const <EvernoteMigrationBatch>[],
      );

      expect(progress.overallFraction, 0);
      expect(progress.overallPercent, 0);
    });
  });

  group('EvernoteMigrationLedgerService PostgREST integration', () {
    test('records a batch and hash-only item manifests without note bodies',
        () async {
      final requests = <http.Request>[];
      final service = _service((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/evernote_migration_batches')) {
          return http.Response(
            jsonEncode(_batchJson()),
            201,
            headers: const {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('', 201, request: request);
      });

      final preview = ImportPreviewResult(
        sourceType: 'evernote',
        sourceLabel: 'Evernote',
        fileName: 'batch-001.enex',
        sourceExportSha256: _hash('a'),
        resourceCount: 3,
        notes: <ImportedNoteDraft>[
          ImportedNoteDraft(
            title: 'Sensitive title must not enter the ledger',
            content: 'Sensitive body must not enter the ledger',
            source: 'evernote',
            sourceId: 'note-guid-1',
            sourceContentSha256: _hash('b'),
            sourceResourceCount: 3,
          ),
        ],
      );

      final batch = await service.recordPreview(
        userId: ' user-a ',
        preview: preview,
      );

      expect(batch.id, 7);
      expect(requests, hasLength(2));
      final batchPayload = jsonDecode(requests[0].body) as Map<String, dynamic>;
      expect(batchPayload['user_id'], 'user-a');
      expect(batchPayload['source_note_count'], 1);
      expect(
        requests[0].url.queryParameters['on_conflict'],
        'user_id,source_export_sha256',
      );

      final itemPayload = jsonDecode(requests[1].body) as List<dynamic>;
      final item = Map<String, dynamic>.from(itemPayload.single as Map);
      expect(item['source_item_key'], 'id:note-guid-1');
      expect(item['source_content_sha256'], _hash('b'));
      expect(item.containsKey('title'), isFalse);
      expect(item.containsKey('content'), isFalse);
    });

    test('loads only the requested owner ledger in newest-first order',
        () async {
      late http.Request captured;
      final service = _service((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[_batchJson()]),
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      });

      final batches = await service.loadBatches(userId: ' user-a ');

      expect(batches.single.id, 7);
      expect(captured.method, 'GET');
      expect(captured.url.queryParameters['user_id'], 'eq.user-a');
      expect(
        captured.url.queryParameters['order'],
        'id.asc.nullslast',
      );
      expect(captured.headers['authorization'], 'Bearer user-a-jwt');
    });

    test('loads owner-scoped note-history inventory and target titles',
        () async {
      late http.Request captured;
      final service = _service((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[_itemJson()]),
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      });

      final items = await service.loadItems(userId: ' user-a ');

      expect(items, hasLength(1));
      expect(items.single.id, 19);
      expect(items.single.batchId, 7);
      expect(items.single.displayTitle, 'Imported note');
      expect(items.single.sourceHistoryVersionCount, 3);
      expect(items.single.verifiedHistoryVersionCount, 2);
      expect(items.single.historyDeletionGatePassed, isFalse);
      expect(captured.url.queryParameters['user_id'], 'eq.user-a');
      expect(
        captured.url.queryParameters['select'],
        contains('evernote_migration_items_target_note_fkey'),
      );
    });
  });
}

EvernoteMigrationLedgerService _service(
  Future<http.Response> Function(http.Request request) handler,
) {
  return EvernoteMigrationLedgerService(
    client: SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      accessToken: () async => 'user-a-jwt',
      httpClient: MockClient(handler),
    ),
  );
}

EvernoteMigrationBatch _batch({
  int sourceNoteCount = 0,
  int importedNoteCount = 0,
  int verifiedNoteCount = 0,
  int sourceDeletedNoteCount = 0,
}) {
  return EvernoteMigrationBatch(
    id: 7,
    userId: 'user-a',
    sourceExportSha256: _hash('a'),
    sourceFileName: 'batch-001.enex',
    status: 'previewed',
    sourceNoteCount: sourceNoteCount,
    sourceResourceCount: 3,
    importedNoteCount: importedNoteCount,
    verifiedNoteCount: verifiedNoteCount,
    sourceDeletedNoteCount: sourceDeletedNoteCount,
    createdAt: DateTime.utc(2026, 8, 23),
    updatedAt: DateTime.utc(2026, 8, 23),
  );
}

Map<String, dynamic> _batchJson() {
  return <String, dynamic>{
    'id': 7,
    'user_id': 'user-a',
    'source_export_sha256': _hash('a'),
    'source_file_name': 'batch-001.enex',
    'status': 'previewed',
    'source_note_count': 1,
    'source_resource_count': 3,
    'imported_note_count': 0,
    'verified_note_count': 0,
    'source_deleted_note_count': 0,
    'created_at': '2026-08-23T00:00:00Z',
    'updated_at': '2026-08-23T00:00:00Z',
  };
}

Map<String, dynamic> _itemJson() {
  return <String, dynamic>{
    'id': 19,
    'batch_id': 7,
    'source_item_key': 'id:note-guid-1',
    'source_note_id': 'note-guid-1',
    'target_note_id': 7001,
    'status': 'verified',
    'history_status': 'importing',
    'source_history_version_count': 3,
    'imported_history_version_count': 2,
    'verified_history_version_count': 2,
    'notes': <String, dynamic>{'title': 'Imported note'},
  };
}

String _hash(String character) =>
    List<String>.filled(64, character, growable: false).join();
