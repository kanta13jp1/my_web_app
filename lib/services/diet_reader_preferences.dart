import 'package:shared_preferences/shared_preferences.dart';

typedef DietReaderSettings = ({
  Set<String> readIds,
  Set<String> uncertainReadIds,
  double fontSize,
  bool fontSizeUncertain,
});

/// Serialize this feature's reads and writes across routes and account changes.
/// Reuse the plugin's local cache without replacing it for unrelated features.
class DietReaderPreferences {
  DietReaderPreferences({
    Future<SharedPreferences> Function()? openPreferences,
    Future<bool> Function(SharedPreferences, String, Object?)? write,
  })  : _openPreferences = openPreferences ?? SharedPreferences.getInstance,
        _write = write ?? _writePreference;

  static final shared = DietReaderPreferences();
  static const _sizeKey = 'diet_debates.font_size';
  static String _prefix(String owner) => 'diet_debates.v1.read.$owner.';

  final Future<bool> Function(SharedPreferences, String, Object?) _write;
  final Future<SharedPreferences> Function() _openPreferences;
  Future<void> _tail = Future<void>.value();
  final _beforeFailedWrite = <String, Object?>{};

  Object? _displayValue(SharedPreferences prefs, String key) =>
      _beforeFailedWrite.containsKey(key)
          ? _beforeFailedWrite[key]
          : prefs.get(key);

  Future<T> _ordered<T>(Future<T> Function(SharedPreferences) action) {
    final result = _tail.then((_) async {
      final prefs = await _openPreferences();
      return await action(prefs);
    });
    // An I/O error belongs to the caller. Later operations must still run.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<DietReaderSettings> load(String? owner) => _ordered((prefs) async {
        final ids = <String>{};
        final uncertainIds = <String>{};
        if (owner != null) {
          final prefix = _prefix(owner);
          final ownedKeys = {
            ...prefs.getKeys().where((key) => key.startsWith(prefix)),
            ..._beforeFailedWrite.keys.where((key) => key.startsWith(prefix)),
          };
          for (final key in ownedKeys) {
            if (_beforeFailedWrite.containsKey(key)) {
              uncertainIds.add(key.substring(prefix.length));
            }
            if (_displayValue(prefs, key) == true) {
              ids.add(key.substring(prefix.length));
            }
          }
        }
        final value = _displayValue(prefs, _sizeKey);
        final size = value is double && const [16.0, 20.0, 24.0].contains(value)
            ? value
            : 16.0;
        return (
          readIds: ids,
          uncertainReadIds: uncertainIds,
          fontSize: size,
          fontSizeUncertain: _beforeFailedWrite.containsKey(_sizeKey)
        );
      });

  Future<void> setRead(String owner, String id, bool read) =>
      _save('${_prefix(owner)}$id', read ? true : null);

  Future<void> setFontSize(double size) => _save(_sizeKey, size);

  Future<void> _save(String key, Object? value) => _ordered((prefs) async {
        final previous = _displayValue(prefs, key);
        try {
          if (!await _write(prefs, key, value)) {
            throw StateError('Preference not saved');
          }
          _beforeFailedWrite.remove(key);
        } catch (_) {
          // The previous UI value is a fallback. The durable outcome is unknown.
          _beforeFailedWrite[key] = previous;
          rethrow;
        }
      });

  static Future<bool> _writePreference(
      SharedPreferences prefs, String key, Object? value,) {
    if (value == null) return prefs.remove(key);
    if (value is bool) return prefs.setBool(key, value);
    return prefs.setDouble(key, value as double);
  }
}
