import 'package:http/http.dart' as http;

class EvernoteStorageStreamService {
  EvernoteStorageStreamService({required http.Client client})
      : _client = client;

  final http.Client _client;

  Stream<List<int>> download({
    required Uri storageBaseUrl,
    required Map<String, String> headers,
    required String bucketId,
    required String objectPath,
  }) async* {
    _validateBaseUrl(storageBaseUrl);
    final bucket = bucketId.trim();
    final pathSegments = objectPath.trim().split('/');
    if (bucket.isEmpty ||
        bucket.contains('/') ||
        bucket == '.' ||
        bucket == '..' ||
        pathSegments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw ArgumentError(
        'A safe Storage bucket and object path are required.',
      );
    }
    final authorization = headers.entries
        .where((entry) => entry.key.toLowerCase() == 'authorization')
        .map((entry) => entry.value.trim())
        .firstOrNull;
    if (authorization == null ||
        !authorization.startsWith('Bearer ') ||
        authorization.contains('\r') ||
        authorization.contains('\n')) {
      throw ArgumentError('A valid Storage authorization header is required.');
    }

    final objectUrl = storageBaseUrl.replace(
      pathSegments: <String>[
        ...storageBaseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        'object',
        bucket,
        ...pathSegments,
      ],
    );
    final request = http.Request('GET', objectUrl)
      ..followRedirects = false
      ..headers.addAll(headers);
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw StateError(
        'Supabase could not stream the private Evernote object '
        '(HTTP ${response.statusCode}).',
      );
    }
    yield* response.stream;
  }

  static void _validateBaseUrl(Uri storageBaseUrl) {
    if (storageBaseUrl.scheme != 'https' ||
        storageBaseUrl.host.isEmpty ||
        storageBaseUrl.port != 443 ||
        storageBaseUrl.userInfo.isNotEmpty ||
        storageBaseUrl.query.isNotEmpty ||
        storageBaseUrl.fragment.isNotEmpty) {
      throw ArgumentError.value(
        storageBaseUrl,
        'storageBaseUrl',
        'A safe HTTPS Supabase Storage URL is required.',
      );
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
