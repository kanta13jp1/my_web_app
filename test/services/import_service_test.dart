import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/direct_storage_upload_service.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:my_web_app/services/import_service.dart';
import 'package:my_web_app/services/storage_quota_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Uint8List _zipBytes(
  final Map<String, String> textFiles, {
  final Map<String, List<int>> binaryFiles = const <String, List<int>>{},
}) {
  final archive = Archive();
  textFiles.forEach((final name, final content) {
    archive.addFile(ArchiveFile.string(name, content));
  });
  binaryFiles.forEach((final name, final bytes) {
    archive.addFile(ArchiveFile.bytes(name, bytes));
  });
  return ZipEncoder().encodeBytes(archive);
}

class _StubQuotaRepo implements StorageQuotaRepository {
  _StubQuotaRepo(this.status);

  final StorageQuotaStatus status;

  @override
  Future<StorageQuotaStatus> loadStatus({required final String userId}) async {
    return status;
  }
}

class _RecordingUploadGateway implements DirectStorageUploadGateway {
  final List<String> paths = <String>[];

  @override
  Future<void> uploadBinary({
    required final String bucketId,
    required final String storagePath,
    required final Uint8List bytes,
    required final String contentType,
    required final bool upsert,
  }) async {
    paths.add('$bucketId/$storagePath');
  }
}

class _RecordingMetadataStore implements DirectUploadMetadataStore {
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> insert({
    required final String tableName,
    required final Map<String, dynamic> values,
  }) async {
    rows.add(values);
    return <String, dynamic>{'id': rows.length, ...values};
  }
}

