import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'evernote_migration_commit_service.dart';
import 'import_service.dart';

const int evernoteStageFingerprintBytes = 1024 * 1024;

enum EvernoteCloudStageState {
  preparing,
  uploading,
  parsing,
  copying,
  verifying,
  completed,
  failed,
}

class EvernoteCloudStageProgress {
  const EvernoteCloudStageProgress({
    required this.state,
    required this.processedBytes,
    required this.totalBytes,
  });

  final EvernoteCloudStageState state;
  final int processedBytes;
  final int totalBytes;

  double get fraction => totalBytes <= 0
      ? 0
      : (processedBytes / totalBytes).clamp(0, 1).toDouble();
}

typedef EvernoteCloudStageProgressCallback = void Function(
  EvernoteCloudStageProgress progress,
);

class EvernoteCloudStageResult {
  const EvernoteCloudStageResult({
    required this.preview,
    required this.stagingPath,
    required this.archivePath,
    required this.totalBytes,
  });

  final ImportPreviewResult preview;
  final String stagingPath;
  final String archivePath;
  final int totalBytes;
}

/// Sends a selected ENEX stream to private Storage before parsing it.
///
/// When [historyRevision] is true, exactly one note is accepted and the
/// content-addressed archive is isolated under the Evernote history namespace.
///
/// The browser keeps at most the file picker's current chunk, a one-megabyte
/// fingerprint prefix, and one parsed note subtree in memory. The original
/// file name is not included in the resumable staging object path.
class EvernoteCloudStageService {
  EvernoteCloudStageService({
    required this.storage,
    required this.importService,
  });

  factory EvernoteCloudStageService.supabase({
    required SupabaseClient client,
    required ImportService importService,
  }) {
    return EvernoteCloudStageService(
      storage: SupabaseEvernoteMigrationStorageGateway(client),
      importService: importService,
    );
  }

  final EvernoteMigrationStorageGateway storage;
  final ImportService importService;

