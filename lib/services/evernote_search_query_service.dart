class EvernoteSearchDocument {
  const EvernoteSearchDocument({
    required this.title,
    required this.content,
    required this.tags,
    this.notebookName,
    this.stackName,
    this.createdAt,
    this.updatedAt,
    this.reminderTime,
    this.resourceMimeTypes = const <String>[],
    this.source,
    this.hasEncryptedText = false,
    this.hasCheckedTodo = false,
    this.hasUncheckedTodo = false,
    this.containsTypes = const <String>{},
  });

  final String title;
  final String content;
  final List<String> tags;
  final String? notebookName;
  final String? stackName;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reminderTime;
  final List<String> resourceMimeTypes;
  final String? source;
  final bool hasEncryptedText;
  final bool hasCheckedTodo;
  final bool hasUncheckedTodo;
  final Set<String> containsTypes;
}

class EvernoteSearchQuery {
  const EvernoteSearchQuery._({
    required this.raw,
    required this.isAdvanced,
    required this.unsupportedOperators,
    required this.errors,
    required _SearchExpression? expression,
  }) : _expression = expression;

  final String raw;
  final bool isAdvanced;
  final List<String> unsupportedOperators;
  final List<String> errors;
  final _SearchExpression? _expression;

  bool get isFullySupported =>
      errors.isEmpty && unsupportedOperators.isEmpty && _expression != null;

  bool get requiresStoredFeatures => RegExp(
        r'(^|\s|\()(?:(?:resource|source|todo|encryption|contains):)',
        caseSensitive: false,
      ).hasMatch(raw);

  bool matches(
    EvernoteSearchDocument document, {
    DateTime? now,
  }) {
    if (raw.trim().isEmpty) return true;
    if (!isFullySupported) {
      // Never pretend that a partly supported Evernote query is exact.
      // The caller must surface unsupportedOperators/errors and leave the
      // result set unfiltered.
      return true;
    }
    return _expression!.evaluate(document, now ?? DateTime.now());
  }
}

class EvernoteSearchQueryService {
  const EvernoteSearchQueryService._();

  static const Set<String> supportedOperators = <String>{
    'intitle',
    'notebook',
    'stack',
    'tag',
    'created',
    'updated',
    'remindertime',
    'resource',
    'source',
    'todo',
    'encryption',
    'contains',
  };

  static const Set<String> supportedContainsTypes = <String>{
    'address',
    'filearchive',
    'attachment',
    'fileaudio',
    'calendarevent',
    'entodo',
    'encodeblock',
    'contact',
    'date',
    'filedocument',
    'email',
    'encrypt',
    'urlgoogledrive',
    'fileimage',
    'numberinteger',
    'list',
    'numberreal',
    'fileoffice',
    'filepdf',
    'numberpercent',
    'person',
    'phonenumber',
    'filepresentation',
    'numberprice',
    'filespreadsheet',
    'table',
    'task',
    'taskcompleted',
    'tasknotcompleted',
    'time',
    'url',
    'filevideo',
  };

  static EvernoteSearchQuery parse(String raw) {
    final lexer = _SearchLexer(raw);
    final rawTokens = lexer.scan();
    final errors = <String>[...lexer.errors];
    var defaultOperator = _TokenKind.and;

    final tokens = <_SearchToken>[];
    for (final token in rawTokens) {
      if (token.kind == _TokenKind.atom &&
          token.value.toLowerCase() == 'any:') {
        defaultOperator = _TokenKind.or;
        continue;
      }
      tokens.add(token);
    }

    final withImplicitOperators = <_SearchToken>[];
    for (final token in tokens) {
      if (withImplicitOperators.isNotEmpty &&
          _endsOperand(withImplicitOperators.last.kind) &&
          _startsOperand(token.kind)) {
        withImplicitOperators.add(
          _SearchToken(defaultOperator, defaultOperator.name.toUpperCase()),
        );
      }
      withImplicitOperators.add(token);
    }

    final unsupported = <String>{};
    final parser = _SearchParser(
      withImplicitOperators,
      errors: errors,
      unsupportedOperators: unsupported,
    );
    final expression = parser.parse();

    final isAdvanced = rawTokens.any((token) {
      if (token.kind != _TokenKind.atom) return true;
      final value = token.value;
      return value.toLowerCase() == 'any:' ||
          value.startsWith('-') ||
          value.contains('"') ||
          value.contains('*') ||
          _modifierName(value) != null;
    });

    return EvernoteSearchQuery._(
      raw: raw,
      isAdvanced: isAdvanced,
      unsupportedOperators: List<String>.unmodifiable(
        unsupported.toList()..sort(),
      ),
      errors: List<String>.unmodifiable(errors),
      expression: expression,
    );
  }

