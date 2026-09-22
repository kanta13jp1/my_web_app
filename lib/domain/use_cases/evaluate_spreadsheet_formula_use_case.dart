import '../models/spreadsheet_document.dart';

class SpreadsheetFormulaResult {
  const SpreadsheetFormulaResult({
    required this.displayValue,
    this.numericValue,
    this.isError = false,
  });

  final String displayValue;
  final double? numericValue;
  final bool isError;
}

class EvaluateSpreadsheetFormulaUseCase {
  const EvaluateSpreadsheetFormulaUseCase();

  SpreadsheetFormulaResult call(
    SpreadsheetDocument document,
    CellAddress address,
  ) {
    final input = document.inputAt(address).trim();
    if (input.isEmpty) {
      return const SpreadsheetFormulaResult(displayValue: '');
    }
    if (!input.startsWith('=')) {
      return SpreadsheetFormulaResult(
        displayValue: input,
        numericValue: double.tryParse(input),
      );
    }

    try {
      final value = _evaluateNumeric(document, address, <CellAddress>{});
      return SpreadsheetFormulaResult(
        displayValue: _formatNumber(value),
        numericValue: value,
      );
    } on _FormulaException catch (error) {
      return SpreadsheetFormulaResult(
        displayValue: error.displayValue,
        isError: true,
      );
    }
  }

  double _evaluateNumeric(
    SpreadsheetDocument document,
    CellAddress address,
    Set<CellAddress> visiting,
  ) {
    if (!visiting.add(address)) {
      throw const _FormulaException('#CYCLE!');
    }

    try {
      final input = document.inputAt(address).trim();
      if (input.isEmpty) return 0;
      if (!input.startsWith('=')) {
        final value = double.tryParse(input);
        if (value == null) throw const _FormulaException('#VALUE!');
        return value;
      }

      final parser = _FormulaParser(
        input.substring(1),
        resolveCell: (referencedAddress) =>
            _evaluateNumeric(document, referencedAddress, visiting),
        resolveRange: (start, end) {
          final values = <double>[];
          final firstRow = start.row < end.row ? start.row : end.row;
          final lastRow = start.row > end.row ? start.row : end.row;
          final firstColumn =
              start.column < end.column ? start.column : end.column;
          final lastColumn =
              start.column > end.column ? start.column : end.column;
          for (var row = firstRow; row <= lastRow; row++) {
            for (var column = firstColumn; column <= lastColumn; column++) {
              final cell = CellAddress(row: row, column: column);
              final raw = document.inputAt(cell).trim();
              if (raw.isEmpty) continue;
              if (!raw.startsWith('=')) {
                final value = double.tryParse(raw);
                if (value != null) values.add(value);
                continue;
              }
              values.add(_evaluateNumeric(document, cell, visiting));
            }
          }
          return values;
        },
      );
      final value = parser.parse();
      if (!value.isFinite) throw const _FormulaException('#NUM!');
      return value;
    } finally {
      visiting.remove(address);
    }
  }

