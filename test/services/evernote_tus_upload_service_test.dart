import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/services/evernote_tus_upload_service.dart';

typedef _RequestHandler = Future<http.StreamedResponse> Function(
  http.BaseRequest request,
  Uint8List body,
);

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final _RequestHandler handler;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];
  final List<Uint8List> bodies = <Uint8List>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final body = await request.finalize().toBytes();
    bodies.add(body);
    return handler(request, body);
  }
}

void main() {
  const endpoint = 'https://project.storage.supabase.co'
      '/storage/v1/upload/resumable';

  test('uploads fixed chunks and sends owner-private object metadata',
      () async {
    var remoteOffset = 0;
    late final _RecordingClient client;
    client = _RecordingClient((request, body) async {
      if (request.method == 'POST') {
        return _response(
          201,
          headers: const <String, String>{
            'location': 'upload-1',
          },
        );
      }
      expect(request.method, 'PATCH');
      expect(request.headers['upload-offset'], remoteOffset.toString());
      remoteOffset += body.length;
      return _response(
        204,
        headers: <String, String>{
          'upload-offset': remoteOffset.toString(),
        },
      );
    });
    final service = EvernoteTusUploadService.forTesting(
      client: client,
      chunkSize: 4,
    );

    final result = await service.upload(
      endpoint: Uri.parse(endpoint),
      accessToken: 'user-access-token',
      source: Stream<List<int>>.fromIterable(<List<int>>[
        <int>[0, 1, 2],
        <int>[3, 4, 5, 6, 7, 8, 9],
      ]),
      totalBytes: 10,
      bucketId: 'evernote-migration-archives',
      objectPath: 'owner/evernote/hash/source.enex',
      contentType: 'application/xml',
    );

    expect(result.uploadedBytes, 10);
    expect(result.uploadUrl, Uri.parse('$endpoint/upload-1'));
    expect(client.requests.map((request) => request.method), <String>[
      'POST',
      'PATCH',
      'PATCH',
      'PATCH',
    ]);
    expect(client.bodies.skip(1).map((body) => body.length), <int>[4, 4, 2]);
    final metadata = _decodeMetadata(
      client.requests.first.headers['upload-metadata']!,
    );
    expect(metadata['bucketName'], 'evernote-migration-archives');
    expect(metadata['objectName'], 'owner/evernote/hash/source.enex');
    expect(metadata['contentType'], 'application/xml');
    expect(
      client.requests.first.headers['authorization'],
      'Bearer user-access-token',
    );
    expect(
      client.requests.every(
        (request) =>
            request.headers['authorization'] == 'Bearer user-access-token',
      ),
      isTrue,
    );
  });

  test('persists the resume URL before sending the first chunk', () async {
    var resumeUrlPersisted = false;
    final client = _RecordingClient((request, body) async {
      if (request.method == 'POST') {
        return _response(
          201,
          headers: const <String, String>{'location': 'upload-1'},
        );
      }
      expect(resumeUrlPersisted, isTrue);
      return _response(
        204,
        headers: const <String, String>{'upload-offset': '1'},
      );
    });
    final service = EvernoteTusUploadService.forTesting(
      client: client,
      chunkSize: 4,
    );

    await service.upload(
      endpoint: Uri.parse(endpoint),
      accessToken: 'user-access-token',
      source: Stream<List<int>>.value(<int>[1]),
      totalBytes: 1,
      bucketId: 'evernote-migration-archives',
      objectPath: 'owner/evernote/hash/source.enex',
      contentType: 'application/xml',
      onUploadUrl: (uploadUrl) async {
        await Future<void>.delayed(Duration.zero);
        resumeUrlPersisted = true;
      },
    );
  });

  test('resumes from the server offset without recreating the upload',
      () async {
    var remoteOffset = 3;
    final client = _RecordingClient((request, body) async {
      if (request.method == 'HEAD') {
        return _response(
          200,
          headers: const <String, String>{'upload-offset': '3'},
        );
      }
      expect(request.method, 'PATCH');
      expect(body, <int>[3, 4, 5, 6, 7]);
      remoteOffset += body.length;
      return _response(
        204,
        headers: <String, String>{
          'upload-offset': remoteOffset.toString(),
        },
      );
    });
    final service = EvernoteTusUploadService.forTesting(
      client: client,
      chunkSize: 6,
    );

    final result = await service.upload(
      endpoint: Uri.parse(endpoint),
      accessToken: 'user-access-token',
      source: Stream<List<int>>.value(<int>[0, 1, 2, 3, 4, 5, 6, 7]),
      totalBytes: 8,
      bucketId: 'evernote-migration-archives',
      objectPath: 'owner/evernote/hash/source.enex',
      contentType: 'application/xml',
      previousUploadUrl: Uri.parse('$endpoint/upload-1'),
    );

    expect(result.uploadedBytes, 8);
    expect(client.requests.map((request) => request.method), <String>[
      'HEAD',
      'PATCH',
    ]);
  });

  test('does not send a bearer token to a different resume host', () async {
    final client = _RecordingClient((request, body) async {
      fail('No request should be sent.');
    });
    final service = EvernoteTusUploadService.forTesting(
      client: client,
      chunkSize: 4,
    );

    await expectLater(
      service.upload(
        endpoint: Uri.parse(endpoint),
        accessToken: 'user-access-token',
        source: Stream<List<int>>.value(<int>[1]),
        totalBytes: 1,
        bucketId: 'evernote-migration-archives',
        objectPath: 'owner/source.enex',
        contentType: 'application/xml',
        previousUploadUrl: Uri.parse(
          'https://attacker.example/upload-1',
        ),
      ),
      throwsStateError,
    );
    expect(client.requests, isEmpty);
  });

  test('does not send a bearer token to a non-HTTPS port', () async {
    final client = _RecordingClient((request, body) async {
      fail('No request should be sent.');
    });
    final service = EvernoteTusUploadService.forTesting(
      client: client,
      chunkSize: 4,
    );

    await expectLater(
      service.upload(
        endpoint: Uri.parse(endpoint),
        accessToken: 'user-access-token',
        source: Stream<List<int>>.value(<int>[1]),
        totalBytes: 1,
        bucketId: 'evernote-migration-archives',
        objectPath: 'owner/source.enex',
        contentType: 'application/xml',
        previousUploadUrl: Uri.parse(
          'https://project.storage.supabase.co:444/'
          'storage/v1/upload/resumable/upload-1',
        ),
      ),
      throwsStateError,
    );
    expect(client.requests, isEmpty);
  });

  test('creates a new upload when the previous TUS URL expired', () async {
    var remoteOffset = 0;
    final client = _RecordingClient((request, body) async {
      if (request.method == 'HEAD') {
        return _response(410);
      }
      if (request.method == 'POST') {
        return _response(
          201,
          headers: const <String, String>{'location': 'upload-2'},
        );
      }
      remoteOffset += body.length;
      return _response(
        204,
        headers: <String, String>{
          'upload-offset': remoteOffset.toString(),
        },
      );
    });
    final service = EvernoteTusUploadService.forTesting(
      client: client,
      chunkSize: 4,
    );

    final result = await service.upload(
      endpoint: Uri.parse(endpoint),
      accessToken: 'user-access-token',
      source: Stream<List<int>>.value(<int>[1, 2, 3]),
      totalBytes: 3,
      bucketId: 'evernote-migration-archives',
      objectPath: 'owner/source.enex',
      contentType: 'application/xml',
      previousUploadUrl: Uri.parse('$endpoint/expired'),
    );

    expect(result.uploadUrl, Uri.parse('$endpoint/upload-2'));
    expect(client.requests.map((request) => request.method), <String>[
      'HEAD',
      'POST',
      'PATCH',
    ]);
  });

  test('rejects a cross-host upload URL returned by Supabase', () async {
    final client = _RecordingClient((request, body) async {
      return _response(
        201,
        headers: const <String, String>{
          'location': 'https://attacker.example/upload-1',
        },
      );
    });
    final service = EvernoteTusUploadService.forTesting(
      client: client,
      chunkSize: 4,
    );

    await expectLater(
      service.upload(
        endpoint: Uri.parse(endpoint),
        accessToken: 'user-access-token',
        source: Stream<List<int>>.value(<int>[1]),
        totalBytes: 1,
        bucketId: 'evernote-migration-archives',
        objectPath: 'owner/source.enex',
        contentType: 'application/xml',
      ),
      throwsStateError,
    );
    expect(client.requests, hasLength(1));
    expect(client.requests.single.url.host, 'project.storage.supabase.co');
  });

  test('derives the direct storage endpoint from a project URL', () {
    expect(
      EvernoteTusUploadService.endpointForSupabaseUrl(
        'https://project.supabase.co',
      ),
      Uri.parse(endpoint),
    );
    expect(
      EvernoteTusUploadService.endpointForSupabaseUrl(
        'https://project.storage.supabase.co/storage/v1',
      ),
      Uri.parse(endpoint),
    );
  });
}

http.StreamedResponse _response(
  int statusCode, {
  Map<String, String> headers = const <String, String>{},
}) {
  return http.StreamedResponse(
    const Stream<List<int>>.empty(),
    statusCode,
    headers: headers,
  );
}

Map<String, String> _decodeMetadata(String value) {
  final result = <String, String>{};
  for (final pair in value.split(',')) {
    final separator = pair.indexOf(' ');
    result[pair.substring(0, separator)] = utf8.decode(
      base64.decode(pair.substring(separator + 1)),
    );
  }
  return result;
}
