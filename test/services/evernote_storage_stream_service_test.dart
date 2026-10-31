import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/services/evernote_storage_stream_service.dart';

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      handler;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return handler(request);
  }
}

void main() {
  final baseUrl = Uri.parse('https://project.supabase.co/storage/v1');

  test('streams a private object with encoded owner-scoped path', () async {
    final client = _RecordingClient((request) async {
      return http.StreamedResponse(
        Stream<List<int>>.fromIterable(<List<int>>[
          <int>[1, 2],
          <int>[3],
        ]),
        200,
      );
    });
    final service = EvernoteStorageStreamService(client: client);

    final bytes = await service
        .download(
          storageBaseUrl: baseUrl,
          headers: const <String, String>{
            'apikey': 'publishable-key',
            'Authorization': 'Bearer user-access-token',
          },
          bucketId: 'evernote-migration-archives',
          objectPath: 'owner id/evernote/source.enex',
        )
        .expand((chunk) => chunk)
        .toList();

    expect(bytes, <int>[1, 2, 3]);
    expect(client.requests, hasLength(1));
    final request = client.requests.single;
    expect(request.method, 'GET');
    expect(request.followRedirects, isFalse);
    expect(
      request.url.toString(),
      'https://project.supabase.co/storage/v1/object/'
      'evernote-migration-archives/owner%20id/evernote/source.enex',
    );
    expect(request.headers['authorization'], 'Bearer user-access-token');
  });

  test('does not follow redirects with a bearer token', () async {
    final client = _RecordingClient((request) async {
      return http.StreamedResponse(
        const Stream<List<int>>.empty(),
        302,
        headers: const <String, String>{
          'location': 'https://attacker.example/steal',
        },
      );
    });
    final service = EvernoteStorageStreamService(client: client);

    await expectLater(
      service
          .download(
            storageBaseUrl: baseUrl,
            headers: const <String, String>{
              'Authorization': 'Bearer user-access-token',
            },
            bucketId: 'evernote-migration-archives',
            objectPath: 'owner/source.enex',
          )
          .drain<void>(),
      throwsStateError,
    );
    expect(client.requests.single.followRedirects, isFalse);
  });

  test('rejects unsafe paths before sending credentials', () async {
    final client = _RecordingClient((request) async {
      fail('No request should be sent.');
    });
    final service = EvernoteStorageStreamService(client: client);

    await expectLater(
      service
          .download(
            storageBaseUrl: baseUrl,
            headers: const <String, String>{
              'Authorization': 'Bearer user-access-token',
            },
            bucketId: 'evernote-migration-archives',
            objectPath: '../private.enex',
          )
          .drain<void>(),
      throwsArgumentError,
    );
    expect(client.requests, isEmpty);
  });

  test('rejects a non-HTTPS storage URL before sending credentials', () async {
    final client = _RecordingClient((request) async {
      fail('No request should be sent.');
    });
    final service = EvernoteStorageStreamService(client: client);

    await expectLater(
      service
          .download(
            storageBaseUrl: Uri.parse('http://project.supabase.co/storage/v1'),
            headers: const <String, String>{
              'Authorization': 'Bearer user-access-token',
            },
            bucketId: 'evernote-migration-archives',
            objectPath: 'owner/source.enex',
          )
          .drain<void>(),
      throwsArgumentError,
    );
    expect(client.requests, isEmpty);
  });
}
