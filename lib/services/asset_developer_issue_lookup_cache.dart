import 'dart:async';
import 'dart:convert';

typedef AssetDeveloperIssueLookupLoader = Future<Map<String, Map<String, dynamic>>>
    Function(List<Map<String, String>> requests);

/// Session-only cache shared by the display and pre-generation lookup paths.
/// Full payload identities keep changed descriptions distinct. Null entries mean
/// a successful lookup found no issue; failed lookups are never cached.
class AssetDeveloperIssueLookupCache {
  AssetDeveloperIssueLookupCache({this.maxCachedEntries = 256})
      : assert(maxCachedEntries > 0);

  final int maxCachedEntries;
  String? _scopeKey;
  int _generation = 0;
  final Map<String, Map<String, dynamic>?> _completed = {};
  final Map<String, Future<Map<String, dynamic>?>> _pending = {};

  String? get scopeKey => _scopeKey;
  int get revision => _generation;

  void resetScope(String? scopeKey) {
    if (_scopeKey == scopeKey) return;
    _scopeKey = scopeKey;
    invalidate();
  }

  void invalidate() {
    _generation++;
    _completed.clear();
    _pending.clear();
  }

  Future<Map<String, Map<String, dynamic>>> lookup({
    required String scopeKey,
    required List<Map<String, String>> requests,
    required AssetDeveloperIssueLookupLoader load,
  }) async {
    resetScope(scopeKey);
    final generation = _generation;
    final identities = <String, Map<String, String>>{};
    for (final request in requests) {
      final key = request['key'] ?? '';
      if (key.isEmpty) throw ArgumentError('A request key is required');
      final payload = Map<String, String>.unmodifiable({
        'key': key,
        'title': request['title'] ?? '',
        'description': request['description'] ?? '',
      });
      final identity = jsonEncode([
        payload['key'],
        payload['title'],
        payload['description'],
      ]);
      identities[identity] = payload;
    }

    final missing = <String, Map<String, String>>{
      for (final entry in identities.entries)
        if (!_completed.containsKey(entry.key) &&
            !_pending.containsKey(entry.key))
          entry.key: entry.value,
    };
    if (missing.isNotEmpty) {
      final batch = Completer<Map<String, Map<String, dynamic>?>>();
      for (final identity in missing.keys) {
        _pending[identity] = batch.future.then((result) => result[identity]);
      }
      unawaited(_fetchBatch(generation, missing, load, batch));
    }

    final results = await Future.wait<Map<String, dynamic>?>([
      for (final identity in identities.keys)
        if (_completed.containsKey(identity))
          Future.value(_completed[identity])
        else
          _pending[identity]!,
    ]);
    if (_generation != generation) {
      throw StateError('The lookup scope was invalidated');
    }
    final byKey = <String, Map<String, dynamic>>{};
    final payloads = identities.values.toList(growable: false);
    for (var index = 0; index < results.length; index++) {
      final issue = results[index];
      if (issue != null) {
        byKey[payloads[index]['key']!] = Map<String, dynamic>.from(issue);
      }
    }
    return byKey;
  }

  Future<void> _fetchBatch(
    int generation,
    Map<String, Map<String, String>> requests,
    AssetDeveloperIssueLookupLoader load,
    Completer<Map<String, Map<String, dynamic>?>> batch,
  ) async {
    try {
      final fetched = await load(
        List<Map<String, String>>.unmodifiable(requests.values),
      );
      final results = <String, Map<String, dynamic>?>{};
      for (final entry in requests.entries) {
        final issue = fetched[entry.value['key']];
        results[entry.key] = issue == null
            ? null
            : Map<String, dynamic>.unmodifiable(issue);
      }
      if (_generation == generation) {
        for (final entry in results.entries) {
          _completed[entry.key] = entry.value;
          _pending.remove(entry.key);
        }
        while (_completed.length > maxCachedEntries) {
          _completed.remove(_completed.keys.first);
        }
      }
      batch.complete(results);
    } catch (error, stackTrace) {
      if (_generation == generation) {
        for (final identity in requests.keys) {
          _pending.remove(identity);
        }
      }
      batch.completeError(error, stackTrace);
    }
  }
}
