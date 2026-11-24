import 'package:logger/logger.dart';

/// ログ出力時にマスク対象とする機密情報キー一覧 (#2732)。
const Set<String> kDefaultSensitiveLogKeys = <String>{
  'password',
  'passwd',
  'passphrase',
  'pwd',
  'secret',
  'token',
  'access_token',
  'refresh_token',
  'id_token',
  'api_key',
  'apikey',
  'authorization',
  'cookie',
  'set_cookie',
  'service_role',
  'service_role_key',
  'private_key',
  'client_secret',
  'bearer',
  'pin',
  'email',
  'phone',
  'phone_number',
  'tel',
  'address',
  'ssn',
  'my_number',
  'credit_card',
  'card_number',
  'cvv',
  'bank_account',
  'account_number',
};

const List<String> _kSensitiveKeySuffixes = <String>[
  '_password',
  '_passwd',
  '_passphrase',
  '_secret',
  '_token',
  '_api_key',
  '_apikey',
  '_private_key',
  '_service_role',
  '_service_role_key',
  '_cookie',
  '_credit_card',
  '_card_number',
  '_account_number',
  '_phone',
  '_phone_number',
  '_email',
  '_cvv',
  '_ssn',
  '_my_number',
];

final RegExp _kCamelBoundary = RegExp(r'([a-z0-9])([A-Z])');
final RegExp _kKeySeparators = RegExp(r'[-\.\s]+');
final RegExp _kAuthHeader = RegExp(
  r'\b(Bearer|Basic)\s+[A-Za-z0-9\-._~+/]+=*',
  caseSensitive: false,
);
final RegExp _kJwtPattern = RegExp(
  r'\beyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\b',
);
final RegExp _kJsonQuotedField = RegExp(
  r'"([A-Za-z0-9_.-]+)"\s*:\s*"([^"]*)"',
);
final RegExp _kKeyValueQuoted = RegExp(
  r"""([A-Za-z0-9_.-]+)\s*([=:])\s*(['"])([^'"]*)\3""",
);
final RegExp _kKeyValueUnquoted = RegExp(
  r'([A-Za-z0-9_.-]+)\s*([=:])\s*([^\s,&;"\x27\)\]}]+)',
);
final RegExp _kEmailPattern = RegExp(
  r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
);
final RegExp _kCardDigitsPattern = RegExp(
  r'\b(?:\d{4}[-\s]\d{4}[-\s]\d{4}[-\s]\d{1,4}|\d{13,19})\b',
);
final RegExp _kBearerPlaceholderAhead = RegExp(r'^\s+\*\*\*');

/// ログ出力時の機密情報マスク処理の共通ユーティリティ (#2732)。
class SensitiveLogMasker {
  static const String maskPlaceholder = '***';

  const SensitiveLogMasker._();

  static String _normalizeKey(String key) {
    final snake = key
        .replaceAllMapped(
          _kCamelBoundary,
          (match) => '${match[1]}_${match[2]}',
        )
        .replaceAll(_kKeySeparators, '_')
        .toLowerCase();
    return snake.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// [key] が機密情報キー一覧またはサフィックス規則に一致するかを判定する。
  static bool isSensitiveKey(String key, {Set<String>? extraKeys}) {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) {
      return false;
    }
    if (kDefaultSensitiveLogKeys.contains(normalized)) {
      return true;
    }
    if (extraKeys != null) {
      for (final extra in extraKeys) {
        if (_normalizeKey(extra) == normalized) {
          return true;
        }
      }
    }
    for (final suffix in _kSensitiveKeySuffixes) {
      if (normalized.endsWith(suffix)) {
        return true;
      }
    }
    return false;
  }

