import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';
import 'package:my_web_app/services/import_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
        'updated_at.desc.nullslast',
      );
      expect(captured.headers['authorization'], 'Bearer user-a-jwt');
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

String _hash(String character) =>
    List<String>.filled(64, character, growable: false).join();
