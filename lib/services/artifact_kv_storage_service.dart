import 'dart:convert';

enum ArtifactStorageScope {
  private('private', '個人保存'),
  shared('shared', '共有保存');

  final String wireKey;
  final String labelJa;

  const ArtifactStorageScope(this.wireKey, this.labelJa);
}

class ArtifactKvRecord {
  final ArtifactStorageScope scope;
  final String hierarchicalKey;
  final String payloadJson;
  final DateTime updatedAt;
  final int byteLength;

  const ArtifactKvRecord({
    required this.scope,
    required this.hierarchicalKey,
    required this.payloadJson,
    required this.updatedAt,
    required this.byteLength,
  });
}

class ArtifactKvValidationException implements Exception {
  final String message;

  const ArtifactKvValidationException(this.message);

  @override
  String toString() => 'ArtifactKvValidationException: $message';
}

class ArtifactKvStorageService {
  static const int defaultMaxPayloadBytes = 65536;
  static final RegExp _hierarchicalKeyRe = RegExp(
    r'^[a-zA-Z0-9_-]{1,48}:[a-zA-Z0-9_.-]{1,79}$',
  );

  final int maxPayloadBytes;
  final DateTime Function() _clock;
  final Future<void> Function(ArtifactKvRecord record)? _onPersist;
  final Map<String, ArtifactKvRecord> _records = <String, ArtifactKvRecord>{};

  ArtifactKvStorageService({
    this.maxPayloadBytes = defaultMaxPayloadBytes,
    DateTime Function()? clock,
    Future<void> Function(ArtifactKvRecord record)? onPersist,
  })  : _clock = clock ?? DateTime.now,
        _onPersist = onPersist;

  static String? validateKey(String rawKey) {
    final trimmed = rawKey.trim();
    if (trimmed.isEmpty) {
      return 'キー名を入力してください。';
    }
    if (trimmed.length > 128) {
      return 'キー名は128文字以内にしてください。';
    }
    if (!_hierarchicalKeyRe.hasMatch(trimmed)) {
      return 'キー名は「namespace:id」形式で指定してください。';
    }
    return null;
  }

  String _compositeKey(ArtifactStorageScope scope, String hierarchicalKey) {
    return '${scope.wireKey}::$hierarchicalKey';
  }

  Future<ArtifactKvRecord> put({
    required ArtifactStorageScope scope,
    required String key,
    required String payloadJson,
    DateTime? updatedAt,
  }) async {
    final keyError = validateKey(key);
    if (keyError != null) {
      throw ArtifactKvValidationException(keyError);
    }

    final normalizedKey = key.trim();
    final byteLength = utf8.encode(payloadJson).length;
    if (byteLength > maxPayloadBytes) {
      throw ArtifactKvValidationException(
        '保存サイズが上限 ($maxPayloadBytes bytes) を超えています ($byteLength bytes)。',
      );
    }

    final candidate = ArtifactKvRecord(
      scope: scope,
      hierarchicalKey: normalizedKey,
      payloadJson: payloadJson,
      updatedAt: (updatedAt ?? _clock()).toUtc(),
      byteLength: byteLength,
    );

    final storeKey = _compositeKey(scope, normalizedKey);
    final existing = _records[storeKey];
    final winner =
        existing == null || !candidate.updatedAt.isBefore(existing.updatedAt)
            ? candidate
            : existing;

    _records[storeKey] = winner;
    if (_onPersist != null && identical(winner, candidate)) {
      await _onPersist!(winner);
    }
    return winner;
  }

  Future<ArtifactKvRecord?> get({
    required ArtifactStorageScope scope,
    required String key,
  }) async {
    final keyError = validateKey(key);
    if (keyError != null) {
      throw ArtifactKvValidationException(keyError);
    }
    return _records[_compositeKey(scope, key.trim())];
  }

  Future<List<ArtifactKvRecord>> listByNamespace({
    required ArtifactStorageScope scope,
    String? namespacePrefix,
  }) async {
    final prefix = namespacePrefix?.trim() ?? '';
    final matched = _records.values.where((record) {
      if (record.scope != scope) {
        return false;
      }
      if (prefix.isEmpty) {
        return true;
      }
      return record.hierarchicalKey.startsWith('$prefix:');
    }).toList(growable: false)
      ..sort((a, b) => a.hierarchicalKey.compareTo(b.hierarchicalKey));
    return matched;
  }

  Future<bool> delete({
    required ArtifactStorageScope scope,
    required String key,
  }) async {
    final keyError = validateKey(key);
    if (keyError != null) {
      throw ArtifactKvValidationException(keyError);
    }
    return _records.remove(_compositeKey(scope, key.trim())) != null;
  }
}