  static bool _endsOperand(_TokenKind kind) =>
      kind == _TokenKind.atom || kind == _TokenKind.rightParen;

  static bool _startsOperand(_TokenKind kind) =>
      kind == _TokenKind.atom ||
      kind == _TokenKind.leftParen ||
      kind == _TokenKind.not;
}

enum _TokenKind { atom, and, or, not, leftParen, rightParen }

class _SearchToken {
  const _SearchToken(this.kind, this.value);

  final _TokenKind kind;
  final String value;
}

class _SearchLexer {
  _SearchLexer(this.source);

  final String source;
  final List<String> errors = <String>[];

  List<_SearchToken> scan() {
    final tokens = <_SearchToken>[];
    final buffer = StringBuffer();
    var quoted = false;

    void flush() {
      if (buffer.isEmpty) return;
      final value = buffer.toString();
      buffer.clear();
      tokens.add(_classify(value));
    }

    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (character == '"') {
        quoted = !quoted;
        buffer.write(character);
        continue;
      }
      if (!quoted && _isWhitespace(character)) {
        flush();
        continue;
      }
      if (!quoted && (character == '(' || character == ')')) {
        flush();
        tokens.add(
          _SearchToken(
            character == '(' ? _TokenKind.leftParen : _TokenKind.rightParen,
            character,
          ),
        );
        continue;
      }
      buffer.write(character);
    }
    flush();
    if (quoted) {
      errors.add('引用符が閉じられていません。');
    }
    return tokens;
  }

  _SearchToken _classify(String value) {
    return switch (value) {
      'AND' => const _SearchToken(_TokenKind.and, 'AND'),
      'OR' => const _SearchToken(_TokenKind.or, 'OR'),
      'NOT' => const _SearchToken(_TokenKind.not, 'NOT'),
      _ => _SearchToken(_TokenKind.atom, value),
    };
  }

  bool _isWhitespace(String value) => value.trim().isEmpty;
}

class _SearchParser {
  _SearchParser(
    this.tokens, {
    required this.errors,
    required this.unsupportedOperators,
  });

  final List<_SearchToken> tokens;
  final List<String> errors;
  final Set<String> unsupportedOperators;
  var _current = 0;

  _SearchExpression? parse() {
    if (tokens.isEmpty) return const _MatchAllExpression();
    final expression = _parseOr();
    if (!_isAtEnd) {
      errors.add('検索式を最後まで解釈できませんでした。');
    }
    return errors.isEmpty ? expression : null;
  }

  _SearchExpression _parseOr() {
    var expression = _parseAnd();
    while (_match(_TokenKind.or)) {
      expression = _BinaryExpression(
        left: expression,
        operator: _TokenKind.or,
        right: _parseAnd(),
      );
    }
    return expression;
  }

  _SearchExpression _parseAnd() {
    var expression = _parseUnary();
    while (_match(_TokenKind.and)) {
      expression = _BinaryExpression(
        left: expression,
        operator: _TokenKind.and,
        right: _parseUnary(),
      );
    }
    return expression;
  }

  _SearchExpression _parseUnary() {
    if (_match(_TokenKind.not)) {
      return _NotExpression(_parseUnary());
    }
    if (_check(_TokenKind.atom) && _peek.value.startsWith('-')) {
      final value = _advance().value.substring(1);
      if (value.isEmpty) {
        errors.add('除外記号の後に検索条件が必要です。');
        return const _MatchAllExpression();
      }
      return _NotExpression(_atom(value));
    }
    return _parsePrimary();
  }

