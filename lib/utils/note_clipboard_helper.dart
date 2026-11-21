import 'package:flutter/services.dart';

/// ノート編集画面でのコピー／切り取り対象の範囲。
enum NoteCopyScope { selection, currentLine, fullText }

/// コピー対象として抽出された文字列とその種別。
class NoteCopyTarget {
  final String text;
  final NoteCopyScope scope;

  const NoteCopyTarget({required this.text, required this.scope});
}

/// 本文からワンタップ抽出・コピーできる項目の種別。
enum NoteCopyableItemKind { keyValue, url, line }

/// 本文から抽出されたコピー候補（ラベル・値・元本文の範囲）。
class NoteCopyableItem {
  final String label;
  final String value;
  final int start;
  final int end;
  final NoteCopyableItemKind kind;

  const NoteCopyableItem({
    required this.label,
    required this.value,
    required this.start,
    required this.end,
    required this.kind,
  });
}

class _KeyValueSpan {
  final String label;
  final int valueStart;
  final int valueEnd;

  const _KeyValueSpan({
    required this.label,
    required this.valueStart,
    required this.valueEnd,
  });
}

/// 切り取り後に反映すべき [TextEditingValue] と切り取った文字列。
class NoteCutResult {
  final String cutText;
  final NoteCopyScope scope;
  final TextEditingValue nextValue;

  const NoteCutResult({
    required this.cutText,
    required this.scope,
    required this.nextValue,
  });
}

/// iOS Safari 等のモバイル環境で不安定な選択・コピペを補う純粋ロジック。
class NoteClipboardHelper {
  const NoteClipboardHelper._();

  /// [text] 上の [offset] が含まれる 1 行分の選択範囲を返す（`\r\n` の `\r` は除外）。
  static TextSelection lineSelectionAt(String text, int offset) {
    if (text.isEmpty) {
      return const TextSelection.collapsed(offset: 0);
    }
    final clamped = offset.clamp(0, text.length);
    var start = clamped;
    while (start > 0 && text[start - 1] != '\n') {
      start--;
    }
    var end = clamped;
    while (end < text.length && text[end] != '\n') {
      end++;
    }
    if (end > start && text[end - 1] == '\r') {
      end--;
    }
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  /// 現在行（空行かつ本文に文字がある場合は全文）を選択した値へ変換する。
  static TextEditingValue selectCurrentLine(TextEditingValue value) {
    if (value.text.isEmpty) {
      return value;
    }
    final anchor = value.selection.isValid ? value.selection.start : 0;
    final lineSel = lineSelectionAt(value.text, anchor);
    if (lineSel.textInside(value.text).trim().isNotEmpty) {
      return value.copyWith(selection: lineSel, composing: TextRange.empty);
    }
    if (value.text.trim().isNotEmpty) {
      return selectAll(value);
    }
    return value;
  }

  /// 本文全体を選択した値へ変換する。
  static TextEditingValue selectAll(TextEditingValue value) {
    return value.copyWith(
      selection: TextSelection(baseOffset: 0, extentOffset: value.text.length),
      composing: TextRange.empty,
    );
  }

  /// 選択中 → 現在行 → 本文全体の優先順でコピー対象を抽出する。
  static NoteCopyTarget? extractCopyTarget(TextEditingValue value) {
    if (value.text.isEmpty) {
      return null;
    }
    final selection = value.selection;
    if (selection.isValid && !selection.isCollapsed) {
      return NoteCopyTarget(
        text: selection.textInside(value.text),
        scope: NoteCopyScope.selection,
      );
    }
    if (selection.isValid) {
      final lineSel = lineSelectionAt(value.text, selection.start);
      final lineText = lineSel.textInside(value.text);
      if (lineText.trim().isNotEmpty) {
        return NoteCopyTarget(text: lineText, scope: NoteCopyScope.currentLine);
      }
    }
    return NoteCopyTarget(text: value.text, scope: NoteCopyScope.fullText);
  }

  /// 選択範囲または現在行を切り取った結果を返す。
  static NoteCutResult? cutTarget(TextEditingValue value) {
    if (value.text.isEmpty) {
      return null;
    }
    final selection = value.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final start = selection.start;
      final end = selection.end;
      final cutText = value.text.substring(start, end);
      final nextText = value.text.replaceRange(start, end, '');
      return NoteCutResult(
        cutText: cutText,
        scope: NoteCopyScope.selection,
        nextValue: value.copyWith(
          text: nextText,
          selection: TextSelection.collapsed(offset: start),
          composing: TextRange.empty,
        ),
      );
    }
    final anchor = selection.isValid ? selection.start : 0;
    final lineSel = lineSelectionAt(value.text, anchor);
    final lineText = lineSel.textInside(value.text);
    if (lineText.trim().isNotEmpty) {
      final start = lineSel.start;
      final nextText = value.text.replaceRange(start, lineSel.end, '');
      return NoteCutResult(
        cutText: lineText,
        scope: NoteCopyScope.currentLine,
        nextValue: value.copyWith(
          text: nextText,
          selection: TextSelection.collapsed(offset: start),
          composing: TextRange.empty,
        ),
      );
    }
    return null;
  }

