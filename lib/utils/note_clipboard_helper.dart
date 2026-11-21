import 'package:flutter/services.dart';

/// ノート編集画面でのコピー／切り取り対象の範囲。
enum NoteCopyScope { selection, currentLine, fullText }

/// コピー対象として抽出された文字列とその種別。
class NoteCopyTarget {
  final String text;
  final NoteCopyScope scope;

  const NoteCopyTarget({required this.text, required this.scope});
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
}
