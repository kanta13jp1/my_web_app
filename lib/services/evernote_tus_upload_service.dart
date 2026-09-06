import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

const int evernoteTusChunkSizeBytes = 6 * 1024 * 1024;
const int evernoteTusRecommendedThresholdBytes = 6 * 1024 * 1024;

class EvernoteTusUploadResult {
  const EvernoteTusUploadResult({
    required this.uploadUrl,
    required this.uploadedBytes,
  });

  final Uri uploadUrl;
  final int uploadedBytes;
}

class EvernoteTusUploadService {
  EvernoteTusUploadService({required http.Client client})
      : _client = client,
        _chunkSize = evernoteTusChunkSizeBytes;

  EvernoteTusUploadService.forTesting({
    required http.Client client,
    required int chunkSize,
  })  : _client = client,
        _chunkSize = chunkSize {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'must be positive');
    }
  }

  final http.Client _client;
  final int _chunkSize;

  static Uri endpointForSupabaseUrl(String supabaseUrl) {
    final projectUrl = Uri.parse(supabaseUrl.trim());
    if (projectUrl.scheme != 'https' || projectUrl.host.isEmpty) {
      throw ArgumentError.value(
        supabaseUrl,
        'supabaseUrl',
        'An HTTPS Supabase project URL is required.',
      );
    }
    final projectId = projectUrl.host.endsWith('.storage.supabase.co')
        ? projectUrl.host.substring(
            0,
            projectUrl.host.length - '.storage.supabase.co'.length,
          )
        : projectUrl.host.endsWith('.supabase.co')
            ? projectUrl.host.substring(
                0,
                projectUrl.host.length - '.supabase.co'.length,
              )
            : '';
    if (projectId.isEmpty || projectId.contains('.')) {
      throw ArgumentError.value(
        supabaseUrl,
        'supabaseUrl',
        'A standard Supabase project URL is required.',
      );
    }
    return Uri(
      scheme: 'https',
      host: '$projectId.storage.supabase.co',
      path: '/storage/v1/upload/resumable',
    );
  }

  Future<EvernoteTusUploadResult> upload({
    required Uri endpoint,
    required String accessToken,
    required Stream<List<int>> source,
    required int totalBytes,
    required String bucketId,
    required String objectPath,
    required String contentType,
    Uri? previousUploadUrl,
    bool upsert = false,
    FutureOr<void> Function(Uri uploadUrl)? onUploadUrl,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
  }) async {
    _validateEndpoint(endpoint);
    final token = accessToken.trim();
    if (token.isEmpty || token.contains('\r') || token.contains('\n')) {
      throw ArgumentError.value(
        accessToken,
        'accessToken',
        'A valid access token is required.',
      );
    }
    if (totalBytes <= 0) {
      throw ArgumentError.value(totalBytes, 'totalBytes', 'must be positive');
    }
    final bucket = bucketId.trim();
    final path = objectPath.trim();
    if (bucket.isEmpty || path.isEmpty || path.split('/').contains('..')) {
      throw ArgumentError('A safe bucket and object path are required.');
    }

    var uploadUrl = previousUploadUrl;
    var uploadOffset = 0;
    if (uploadUrl != null) {
      _validateUploadUrl(endpoint: endpoint, uploadUrl: uploadUrl);
      final resumedOffset = await _loadResumeOffset(
        uploadUrl: uploadUrl,
        accessToken: token,
      );
      if (resumedOffset == null) {
        uploadUrl = null;
      } else {
        uploadOffset = resumedOffset;
      }
    }
    if (uploadUrl == null) {
      uploadUrl = await _createUpload(
        endpoint: endpoint,
        accessToken: token,
        totalBytes: totalBytes,
        bucketId: bucket,
        objectPath: path,
        contentType: contentType,
        upsert: upsert,
      );
      final uploadUrlCallback = onUploadUrl;
      if (uploadUrlCallback != null) {
        await uploadUrlCallback(uploadUrl);
      }
    }
    if (uploadOffset < 0 || uploadOffset > totalBytes) {
      throw StateError('The resumable upload offset is outside the file.');
    }
    onProgress?.call(uploadOffset, totalBytes);
    if (uploadOffset == totalBytes) {
      return EvernoteTusUploadResult(
        uploadUrl: uploadUrl,
        uploadedBytes: uploadOffset,
      );
    }

    var sourcePosition = 0;
    final buffer = BytesBuilder(copy: false);
    await for (final part in source) {
      if (part.isEmpty) continue;
      if (sourcePosition + part.length > totalBytes) {
        throw StateError('The upload stream is larger than the declared file.');
      }
      var partOffset = 0;
      if (sourcePosition < uploadOffset) {
        final skip = uploadOffset - sourcePosition;
        if (skip >= part.length) {
          sourcePosition += part.length;
          continue;
        }
        partOffset = skip;
      }
      sourcePosition += part.length;
      while (partOffset < part.length) {
        final capacity = _chunkSize - buffer.length;
        final available = part.length - partOffset;
        final take = available < capacity ? available : capacity;
        buffer.add(
          Uint8List.fromList(part.sublist(partOffset, partOffset + take)),
        );
        partOffset += take;
        if (buffer.length == _chunkSize) {
          uploadOffset = await _sendChunk(
            uploadUrl: uploadUrl,
            accessToken: token,
            uploadOffset: uploadOffset,
            chunk: buffer.takeBytes(),
          );
          onProgress?.call(uploadOffset, totalBytes);
        }
      }
    }
    if (sourcePosition != totalBytes) {
      throw StateError(
        'The upload stream ended before the declared file size.',
      );
    }
    if (buffer.isNotEmpty) {
      uploadOffset = await _sendChunk(
        uploadUrl: uploadUrl,
        accessToken: token,
        uploadOffset: uploadOffset,
        chunk: buffer.takeBytes(),
      );
      onProgress?.call(uploadOffset, totalBytes);
    }
    if (uploadOffset != totalBytes) {
      throw StateError('The upload did not reach the declared file size.');
    }
    return EvernoteTusUploadResult(
      uploadUrl: uploadUrl,
      uploadedBytes: uploadOffset,
    );
  }

  Future<Uri> _createUpload({
    required Uri endpoint,
    required String accessToken,
    required int totalBytes,
    required String bucketId,
    required String objectPath,
    required String contentType,
    required bool upsert,
  }) async {
    final request = http.Request('POST', endpoint)
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $accessToken',
        'Tus-Resumable': '1.0.0',
        'Upload-Length': totalBytes.toString(),
        'Upload-Metadata': _uploadMetadata(<String, String>{
          'bucketName': bucketId,
          'objectName': objectPath,
          'contentType': contentType,
          'cacheControl': '3600',
        }),
        if (upsert) 'x-upsert': 'true',
      });
    final response = await _client.send(request);
    await response.stream.drain<void>();
    if (response.statusCode != 201) {
      throw StateError(
        'Supabase did not create the resumable upload '
        '(HTTP ${response.statusCode}).',
      );
    }
    final location = response.headers['location'];
    if (location == null || location.trim().isEmpty) {
      throw StateError('Supabase did not return a resumable upload URL.');
    }
    final uploadUrl =
        endpoint.replace(path: '${endpoint.path}/').resolve(location.trim());
    _validateUploadUrl(endpoint: endpoint, uploadUrl: uploadUrl);
    return uploadUrl;
  }

  Future<int?> _loadResumeOffset({
    required Uri uploadUrl,
    required String accessToken,
  }) async {
    final request = http.Request('HEAD', uploadUrl)
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $accessToken',
        'Tus-Resumable': '1.0.0',
      });
    final response = await _client.send(request);
    await response.stream.drain<void>();
    if (response.statusCode == 404 || response.statusCode == 410) {
      return null;
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw StateError(
        'Supabase could not resume the upload '
        '(HTTP ${response.statusCode}).',
      );
    }
    final offset = int.tryParse(response.headers['upload-offset'] ?? '');
    if (offset == null || offset < 0) {
      throw StateError('Supabase returned an invalid upload offset.');
    }
    return offset;
  }

  Future<int> _sendChunk({
    required Uri uploadUrl,
    required String accessToken,
    required int uploadOffset,
    required Uint8List chunk,
  }) async {
    final request = http.StreamedRequest('PATCH', uploadUrl)
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $accessToken',
        'Tus-Resumable': '1.0.0',
        'Upload-Offset': uploadOffset.toString(),
        'Content-Type': 'application/offset+octet-stream',
      })
      ..contentLength = chunk.length;
    request.sink.add(chunk);
    unawaited(request.sink.close());
    final response = await _client.send(request);
    await response.stream.drain<void>();
    if (response.statusCode != 204) {
      throw StateError(
        'Supabase rejected an upload chunk '
        '(HTTP ${response.statusCode}).',
      );
    }
    final nextOffset = int.tryParse(
      response.headers['upload-offset'] ?? '',
    );
    if (nextOffset == null) {
      throw StateError('Supabase returned an invalid upload offset.');
    }
    final expectedOffset = uploadOffset + chunk.length;
    if (nextOffset != expectedOffset) {
      throw StateError('Supabase returned an unexpected upload offset.');
    }
    return nextOffset;
  }

  static String _uploadMetadata(Map<String, String> values) {
    return values.entries
        .map(
          (entry) => '${entry.key} '
              '${base64.encode(utf8.encode(entry.value))}',
        )
        .join(',');
  }

  static void _validateEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'https' ||
        !endpoint.host.endsWith('.storage.supabase.co') ||
        endpoint.port != 443 ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.query.isNotEmpty ||
        endpoint.fragment.isNotEmpty ||
        endpoint.path != '/storage/v1/upload/resumable') {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'The direct Supabase Storage TUS endpoint is required.',
      );
    }
  }

  static void _validateUploadUrl({
    required Uri endpoint,
    required Uri uploadUrl,
  }) {
    if (uploadUrl.scheme != 'https' ||
        uploadUrl.host != endpoint.host ||
        uploadUrl.port != 443 ||
        uploadUrl.userInfo.isNotEmpty ||
        uploadUrl.query.isNotEmpty ||
        uploadUrl.fragment.isNotEmpty ||
        !uploadUrl.path.startsWith('/storage/v1/upload/resumable/')) {
      throw StateError('Supabase returned an unsafe resumable upload URL.');
    }
  }
}