  String _formatNumber(double value) {
    final normalized = value.abs() < 0.000000001 ? 0.0 : value;
    if (normalized == normalized.roundToDouble()) {
      return normalized.toInt().toString();
    }
    return normalized
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _FormulaException implements Exception {
  const _FormulaException(this.displayValue);

  final String displayValue;
}

typedef _CellResolver = double Function(CellAddress address);
typedef _RangeResolver = List<double> Function(
  CellAddress start,
  CellAddress end,
);

class _FormulaParser {
  _FormulaParser(
    String source, {
    required _CellResolver resolveCell,
    required _RangeResolver resolveRange,
  })  : _tokens = _FormulaLexer(source).scan(),
        _resolveCell = resolveCell,
        _resolveRange = resolveRange;

  final List<_FormulaToken> _tokens;
  final _CellResolver _resolveCell;
  final _RangeResolver _resolveRange;
  int _current = 0;

  double parse() {
    final value = _expression();
    if (!_check(_FormulaTokenType.end)) {
      throw const _FormulaException('#ERROR!');
    }
    return value;
  }

  double _expression() {
    var value = _term();
    while (_match(<_FormulaTokenType>[
      _FormulaTokenType.plus,
      _FormulaTokenType.minus,
    ])) {
      final operator = _previous.type;
      final right = _term();
      value =
          operator == _FormulaTokenType.plus ? value + right : value - right;
    }
    return value;
  }

  double _term() {
    var value = _unary();
    while (_match(<_FormulaTokenType>[
      _FormulaTokenType.star,
      _FormulaTokenType.slash,
    ])) {
      final operator = _previous.type;
      final right = _unary();
      if (operator == _FormulaTokenType.slash && right == 0) {
        throw const _FormulaException('#DIV/0!');
      }
      value =
          operator == _FormulaTokenType.star ? value * right : value / right;
    }
    return value;
  }

  double _unary() {
    if (_match(<_FormulaTokenType>[_FormulaTokenType.minus])) {
      return -_unary();
    }
    if (_match(<_FormulaTokenType>[_FormulaTokenType.plus])) {
      return _unary();
    }
    return _primary();
  }

  double _primary() {
    if (_match(<_FormulaTokenType>[_FormulaTokenType.number])) {
      return _previous.number!;
    }

    if (_match(<_FormulaTokenType>[_FormulaTokenType.identifier])) {
      final identifier = _previous.lexeme.toUpperCase();
      if (_match(<_FormulaTokenType>[_FormulaTokenType.leftParenthesis])) {
        return _function(identifier);
      }
      final address = CellAddress.tryParse(identifier);
      if (address == null) throw const _FormulaException('#NAME?');
      return _resolveCell(address);
    }

    if (_match(<_FormulaTokenType>[_FormulaTokenType.leftParenthesis])) {
      final value = _expression();
      _consume(_FormulaTokenType.rightParenthesis);
      return value;
    }

    throw const _FormulaException('#ERROR!');
  }

  double _function(String name) {
    final values = <double>[];
    if (!_check(_FormulaTokenType.rightParenthesis)) {
      do {
        if (_isRangeStart()) {
          final start = CellAddress.tryParse(_advance.lexeme)!;
          _consume(_FormulaTokenType.colon);
          final endToken = _consume(_FormulaTokenType.identifier);
          final end = CellAddress.tryParse(endToken.lexeme);
          if (end == null) throw const _FormulaException('#REF!');
          values.addAll(_resolveRange(start, end));
        } else {
          values.add(_expression());
        }
      } while (_match(<_FormulaTokenType>[_FormulaTokenType.comma]));
    }
    _consume(_FormulaTokenType.rightParenthesis);

    return switch (name) {
      'SUM' => values.fold<double>(0, (sum, value) => sum + value),
      'AVERAGE' => values.isEmpty
          ? throw const _FormulaException('#DIV/0!')
          : values.fold<double>(0, (sum, value) => sum + value) / values.length,
      'MIN' => values.isEmpty
          ? 0
          : values.reduce((left, right) => left < right ? left : right),
      'MAX' => values.isEmpty
          ? 0
          : values.reduce((left, right) => left > right ? left : right),
      _ => throw const _FormulaException('#NAME?'),
    };
  }

  bool _isRangeStart() {
    if (!_check(_FormulaTokenType.identifier)) return false;
    if (CellAddress.tryParse(_peek.lexeme) == null) return false;
    return _peekNext.type == _FormulaTokenType.colon;
  }

  bool _match(List<_FormulaTokenType> types) {
    for (final type in types) {
      if (!_check(type)) continue;
      _advance;
      return true;
    }
    return false;
  }

  _FormulaToken _consume(_FormulaTokenType type) {
    if (_check(type)) return _advance;
    throw const _FormulaException('#ERROR!');
  }

  bool _check(_FormulaTokenType type) => _peek.type == type;

  _FormulaToken get _advance {
    if (!_check(_FormulaTokenType.end)) _current++;
    return _previous;
  }

  _FormulaToken get _peek => _tokens[_current];

  _FormulaToken get _peekNext {
    if (_current + 1 >= _tokens.length) return _tokens.last;
    return _tokens[_current + 1];
  }

  _FormulaToken get _previous => _tokens[_current - 1];
}

enum _FormulaTokenType {
  number,
  identifier,
  plus,
  minus,
  star,
  slash,
  leftParenthesis,
  rightParenthesis,
  comma,
  colon,
  end,
}

class _FormulaToken {
  const _FormulaToken(this.type, this.lexeme, [this.number]);

  final _FormulaTokenType type;
  final String lexeme;
  final double? number;
}

class _FormulaLexer {
  const _FormulaLexer(this.source);

  final String source;

  List<_FormulaToken> scan() {
    final tokens = <_FormulaToken>[];
    var current = 0;
    while (current < source.length) {
      final character = source[current];
      if (character.trim().isEmpty) {
        current++;
        continue;
      }
      final simpleType = switch (character) {
        '+' => _FormulaTokenType.plus,
        '-' => _FormulaTokenType.minus,
        '*' => _FormulaTokenType.star,
        '/' => _FormulaTokenType.slash,
        '(' => _FormulaTokenType.leftParenthesis,
        ')' => _FormulaTokenType.rightParenthesis,
        ',' => _FormulaTokenType.comma,
        ':' => _FormulaTokenType.colon,
        _ => null,
      };
      if (simpleType != null) {
        tokens.add(_FormulaToken(simpleType, character));
        current++;
        continue;
      }

      if (_isDigit(character) ||
          (character == '.' &&
              current + 1 < source.length &&
              _isDigit(source[current + 1]))) {
        final start = current;
        var hasDecimalPoint = false;
        while (current < source.length) {
          final next = source[current];
          if (next == '.') {
            if (hasDecimalPoint) break;
            hasDecimalPoint = true;
            current++;
            continue;
          }
          if (!_isDigit(next)) break;
          current++;
        }
        final lexeme = source.substring(start, current);
        tokens.add(
          _FormulaToken(_FormulaTokenType.number, lexeme, double.parse(lexeme)),
        );
        continue;
      }

      if (_isLetter(character)) {
        final start = current;
        while (current < source.length &&
            (_isLetter(source[current]) || _isDigit(source[current]))) {
          current++;
        }
        tokens.add(
          _FormulaToken(
            _FormulaTokenType.identifier,
            source.substring(start, current),
          ),
        );
        continue;
      }

      throw const _FormulaException('#ERROR!');
    }
    tokens.add(const _FormulaToken(_FormulaTokenType.end, ''));
    return tokens;
  }

  bool _isDigit(String value) {
    final unit = value.codeUnitAt(0);
    return unit >= 48 && unit <= 57;
  }

  bool _isLetter(String value) {
    final unit = value.toUpperCase().codeUnitAt(0);
    return unit >= 65 && unit <= 90;
  }
}