  Future<EvernoteCloudStageResult> stage({
    required String userId,
    required String fileName,
    required Stream<List<int>> source,
    required int totalBytes,
    bool historyRevision = false,
    EvernoteCloudStageProgressCallback? onProgress,
  }) async {
    final ownerId = _validatedOwnerId(userId);
    if (totalBytes <= 0 || totalBytes > evernoteMigrationMaxObjectBytes) {
      throw StateError(
        'The ENEX batch must be between 1 byte and '
        '$evernoteMigrationMaxObjectBytes bytes.',
      );
    }
    final displayFileName = fileName.trim();
    if (displayFileName.isEmpty) {
      throw ArgumentError.value(fileName, 'fileName', 'must not be empty');
    }

    onProgress?.call(
      EvernoteCloudStageProgress(
        state: EvernoteCloudStageState.preparing,
        processedBytes: 0,
        totalBytes: totalBytes,
      ),
    );

    final prepared = await _prepareSource(
      source: source,
      totalBytes: totalBytes,
    );
    final fileNameHash = sha256
        .convert(utf8.encode(displayFileName))
        .toString()
        .substring(0, 32);
    final stagingNamespace =
        historyRevision ? 'evernote-history/incoming' : 'evernote/incoming';
    final stagingPath = '$ownerId/$stagingNamespace/'
        'v2-$totalBytes-${prepared.prefixSha256}-$fileNameHash.enex';

    ImportPreviewResult preview;
    try {
      String selectedSha256;
      final stagingExists = await storage.objectExists(
        bucketId: evernoteArchiveBucket,
        path: stagingPath,
      );
      if (stagingExists) {
        selectedSha256 = await _digestStream(
          prepared.replay,
          expectedBytes: totalBytes,
          onProgress: (processedBytes) {
            onProgress?.call(
              EvernoteCloudStageProgress(
                state: EvernoteCloudStageState.verifying,
                processedBytes: processedBytes,
                totalBytes: totalBytes,
              ),
            );
          },
        );
        preview = await importService.buildEvernoteStreamingPreview(
          fileName: displayFileName,
          source: storage.downloadStream(
            bucketId: evernoteArchiveBucket,
            path: stagingPath,
          ),
          totalBytes: totalBytes,
          onProgress: (processedBytes, _) {
            onProgress?.call(
              EvernoteCloudStageProgress(
                state: EvernoteCloudStageState.parsing,
                processedBytes: processedBytes,
                totalBytes: totalBytes,
              ),
            );
          },
        );
      } else {
        final selectedDigest = _EvernoteSelectedStreamDigest(totalBytes);
        Object? uploadError;
        StackTrace? uploadStackTrace;
        try {
          await storage.uploadStream(
            bucketId: evernoteArchiveBucket,
            path: stagingPath,
            source: selectedDigest.bind(prepared.replay),
            totalBytes: totalBytes,
            contentType: 'application/xml',
            onProgress: (uploadedBytes, _) {
              onProgress?.call(
                EvernoteCloudStageProgress(
                  state: EvernoteCloudStageState.uploading,
                  processedBytes: uploadedBytes,
                  totalBytes: totalBytes,
                ),
              );
            },
          );
        } catch (error, stackTrace) {
          uploadError = error;
          uploadStackTrace = stackTrace;
        }
        if (!selectedDigest.isComplete) {
          if (uploadError != null) {
            Error.throwWithStackTrace(uploadError, uploadStackTrace!);
          }
          throw StateError('The selected ENEX stream was not fully consumed.');
        }
        selectedSha256 = selectedDigest.value;
        try {
          preview = await importService.buildEvernoteStreamingPreview(
            fileName: displayFileName,
            source: storage.downloadStream(
              bucketId: evernoteArchiveBucket,
              path: stagingPath,
            ),
            totalBytes: totalBytes,
            onProgress: (processedBytes, _) {
              onProgress?.call(
                EvernoteCloudStageProgress(
                  state: EvernoteCloudStageState.parsing,
                  processedBytes: processedBytes,
                  totalBytes: totalBytes,
                ),
              );
            },
          );
        } catch (_) {
          if (uploadError != null) {
            Error.throwWithStackTrace(uploadError, uploadStackTrace!);
          }
          rethrow;
        }
      }

      final exportSha256 = preview.sourceExportSha256?.toLowerCase();
      if (exportSha256 == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(exportSha256)) {
        throw StateError('The staged ENEX did not produce a valid SHA-256.');
      }
      if (selectedSha256 != exportSha256) {
        throw StateError(
          'The selected ENEX does not match the resumable staging object. '
          'Rename the local export and select it again instead of reusing '
          'this staging fingerprint.',
        );
      }
      if (historyRevision && preview.notes.length != 1) {
        throw StateError(
          'Export exactly one Evernote history revision per ENEX file.',
        );
      }
      final archiveNamespace =
          historyRevision ? 'evernote-history' : 'evernote';
      final archivePath =
          '$ownerId/$archiveNamespace/$exportSha256/source.enex';

      onProgress?.call(
        EvernoteCloudStageProgress(
          state: EvernoteCloudStageState.copying,
          processedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
      Object? copyError;
      StackTrace? copyStackTrace;
      try {
        await storage.copyObject(
          bucketId: evernoteArchiveBucket,
          sourcePath: stagingPath,
          destinationPath: archivePath,
        );
      } catch (error, stackTrace) {
        // Content-addressed destination may already exist after a retry.
        copyError = error;
        copyStackTrace = stackTrace;
      }

      try {
        onProgress?.call(
          EvernoteCloudStageProgress(
            state: EvernoteCloudStageState.verifying,
            processedBytes: 0,
            totalBytes: totalBytes,
          ),
        );
        final stored = await _digestStream(
          storage.downloadStream(
            bucketId: evernoteArchiveBucket,
            path: archivePath,
          ),
          expectedBytes: totalBytes,
          onProgress: (processedBytes) {
            onProgress?.call(
              EvernoteCloudStageProgress(
                state: EvernoteCloudStageState.verifying,
                processedBytes: processedBytes,
                totalBytes: totalBytes,
              ),
            );
          },
        );
        if (stored != exportSha256) {
          throw StateError('The cloud recovery archive hash does not match.');
        }
      } catch (_) {
        if (copyError != null) {
          Error.throwWithStackTrace(copyError, copyStackTrace!);
        }
        rethrow;
      }

      onProgress?.call(
        EvernoteCloudStageProgress(
          state: EvernoteCloudStageState.completed,
          processedBytes: totalBytes,
          totalBytes: totalBytes,
        ),
      );
      return EvernoteCloudStageResult(
        preview: preview,
        stagingPath: stagingPath,
        archivePath: archivePath,
        totalBytes: totalBytes,
      );
    } catch (_) {
      onProgress?.call(
        EvernoteCloudStageProgress(
          state: EvernoteCloudStageState.failed,
          processedBytes: 0,
          totalBytes: totalBytes,
        ),
      );
      rethrow;
    } finally {
      await prepared.cancel();
    }
  }

  String _validatedOwnerId(String userId) {
    final ownerId = userId.trim();
    if (ownerId.isEmpty || ownerId.contains('/') || ownerId.contains(r'\')) {
      throw ArgumentError.value(userId, 'userId', 'Invalid owner id.');
    }
    return ownerId;
  }

  Future<_PreparedEvernoteSource> _prepareSource({
    required Stream<List<int>> source,
    required int totalBytes,
  }) async {
    final targetPrefixBytes = totalBytes < evernoteStageFingerprintBytes
        ? totalBytes
        : evernoteStageFingerprintBytes;
    final iterator = StreamIterator<List<int>>(source);
    final prefix = BytesBuilder(copy: false);
    List<int>? firstRemainder;

    while (prefix.length < targetPrefixBytes) {
      if (!await iterator.moveNext()) {
        await iterator.cancel();
        throw StateError('The selected ENEX ended before its declared size.');
      }
      final part = iterator.current;
      if (part.isEmpty) continue;
      final remaining = targetPrefixBytes - prefix.length;
      final take = part.length < remaining ? part.length : remaining;
      prefix.add(Uint8List.fromList(part.sublist(0, take)));
      if (take < part.length) {
        firstRemainder = part.sublist(take);
      }
    }

    final prefixBytes = prefix.takeBytes();
    final prefixSha256 = sha256.convert(prefixBytes).toString();

    Stream<List<int>> replay() async* {
      yield prefixBytes;
      final remainder = firstRemainder;
      if (remainder != null && remainder.isNotEmpty) yield remainder;
      while (await iterator.moveNext()) {
        final part = iterator.current;
        if (part.isNotEmpty) yield part;
      }
    }

    return _PreparedEvernoteSource(
      prefixSha256: prefixSha256,
      replay: replay(),
      cancel: () async {
        await iterator.cancel();
      },
    );
  }

  Future<String> _digestStream(
    Stream<List<int>> source, {
    required int expectedBytes,
    void Function(int processedBytes)? onProgress,
  }) async {
    final output = _EvernoteStageDigestSink();
    final input = sha256.startChunkedConversion(output);
    var processedBytes = 0;
    await for (final part in source) {
      if (part.isEmpty) continue;
      processedBytes += part.length;
      if (processedBytes > expectedBytes) {
        throw StateError('The cloud archive is larger than expected.');
      }
      input.add(part);
      onProgress?.call(processedBytes);
    }
    input.close();
    if (processedBytes != expectedBytes) {
      throw StateError('The cloud archive size does not match.');
    }
    return output.value.toString();
  }
}

class _PreparedEvernoteSource {
  const _PreparedEvernoteSource({
    required this.prefixSha256,
    required this.replay,
    required this.cancel,
  });

  final String prefixSha256;
  final Stream<List<int>> replay;
  final Future<void> Function() cancel;
}

class _EvernoteSelectedStreamDigest {
  _EvernoteSelectedStreamDigest(this.expectedBytes) {
    _input = sha256.startChunkedConversion(_output);
  }

  final int expectedBytes;
  final _EvernoteStageDigestSink _output = _EvernoteStageDigestSink();
  late final ByteConversionSink _input;
  var _processedBytes = 0;
  var _bound = false;
  var isComplete = false;

  Stream<List<int>> bind(Stream<List<int>> source) async* {
    if (_bound) throw StateError('The selected ENEX stream was already used.');
    _bound = true;
    var reachedEnd = false;
    try {
      await for (final part in source) {
        if (part.isEmpty) continue;
        _processedBytes += part.length;
        if (_processedBytes > expectedBytes) {
          throw StateError('The selected ENEX is larger than expected.');
        }
        _input.add(part);
        yield part;
      }
      reachedEnd = true;
    } finally {
      if (reachedEnd) {
        _input.close();
        if (_processedBytes != expectedBytes) {
          throw StateError('The selected ENEX size does not match.');
        }
        isComplete = true;
      }
    }
  }

  String get value {
    if (!isComplete) {
      throw StateError('The selected ENEX digest is incomplete.');
    }
    return _output.value.toString();
  }
}

class _EvernoteStageDigestSink implements Sink<Digest> {
  Digest? _value;

  Digest get value {
    final digest = _value;
    if (digest == null) {
      throw StateError('The cloud archive digest is not available.');
    }
    return digest;
  }

  @override
  void add(Digest data) {
    if (_value != null) {
      throw StateError('The cloud archive digest was already completed.');
    }
    _value = data;
  }

  @override
  void close() {
    if (_value == null) {
      throw StateError('The cloud archive digest was not completed.');
    }
  }
}
