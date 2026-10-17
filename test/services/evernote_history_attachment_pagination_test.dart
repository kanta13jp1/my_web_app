import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/evernote_note_history_migration_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('history attachments continue past server page caps', () async {
    var pages = 0;
    final rows = List<Map<String, dynamic>>.generate(
      205,
      (index) => <String, dynamic>{
        'file_path': 'path-${index.toString().padLeft(4, '0')}',
        'file_size': index,
        'mime_type': 'text/plain',
        'content_sha256': 'fixture',
      },
    );
    final client = SupabaseClient(
      'https://history-fixture.invalid',
      'fixture-key',
      httpClient: MockClient((request) async {
        Object response;
        if (request.url.path.endsWith('/note_versions')) {
          response = <String, dynamic>{
            'id': 'version-fixture',
            'title': 'fixture',
            'content': 'fixture',
            'saved_at': '2026-01-01T00:00:00Z',
            'source_content_sha256': 'fixture',
            'source_tags': <String>[],
          };
        } else {
          expect(
            request.url.queryParameters['note_version_id'],
            'eq.version-fixture',
          );
          expect(request.url.queryParameters['order'], 'file_path.asc');
          expect(request.url.queryParameters['limit'], '100');
          final filter = request.url.queryParameters['file_path'];
          final cursor = filter == null ? '' : filter.substring(3);
          if (filter != null) expect(filter, startsWith('gt.'));
          // Simulate an API cap smaller than the requested page size.
          response = rows
              .where((row) => (row['file_path'] as String).compareTo(cursor) > 0)
              .take(50)
              .toList();
          pages++;
        }
        return http.Response(
          jsonEncode(response),
          200,
          request: request,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final result = await SupabaseEvernoteNoteHistoryDatabaseGateway(client)
        .loadVersion(noteVersionId: 'version-fixture');
    expect(result.attachments.length, 205);
    expect(result.attachments.map((item) => item.filePath).toSet().length, 205);
    expect(result.attachments.last.filePath, 'path-0204');
    expect(pages, 6);
  });
}
