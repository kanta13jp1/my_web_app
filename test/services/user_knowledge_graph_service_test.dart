import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_knowledge_graph.dart';
import 'package:my_web_app/services/user_knowledge_graph_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('parses owner status and document metadata', () async {
    final service = SupabaseUserKnowledgeGraphService(
      invoker: (body) async {
        expect(body['action'], 'knowledge_graph.status');
        return <String, dynamic>{
          'success': true,
          'configured': true,
          'graph_ready': true,
          'documents': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'document-1',
              'file_name': 'roadmap.pdf',
              'mime_type': 'application/pdf',
              'size_bytes': 2048,
              'processing_status': 'completed',
              'created_at': '2026-08-24T00:00:00Z',
            },
          ],
        };
      },
    );

    final status = await service.loadStatus();

    expect(status.configured, isTrue);
    expect(status.graphReady, isTrue);
    expect(status.documents.single.fileName, 'roadmap.pdf');
  });

  test(
    'uploads base64 content with offline policy but never an API key',
    () async {
      late Map<String, dynamic> captured;
      final service = SupabaseUserKnowledgeGraphService(
        invoker: (body) async {
          captured = body;
          return <String, dynamic>{
            'success': true,
            'document': <String, dynamic>{
              'id': 'document-1',
              'file_name': 'roadmap.txt',
              'mime_type': 'text/plain',
              'size_bytes': 3,
              'processing_status': 'in_progress',
              'created_at': '2026-08-24T00:00:00Z',
            },
          };
        },
      );

      final document = await service.upload(
        UserKnowledgeGraphUpload(
          fileName: 'roadmap.txt',
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      );

      expect(document.id, 'document-1');
      expect(captured['file_base64'], 'AQID');
      expect(captured['offline_secure_mode'], isFalse);
      expect(captured.containsKey('api_key'), isFalse);
      expect(captured.containsKey('WRITER_API_KEY'), isFalse);
    },
  );

  test('parses answer and inline citation metadata', () async {
    final service = SupabaseUserKnowledgeGraphService(
      invoker: (_) async => <String, dynamic>{
        'success': true,
        'answer': 'October [1]',
        'citations': <Map<String, dynamic>>[
          <String, dynamic>{
            'index': 1,
            'document_id': 'document-1',
            'file_name': 'roadmap.txt',
            'snippet': 'Launch is in October.',
          },
        ],
      },
    );

    final answer = await service.ask('When is launch?');

    expect(answer.answer, contains('[1]'));
    expect(answer.citations.single.fileName, 'roadmap.txt');
  });

  test('rejects files larger than the shared 4 MB boundary', () async {
    const service = SupabaseUserKnowledgeGraphService(
      invoker: _unexpectedInvoke,
    );

    expect(
      () => service.upload(
        UserKnowledgeGraphUpload(
          fileName: 'too-large.txt',
          mimeType: 'text/plain',
          bytes: Uint8List(SupabaseUserKnowledgeGraphService.maxFileBytes + 1),
        ),
      ),
      throwsA(
        isA<UserKnowledgeGraphException>().having(
          (error) => error.message,
          'message',
          contains('4MB'),
        ),
      ),
    );
  });
}

Future<Map<String, dynamic>> _unexpectedInvoke(Map<String, dynamic> _) {
  throw StateError('invoker should not be called');
}