void main() {
  late ImportService service;

  setUp(() {
    service = ImportService(GamificationService());
  });

  group('ImportService', () {
    test('parseNotionCsvText reads title content and tags', () {
      const csv = 'Title,Content,Tags\n'
          '"Reading memo","Imported from Notion","books,import"\n';

      final drafts = service.parseNotionCsvText(csv);

      expect(drafts, hasLength(1));
      expect(drafts.first.title, 'Reading memo');
      expect(drafts.first.content, 'Imported from Notion');
      expect(drafts.first.tags, <String>['books', 'import']);
      expect(drafts.first.source, 'notion');
    });

    test('parseEvernoteEnexText preserves formatting and extracts tags', () {
      const enex = '''
<?xml version="1.0" encoding="UTF-8"?>
<en-export>
  <note>
    <title>Evernote memo</title>
    <content><![CDATA[
      <en-note>
        <div>First line</div>
        <div><b>Second line</b></div>
      </en-note>
    ]]></content>
    <tag>archive</tag>
    <tag>ideas</tag>
  </note>
</en-export>
''';

      final drafts = service.parseEvernoteEnexText(enex);

      expect(drafts, hasLength(1));
      expect(drafts.first.title, 'Evernote memo');
      expect(drafts.first.content, 'First line\n\n**Second line**');
      expect(drafts.first.tags, <String>['archive', 'ideas']);
      expect(drafts.first.source, 'evernote');
      expect(drafts.first.sourceId, hasLength(64));
      expect(drafts.first.sourceContentSha256, hasLength(64));
      expect(drafts.first.sourceMetadata['enml'], contains('<en-note>'));
      expect(
        drafts.first.sourceMetadata['enml'],
        contains('<b>Second line</b>'),
      );
    });

    test('Evernote preview enables only the lossless commit path', () async {
      const enex = '''
<en-export export-date="20260823T034500Z" application="Evernote" version="10">
  <note>
    <title>Safe preview</title>
    <content><![CDATA[<en-note><div>Body</div></en-note>]]></content>
    <resource>
      <data encoding="base64">aGVsbG8=</data>
      <mime>text/plain</mime>
      <resource-attributes><file-name>memo.txt</file-name></resource-attributes>
    </resource>
  </note>
</en-export>
''';

      final preview = await service.buildPreview(
        sourceType: 'evernote',
        fileName: 'batch-001.enex',
        bytes: Uint8List.fromList(utf8.encode(enex)),
      );

      expect(preview.usedEdgeFunction, isFalse);
      expect(preview.canCommit, isTrue);
      expect(preview.commitBlockedReason, isNull);
      expect(preview.sourceExportSha256, hasLength(64));
      expect(preview.resourceCount, 1);
      expect(preview.notes.single.sourceResourceCount, 1);
    });

    test('Evernote streaming preview matches the lossless preview metadata',
        () async {
      const enex = '''
<en-export export-date="20260823T034500Z" application="Evernote" version="10">
  <note>
    <title>Streaming preview</title>
    <content><![CDATA[<en-note><div>Body</div></en-note>]]></content>
    <resource>
      <data encoding="base64">aGVsbG8=</data>
      <mime>text/plain</mime>
    </resource>
  </note>
</en-export>
''';
      final bytes = Uint8List.fromList(utf8.encode(enex));

      final preview = await service.buildEvernoteStreamingPreview(
        fileName: 'batch-001.enex',
        source: Stream<List<int>>.fromIterable(
          bytes.map<List<int>>((byte) => <int>[byte]),
        ),
        totalBytes: bytes.length,
      );

      expect(preview.previewMode, 'local-streaming');
      expect(preview.previewModeLabel, 'Memory-bounded streaming preview');
      expect(preview.canCommit, isTrue);
      expect(preview.sourceExportSha256, hasLength(64));
      expect(preview.resourceCount, 1);
      expect(preview.notes.single.title, 'Streaming preview');
      expect(preview.notes.single.sourceResourceCount, 1);
      expect(preview.notes.single.sourceMetadata['streaming_preview'], isTrue);
      expect(preview.notes.single.sourceMetadata['preview_sample'], isTrue);
      expect(
        preview.notes.single.sourceMetadata.containsKey('enml'),
        isFalse,
      );
      expect(
        preview.notes.single.sourceMetadata.containsKey('raw_note_xml'),
        isFalse,
      );
      expect(
        preview.notes.single.sourceMetadata.containsKey('resources'),
        isFalse,
      );
    });

    test('Evernote streaming preview bounds retained note content', () async {
      final longBody = List<String>.filled(2500, '界').join();
      final notes = List<String>.generate(
        13,
        (index) => '''
  <note>
    <title>Note $index</title>
    <content><![CDATA[<en-note><div>${index == 0 ? longBody : 'Body $index'}</div></en-note>]]></content>
  </note>''',
      ).join();
      final enex = '<en-export>$notes</en-export>';
      final bytes = Uint8List.fromList(utf8.encode(enex));

      final preview = await service.buildEvernoteStreamingPreview(
        fileName: 'bounded.enex',
        source: Stream<List<int>>.value(bytes),
        totalBytes: bytes.length,
      );

      expect(preview.notes, hasLength(13));
      expect(preview.notes.first.content.runes.length, 2000);
      expect(
        preview.notes.first.sourceMetadata['preview_content_truncated'],
        isTrue,
      );
      expect(preview.notes[11].sourceMetadata['preview_sample'], isTrue);
      expect(preview.notes[12].content, isEmpty);
      expect(preview.notes[12].sourceMetadata['preview_sample'], isFalse);
    });

    test('Evernote drafts cannot enter the legacy commit path', () async {
      const draft = ImportedNoteDraft(
        title: 'Blocked',
        content: 'Body',
        source: 'evernote',
      );

      expect(
        () => service.importNotes(userId: 'user-1', notes: const [draft]),
        throwsA(isA<StateError>()),
      );
    });

    test('ImportPreviewResult.fromJson reads edge preview metadata', () {
      final preview = ImportPreviewResult.fromJson(<String, dynamic>{
        'sourceType': 'markdown',
        'sourceLabel': 'Markdown',
        'fileName': 'note.md',
        'previewMode': 'edge-function',
        'warnings': <String>['Edge preview active'],
        'notes': <Map<String, dynamic>>[
          <String, dynamic>{
            'title': 'Title',
            'content': 'Body',
            'source': 'markdown',
            'tags': <String>[],
          },
        ],
      });

      expect(preview.sourceType, 'markdown');
      expect(preview.usedEdgeFunction, isTrue);
      expect(preview.notes.single.title, 'Title');
      expect(preview.warnings.single, 'Edge preview active');
    });

    test('ImportExecutionResult.fromJson reads execution metadata', () {
      final result = ImportExecutionResult.fromJson(<String, dynamic>{
        'insertedCount': 24,
        'skippedDuplicateCount': 2,
        'uploadedAttachmentCount': 5,
        'importMode': 'edge-function',
      });

      expect(result.insertedCount, 24);
      expect(result.skippedDuplicateCount, 2);
      expect(result.uploadedAttachmentCount, 5);
      expect(result.usedEdgeFunction, isTrue);
      expect(result.importModeLabel, 'Edge Function import');
    });

    test(
      'buildPreview parses notion_zip and .zip files selected on notion card',
      () async {
        const pageId = '0123456789abcdef0123456789abcdef';
        final zip = _zipBytes(
          <String, String>{
            'Workspace $pageId/Guide $pageId.md':
                '# Migration Guide\n\n![](img.png)\n',
          },
          binaryFiles: <String, List<int>>{
            'Workspace $pageId/img.png': const <int>[1, 2, 3],
          },
        );

        final previewExplicit = await service.buildPreview(
          sourceType: 'notion_zip',
          fileName: 'export.zip',
          bytes: zip,
        );
        expect(previewExplicit.sourceType, 'notion_zip');
        expect(previewExplicit.previewMode, 'local-notion-zip');
        expect(previewExplicit.usedEdgeFunction, isFalse);
        expect(previewExplicit.notes, hasLength(1));
        expect(previewExplicit.resourceCount, 1);
        expect(previewExplicit.sourceExportSha256, hasLength(64));

        final previewAuto = await service.buildPreview(
          sourceType: 'notion',
          fileName: 'export.zip',
          bytes: zip,
        );
        expect(previewAuto.sourceType, 'notion_zip');
        expect(previewAuto.previewMode, 'local-notion-zip');
      },
    );

    test(
      'importNotes falls back locally when edge import.commit omits insertedCount',
      () async {
        final noteInserts = <List<dynamic>>[];
        final client = SupabaseClient(
          'http://localhost:9999',
          'synthetic-public-key',
          accessToken: () async => 'synthetic-token',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((final request) async {
            if (request.url.path.endsWith('/functions/v1/growth-hub')) {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'success': true,
                  'item': <String, dynamic>{'id': 99},
                }),
                200,
                headers: const <String, String>{
                  'content-type': 'application/json',
                },
                request: request,
              );
            }
            if (request.url.path.endsWith('/rest/v1/notes') &&
                request.method == 'POST') {
              final decoded = jsonDecode(request.body);
              if (decoded is List) {
                noteInserts.add(decoded);
              }
              return http.Response(
                '[]',
                201,
                headers: const <String, String>{
                  'content-type': 'application/json',
                },
                request: request,
              );
            }
            return http.Response(
              '[]',
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);

        final wiredService = ImportService(
          GamificationService(),
          clientOverride: client,
        );
        final result = await wiredService.importNotes(
          userId: 'user-123',
          notes: const <ImportedNoteDraft>[
            ImportedNoteDraft(
              title: 'Fallback Note',
              content: 'Saved locally after stub edge response',
              source: 'notion_page',
              tags: <String>['notion'],
            ),
          ],
        );

        expect(result.insertedCount, 1);
        expect(result.importMode, 'local-fallback');
        expect(noteInserts, hasLength(1));
        final firstInserted = Map<String, dynamic>.from(
          noteInserts.single.single as Map,
        );
        expect(firstInserted['user_id'], 'user-123');
        expect(firstInserted['created_by'], 'user-123');
        expect(firstInserted['capture_source'], 'notion_page');
        expect(firstInserted['tags'], const <String>['notion']);
      },
    );

    test(
      'importNotionZipBundle deduplicates source_key, creates collections, '
      'uploads attachments, and rewrites markdown links',
      () async {
        const folderId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1';
        const pageId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb2';
        final zip = _zipBytes(
          <String, String>{
            'Wiki $folderId/Design $pageId.md':
                '# Design Doc\n\nSee ![wireframe](wire%201.png)\n',
          },
          binaryFiles: <String, List<int>>{
            'Wiki $folderId/wire 1.png': const <int>[1, 2, 3, 4],
          },
        );
        final bundle = service.parseNotionZipBytes(
          fileName: 'notion-wiki.zip',
          bytes: zip,
        );

        var nextCollectionId = 10;
        final updatedNoteContents = <String>[];
        final client = SupabaseClient(
          'http://localhost:9999',
          'synthetic-public-key',
          accessToken: () async => 'synthetic-token',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((final request) async {
            if (request.url.path.endsWith('/rest/v1/note_collections')) {
              if (request.method == 'POST') {
                final createdId = nextCollectionId;
                nextCollectionId += 1;
                return http.Response(
                  jsonEncode(<String, dynamic>{'id': createdId}),
                  201,
                  headers: const <String, String>{
                    'content-type': 'application/json',
                  },
                  request: request,
                );
              }
              return http.Response(
                '[]',
                200,
                headers: const <String, String>{
                  'content-type': 'application/json',
                },
                request: request,
              );
            }
            if (request.url.path.endsWith('/rest/v1/notes')) {
              if (request.method == 'POST') {
                final decoded = jsonDecode(request.body) as List<dynamic>;
                final firstRow = Map<String, dynamic>.from(
                  decoded.first as Map,
                );
                return http.Response(
                  jsonEncode(<Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 501,
                      'source_key': firstRow['source_key'],
                    },
                  ]),
                  201,
                  headers: const <String, String>{
                    'content-type': 'application/json',
                  },
                  request: request,
                );
              }
              if (request.method == 'PATCH') {
                final payload = Map<String, dynamic>.from(
                  jsonDecode(request.body) as Map,
                );
                updatedNoteContents.add(payload['content']?.toString() ?? '');
                return http.Response(
                  '[]',
                  200,
                  headers: const <String, String>{
                    'content-type': 'application/json',
                  },
                  request: request,
                );
              }
              return http.Response(
                '[]',
                200,
                headers: const <String, String>{
                  'content-type': 'application/json',
                },
                request: request,
              );
            }
            return http.Response(
              '[]',
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);

        final uploadGateway = _RecordingUploadGateway();
        final metadataStore = _RecordingMetadataStore();
        final wiredService = ImportService(
          GamificationService(),
          clientOverride: client,
        );

        final result = await wiredService.importNotionZipBundle(
          userId: 'user-notion-1',
          bundle: bundle,
          quotaService: StorageQuotaService(
            repository: _StubQuotaRepo(
              const StorageQuotaStatus(
                planId: 'free',
                isAdmin: false,
                usedBytes: 0,
                quotaBytes: StorageQuotaPolicy.freeQuotaBytes,
                maxSingleFileBytes: StorageQuotaPolicy.freeSingleFileMaxBytes,
                attachmentCount: 0,
              ),
            ),
          ),
          uploadService: DirectStorageUploadService(
            storage: uploadGateway,
            metadataStore: metadataStore,
          ),
        );

        expect(result.insertedCount, 1);
        expect(result.uploadedAttachmentCount, 1);
        expect(result.importMode, 'notion-zip-lossless');
        expect(uploadGateway.paths, hasLength(1));
        expect(metadataStore.rows.single['note_id'], 501);
        expect(metadataStore.rows.single['source_system'], 'notion');
        expect(updatedNoteContents, hasLength(1));
        expect(updatedNoteContents.single, contains('(attachment:'));
      },
    );
  });
}