  _SearchExpression _parsePrimary() {
    if (_match(_TokenKind.leftParen)) {
      final expression = _parseOr();
      if (!_match(_TokenKind.rightParen)) {
        errors.add('右括弧が不足しています。');
      }
      return expression;
    }
    if (_match(_TokenKind.atom)) {
      return _atom(_previous.value);
    }
    if (!_isAtEnd) {
      errors.add('演算子の位置が不正です: \${_advance().value}');
    } else {
      errors.add('検索条件が不足しています。');
    }
    return const _MatchAllExpression();
  }

  _SearchExpression _atom(String token) {
    final modifier = _modifierName(token);
    String value = token;
    if (modifier != null) {
      value = token.substring(token.indexOf(':') + 1);
      if (!EvernoteSearchQueryService.supportedOperators.contains(modifier)) {
        unsupportedOperators.add(modifier);
        return const _MatchAllExpression();
      }
      if (value.isEmpty && modifier != 'encryption') {
        errors.add('$modifier: の値が不足しています。');
        return const _MatchAllExpression();
      }
    }

    final quoted =
        value.length >= 2 && value.startsWith('"') && value.endsWith('"');
    if (value.contains('"') && !quoted) {
      errors.add('引用符は検索語または演算子の値全体を囲んでください。');
    }
    final unquoted = quoted ? value.substring(1, value.length - 1) : value;
    if (unquoted.trim().isEmpty && modifier != 'encryption') {
      errors.add('空の検索語は使用できません。');
    }
    if (unquoted.contains('*') && !unquoted.endsWith('*')) {
      errors.add('ワイルドカードは検索語の末尾でのみ使用できます。');
    }
    if (modifier == 'todo' &&
        !const <String>{'true', 'false', '*'}.contains(
          unquoted.toLowerCase(),
        )) {
      errors.add('todo: は true、false、* のいずれかを指定してください。');
    }
    if (modifier == 'contains' &&
        !EvernoteSearchQueryService.supportedContainsTypes.contains(
          unquoted.toLowerCase(),
        )) {
      errors.add('contains: の種別が不正です。');
    }
    if (modifier == 'created' ||
        modifier == 'updated' ||
        modifier == 'remindertime') {
      if (_relativeDateThreshold(unquoted, DateTime(2024)) == null) {
        errors.add('$modifier: の日付形式が不正です。');
      }
    }
    return _AtomExpression(
      modifier: modifier,
      value: unquoted,
      exactPhrase: quoted,
      wildcard: unquoted.endsWith('*'),
    );
  }

  bool _match(_TokenKind kind) {
    if (!_check(kind)) return false;
    _advance();
    return true;
  }

  bool _check(_TokenKind kind) => !_isAtEnd && _peek.kind == kind;

  _SearchToken _advance() {
    if (!_isAtEnd) _current++;
    return _previous;
  }

  bool get _isAtEnd => _current >= tokens.length;
  _SearchToken get _peek => tokens[_current];
  _SearchToken get _previous => tokens[_current - 1];
}

abstract class _SearchExpression {
  const _SearchExpression();

  bool evaluate(EvernoteSearchDocument document, DateTime now);
}

class _MatchAllExpression extends _SearchExpression {
  const _MatchAllExpression();

  @override
  bool evaluate(EvernoteSearchDocument document, DateTime now) => true;
}

class _NotExpression extends _SearchExpression {
  const _NotExpression(this.expression);

  final _SearchExpression expression;

  @override
  bool evaluate(EvernoteSearchDocument document, DateTime now) =>
      !expression.evaluate(document, now);
}

class _BinaryExpression extends _SearchExpression {
  const _BinaryExpression({
    required this.left,
    required this.operator,
    required this.right,
  });

  final _SearchExpression left;
  final _TokenKind operator;
  final _SearchExpression right;

  @override
  bool evaluate(EvernoteSearchDocument document, DateTime now) {
    if (operator == _TokenKind.and) {
      return left.evaluate(document, now) && right.evaluate(document, now);
    }
    return left.evaluate(document, now) || right.evaluate(document, now);
  }
}

class _AtomExpression extends _SearchExpression {
  const _AtomExpression({
    required this.modifier,
    required this.value,
    required this.exactPhrase,
    required this.wildcard,
  });

  final String? modifier;
  final String value;
  final bool exactPhrase;
  final bool wildcard;