  /// 選択範囲置換またはカーソル／末尾位置へ [pastedText] を挿入する。
  static TextEditingValue insertPastedText(
    TextEditingValue value,
    String pastedText,
  ) {
    final selection = value.selection;
    if (selection.isValid) {
      final start = selection.start;
      final end = selection.end;
      final nextText = value.text.replaceRange(start, end, pastedText);
      return value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: start + pastedText.length),
        composing: TextRange.empty,
      );
    }
    final nextText = '${value.text}$pastedText';
    return value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
  }

  static final RegExp _urlPattern = RegExp(r'https?://[^\s\u3000]+');

  static bool _isWhitespace(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x3000 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
  }

  static bool _isAsciiDigit(int codeUnit) =>
      codeUnit >= 0x30 && codeUnit <= 0x39;

  static bool _containsWhitespace(String text) {
    for (var i = 0; i < text.length; i++) {
      if (_isWhitespace(text.codeUnitAt(i))) {
        return true;
      }
    }
    return false;
  }

  static bool _isTrailingUrlPunctuation(String ch) => '。、)）]」,.'.contains(ch);

  static _KeyValueSpan? _extractKeyValueOnLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return null;
    }
    var sepIndex = -1;
    for (var i = 0; i < line.length; i++) {
      final unit = line.codeUnitAt(i);
      if (unit == 0x3A) {
        final isScheme =
            i + 2 < line.length && line.substring(i, i + 3) == '://';
        final isTime = i > 0 &&
            i + 1 < line.length &&
            _isAsciiDigit(line.codeUnitAt(i - 1)) &&
            _isAsciiDigit(line.codeUnitAt(i + 1));
        if (!isScheme && !isTime) {
          sepIndex = i;
          break;
        }
      } else if (unit == 0xFF1A || unit == 0x3D) {
        sepIndex = i;
        break;
      }
    }
    if (sepIndex < 0) {
      return null;
    }
    final label = line.substring(0, sepIndex).trim();
    if (label.isEmpty ||
        label.length > 32 ||
        label.contains('http://') ||
        label.contains('https://')) {
      return null;
    }
    var valStart = sepIndex + 1;
    while (valStart < line.length && _isWhitespace(line.codeUnitAt(valStart))) {
      valStart++;
    }
    var valEnd = line.length;
    while (valEnd > valStart && _isWhitespace(line.codeUnitAt(valEnd - 1))) {
      valEnd--;
    }
    if (valEnd <= valStart) {
      return null;
    }
    return _KeyValueSpan(
      label: label,
      valueStart: valStart,
      valueEnd: valEnd,
    );
  }

  /// カーソル付近の「値（`キー: 値`）」または連続トークン（ハイフン入り等）を選択する。
  static TextSelection tokenOrValueSelectionAt(String text, int offset) {
    if (text.isEmpty) {
      return const TextSelection.collapsed(offset: 0);
    }
    final lineSel = lineSelectionAt(text, offset);
    final lineStart = lineSel.start;
    final lineEnd = lineSel.end;
    final line = text.substring(lineStart, lineEnd);
    if (line.trim().isEmpty) {
      return text.trim().isNotEmpty
          ? TextSelection(baseOffset: 0, extentOffset: text.length)
          : const TextSelection.collapsed(offset: 0);
    }
    final kv = _extractKeyValueOnLine(line);
    if (kv != null) {
      final valText = line.substring(kv.valueStart, kv.valueEnd);
      if (offset <= lineStart + kv.valueStart ||
          !_containsWhitespace(valText)) {
        return TextSelection(
          baseOffset: lineStart + kv.valueStart,
          extentOffset: lineStart + kv.valueEnd,
        );
      }
    }
    final rel = (offset - lineStart).clamp(0, line.length);
    var anchor = -1;
    if (rel < line.length && !_isWhitespace(line.codeUnitAt(rel))) {
      anchor = rel;
    } else if (rel > 0 && !_isWhitespace(line.codeUnitAt(rel - 1))) {
      anchor = rel - 1;
    } else {
      for (var i = rel; i < line.length; i++) {
        if (!_isWhitespace(line.codeUnitAt(i))) {
          anchor = i;
          break;
        }
      }
      if (anchor < 0) {
        for (var i = rel - 1; i >= 0; i--) {
          if (!_isWhitespace(line.codeUnitAt(i))) {
            anchor = i;
            break;
          }
        }
      }
    }
    if (anchor < 0) {
      return TextSelection(baseOffset: lineStart, extentOffset: lineEnd);
    }
    var tokStart = anchor;
    while (tokStart > 0 && !_isWhitespace(line.codeUnitAt(tokStart - 1))) {
      tokStart--;
    }
    var tokEnd = anchor + 1;
    while (tokEnd < line.length && !_isWhitespace(line.codeUnitAt(tokEnd))) {
      tokEnd++;
    }
    return TextSelection(
      baseOffset: lineStart + tokStart,
      extentOffset: lineStart + tokEnd,
    );
  }

  /// カーソル付近の値（`キー: 値`）または連続トークンを選択した値へ変換する。
  static TextEditingValue selectTokenOrValue(TextEditingValue value) {
    if (value.text.isEmpty) {
      return value;
    }
    final anchor = value.selection.isValid ? value.selection.start : 0;
    final sel = tokenOrValueSelectionAt(value.text, anchor);
    return value.copyWith(selection: sel, composing: TextRange.empty);
  }

  /// 本文からワンタップでコピーできる値・URL・行の一覧を抽出する。
  static List<NoteCopyableItem> extractCopyableItems(String text) {
    if (text.isEmpty) {
      return const <NoteCopyableItem>[];
    }
    final primaryItems = <NoteCopyableItem>[];
    final lineItems = <NoteCopyableItem>[];
    final seenSpans = <String>{};
    var pos = 0;
    var lineNumber = 0;
    while (pos <= text.length) {
      final nlIndex = text.indexOf('\n', pos);
      final rawEnd = nlIndex < 0 ? text.length : nlIndex;
      var lineEnd = rawEnd;
      if (lineEnd > pos && text.codeUnitAt(lineEnd - 1) == 0x0D) {
        lineEnd--;
      }
      lineNumber++;
      final line = text.substring(pos, lineEnd);
      if (line.trim().isNotEmpty) {
        final kv = _extractKeyValueOnLine(line);
        if (kv != null) {
          final start = pos + kv.valueStart;
          final end = pos + kv.valueEnd;
          if (seenSpans.add('$start:$end')) {
            primaryItems.add(
              NoteCopyableItem(
                label: kv.label,
                value: text.substring(start, end),
                start: start,
                end: end,
                kind: NoteCopyableItemKind.keyValue,
              ),
            );
          }
        }
        for (final match in _urlPattern.allMatches(line)) {
          var urlEnd = match.end;
          while (urlEnd > match.start &&
              _isTrailingUrlPunctuation(line.substring(urlEnd - 1, urlEnd))) {
            urlEnd--;
          }
          if (urlEnd > match.start) {
            final start = pos + match.start;
            final end = pos + urlEnd;
            if (seenSpans.add('$start:$end')) {
              primaryItems.add(
                NoteCopyableItem(
                  label: 'URL',
                  value: text.substring(start, end),
                  start: start,
                  end: end,
                  kind: NoteCopyableItemKind.url,
                ),
              );
            }
          }
        }
        if (seenSpans.add('$pos:$lineEnd')) {
          lineItems.add(
            NoteCopyableItem(
              label: '行 $lineNumber',
              value: line,
              start: pos,
              end: lineEnd,
              kind: NoteCopyableItemKind.line,
            ),
          );
        }
      }
      if (nlIndex < 0) {
        break;
      }
      pos = nlIndex + 1;
    }
    return <NoteCopyableItem>[...primaryItems, ...lineItems];
  }

  /// [current] の始点・終点を [startDelta]/[endDelta] だけ調整し安全にクランプする。
  static TextSelection adjustSelection(
    String text,
    TextSelection current, {
    int startDelta = 0,
    int endDelta = 0,
  }) {
    if (text.isEmpty) {
      return const TextSelection.collapsed(offset: 0);
    }
    final maxLen = text.length;
    var start = current.isValid ? current.start.clamp(0, maxLen) : 0;
    var end = current.isValid ? current.end.clamp(0, maxLen) : maxLen;
    if (end <= start) {
      start = 0;
      end = maxLen;
    }
    if (startDelta != 0) {
      start = (start + startDelta).clamp(0, end > 0 ? end - 1 : 0);
    }
    if (endDelta != 0) {
      final minEnd = start < maxLen ? start + 1 : maxLen;
      end = (end + endDelta).clamp(minEnd, maxLen);
    }
    return TextSelection(baseOffset: start, extentOffset: end);
  }
}