  /// テキスト内の認証ヘッダー・JWT・JSON フィールド・クエリ値・個人識別子をマスクする。
  static String maskString(String input, {Set<String>? extraKeys}) {
    if (input.isEmpty) {
      return input;
    }
    var result = input.replaceAllMapped(
      _kAuthHeader,
      (match) => '${match[1]} $maskPlaceholder',
    );
    result = result.replaceAll(_kJwtPattern, maskPlaceholder);
    result = result.replaceAllMapped(_kJsonQuotedField, (match) {
      final key = match[1] ?? '';
      if (!isSensitiveKey(key, extraKeys: extraKeys)) {
        return match[0] ?? '';
      }
      return '"$key":"$maskPlaceholder"';
    });
    result = result.replaceAllMapped(_kKeyValueQuoted, (match) {
      final key = match[1] ?? '';
      final sep = match[2] ?? '=';
      final quote = match[3] ?? '"';
      if (!isSensitiveKey(key, extraKeys: extraKeys)) {
        return match[0] ?? '';
      }
      return '$key$sep$quote$maskPlaceholder$quote';
    });
    result = result.replaceAllMapped(_kKeyValueUnquoted, (match) {
      final key = match[1] ?? '';
      final sep = match[2] ?? '=';
      final value = match[3] ?? '';
      final lowerValue = value.toLowerCase();
      final isAuthSchemePrefix =
          (lowerValue == 'bearer' || lowerValue == 'basic') &&
              _kBearerPlaceholderAhead.hasMatch(result.substring(match.end));
      if (!isSensitiveKey(key, extraKeys: extraKeys) ||
          value == maskPlaceholder ||
          isAuthSchemePrefix) {
        return match[0] ?? '';
      }
      return '$key$sep$maskPlaceholder';
    });
    result = result.replaceAll(_kEmailPattern, maskPlaceholder);
    result = result.replaceAll(_kCardDigitsPattern, maskPlaceholder);
    return result;
  }

  /// 任意の値 (`String` / `Map` / `Iterable` / 例外オブジェクト) を再帰的にマスクする。
  static dynamic maskValue(
    dynamic value, {
    Set<String>? extraKeys,
    int maxDepth = 8,
  }) {
    return _maskRecursive(
      value,
      extraKeys: extraKeys,
      maxDepth: maxDepth,
      depth: 0,
      visited: Set<Object>.identity(),
    );
  }

  static dynamic _maskRecursive(
    dynamic value, {
    required Set<String>? extraKeys,
    required int maxDepth,
    required int depth,
    required Set<Object> visited,
  }) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is String) {
      return maskString(value, extraKeys: extraKeys);
    }
    if (depth >= maxDepth) {
      return maskPlaceholder;
    }
    if (value is Map) {
      if (!visited.add(value)) {
        return '[Circular]';
      }
      try {
        final masked = <String, dynamic>{};
        for (final entry in value.entries) {
          final keyString = entry.key.toString();
          if (isSensitiveKey(keyString, extraKeys: extraKeys)) {
            masked[keyString] = maskPlaceholder;
          } else {
            masked[keyString] = _maskRecursive(
              entry.value,
              extraKeys: extraKeys,
              maxDepth: maxDepth,
              depth: depth + 1,
              visited: visited,
            );
          }
        }
        return masked;
      } finally {
        visited.remove(value);
      }
    }
    if (value is Iterable) {
      if (!visited.add(value)) {
        return const <String>['[Circular]'];
      }
      try {
        return value
            .map<dynamic>(
              (item) => _maskRecursive(
                item,
                extraKeys: extraKeys,
                maxDepth: maxDepth,
                depth: depth + 1,
                visited: visited,
              ),
            )
            .toList(growable: false);
      } finally {
        visited.remove(value);
      }
    }
    return maskString(value.toString(), extraKeys: extraKeys);
  }
}

/// ログレベル閾値を尊重するカスタム [LogFilter] (#2732)。
class SensitiveLogFilter extends LogFilter {
  final Level? minimumLevel;

  SensitiveLogFilter({this.minimumLevel});

  @override
  bool shouldLog(LogEvent event) {
    final threshold = minimumLevel ?? level ?? Logger.level;
    return event.level.value >= threshold.value;
  }
}