  @override
  bool evaluate(EvernoteSearchDocument document, DateTime now) {
    final target = wildcard ? value.substring(0, value.length - 1) : value;
    switch (modifier) {
      case 'intitle':
        return _matchesText(document.title, target, exactPhrase, wildcard);
      case 'notebook':
        return _matchesName(document.notebookName, target, wildcard);
      case 'stack':
        return _matchesName(document.stackName, target, wildcard);
      case 'tag':
        if (target == '') return document.tags.isNotEmpty;
        return document.tags.any(
          (tag) => _matchesName(tag, target, wildcard),
        );
      case 'created':
        return _matchesDate(document.createdAt, target, now);
      case 'updated':
        return _matchesDate(document.updatedAt, target, now);
      case 'remindertime':
        if (target == '' || target == '*') {
          return document.reminderTime != null;
        }
        return _matchesDate(document.reminderTime, target, now);
      case 'resource':
        return document.resourceMimeTypes.any(
          (mime) => _matchesName(mime, target, wildcard),
        );
      case 'source':
        return _matchesName(document.source, target, wildcard);
      case 'todo':
        return switch (target.toLowerCase()) {
          'true' => document.hasCheckedTodo,
          'false' => document.hasUncheckedTodo,
          '*' => document.hasCheckedTodo || document.hasUncheckedTodo,
          _ => false,
        };
      case 'encryption':
        return document.hasEncryptedText;
      case 'contains':
        return document.containsTypes.contains(target.toLowerCase());
      case null:
        final fields = <String>[
          document.title,
          document.content,
          ...document.tags,
        ];
        return fields.any(
          (field) => _matchesText(field, target, exactPhrase, wildcard),
        );
    }
    return true;
  }

  bool _matchesDate(DateTime? actual, String rawThreshold, DateTime now) {
    if (actual == null) return false;
    final threshold = _relativeDateThreshold(rawThreshold, now);
    return threshold != null && !actual.isBefore(threshold);
  }

  bool _matchesName(String? actual, String expected, bool isWildcard) {
    if (actual == null) return false;
    final foldedActual = actual.trim().toLowerCase();
    final foldedExpected = expected.trim().toLowerCase();
    return isWildcard
        ? foldedActual.startsWith(foldedExpected)
        : foldedActual == foldedExpected;
  }

  bool _matchesText(
    String actual,
    String expected,
    bool phrase,
    bool isWildcard,
  ) {
    final expectedWords = _searchWords(expected);
    if (expectedWords.isEmpty) return false;
    final actualWords = _searchWords(actual);
    if (phrase) {
      return actualWords.join(' ').contains(expectedWords.join(' '));
    }
    final needle = expectedWords.first;
    return actualWords.any(
      (word) => isWildcard ? word.startsWith(needle) : word == needle,
    );
  }
}

String? _modifierName(String token) {
  final separator = token.indexOf(':');
  if (separator <= 0) return null;
  final candidate = token.substring(0, separator);
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(candidate)) {
    return null;
  }
  return candidate.toLowerCase();
}

List<String> _searchWords(String value) {
  return RegExp(r'[A-Za-z0-9_\u0080-\uFFFF]+', unicode: true)
      .allMatches(value.toLowerCase())
      .map((match) => match.group(0)!)
      .toList(growable: false);
}

DateTime? _relativeDateThreshold(String value, DateTime now) {
  final absolute = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
  if (absolute != null) {
    final year = int.parse(absolute.group(1)!);
    final month = int.parse(absolute.group(2)!);
    final day = int.parse(absolute.group(3)!);
    final candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return candidate;
  }

  final relative =
      RegExp(r'^(day|week|month|year)(?:-([0-9]+))?$').firstMatch(value);
  if (relative == null) return null;
  final count = int.tryParse(relative.group(2) ?? '0');
  if (count == null) return null;

  switch (relative.group(1)) {
    case 'day':
      return DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: count));
    case 'week':
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfToday.subtract(
        Duration(days: startOfToday.weekday - DateTime.monday),
      );
      return startOfWeek.subtract(Duration(days: count * 7));
    case 'month':
      return DateTime(now.year, now.month - count);
    case 'year':
      return DateTime(now.year - count);
  }
  return null;
}
