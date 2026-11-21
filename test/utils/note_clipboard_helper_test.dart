import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/note_clipboard_helper.dart';

void main() {
  group('NoteClipboardHelper', () {
    test('selectCurrentLine expands partial URL to whole line', () {
      const text = 'line1\nhttps://mightylink-app.com/\nline3';
      final startOfCom = text.indexOf('com/');
      final partial = TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: startOfCom,
          extentOffset: startOfCom + 4,
        ),
      );

      final selected = NoteClipboardHelper.selectCurrentLine(partial);
      expect(
        selected.selection.textInside(selected.text),
        'https://mightylink-app.com/',
      );
    });

    test('lineSelectionAt strips trailing carriage return on CRLF', () {
      const text = 'first\r\nsecond\r\n';
      final selection = NoteClipboardHelper.lineSelectionAt(text, 9);
      expect(selection.textInside(text), 'second');
    });

    test('selectCurrentLine falls back to full text when on an empty line', () {
      const text = 'first line\n\nthird line';
      final onEmptyLine = text.indexOf('\n\n') + 1;
      final selected = NoteClipboardHelper.selectCurrentLine(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: onEmptyLine),
        ),
      );
      expect(selected.selection.textInside(selected.text), text);
    });

    test('extractCopyTarget follows selection -> line -> full priority', () {
      const text = 'first\nhttps://mightylink-app.com/\nthird';
      final selResult = NoteClipboardHelper.extractCopyTarget(
        const TextEditingValue(
          text: text,
          selection: TextSelection(baseOffset: 0, extentOffset: 5),
        ),
      );
      expect(selResult?.scope, NoteCopyScope.selection);
      expect(selResult?.text, 'first');

      final lineOffset = text.indexOf('mightylink');
      final lineResult = NoteClipboardHelper.extractCopyTarget(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: lineOffset),
        ),
      );
      expect(lineResult?.scope, NoteCopyScope.currentLine);
      expect(lineResult?.text, 'https://mightylink-app.com/');

      final fullResult = NoteClipboardHelper.extractCopyTarget(
        const TextEditingValue(text: 'only line'),
      );
      expect(fullResult?.scope, NoteCopyScope.fullText);
      expect(fullResult?.text, 'only line');

      expect(
        NoteClipboardHelper.extractCopyTarget(const TextEditingValue(text: '')),
        isNull,
      );
    });

    test('insertPastedText replaces, inserts, and appends', () {
      final atCursor = NoteClipboardHelper.insertPastedText(
        const TextEditingValue(
          text: 'hello world',
          selection: TextSelection.collapsed(offset: 6),
        ),
        'Flutter ',
      );
      expect(atCursor.text, 'hello Flutter world');
      expect(atCursor.selection.baseOffset, 14);

      final replaced = NoteClipboardHelper.insertPastedText(
        const TextEditingValue(
          text: 'hello world',
          selection: TextSelection(baseOffset: 6, extentOffset: 11),
        ),
        'iPhone',
      );
      expect(replaced.text, 'hello iPhone');

      final appended = NoteClipboardHelper.insertPastedText(
        const TextEditingValue(text: 'abc'),
        'def',
      );
      expect(appended.text, 'abcdef');
      expect(appended.selection.baseOffset, 6);
    });

    test('cutTarget cuts active selection or current non-empty line', () {
      final cutSelection = NoteClipboardHelper.cutTarget(
        const TextEditingValue(
          text: 'alpha beta',
          selection: TextSelection(baseOffset: 0, extentOffset: 6),
        ),
      );
      expect(cutSelection?.scope, NoteCopyScope.selection);
      expect(cutSelection?.cutText, 'alpha ');
      expect(cutSelection?.nextValue.text, 'beta');

      final cutLine = NoteClipboardHelper.cutTarget(
        const TextEditingValue(
          text: 'line1\nline2',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(cutLine?.scope, NoteCopyScope.currentLine);
      expect(cutLine?.cutText, 'line1');
      expect(cutLine?.nextValue.text, '\nline2');
    });

    test('selectAll selects full content', () {
      final selected = NoteClipboardHelper.selectAll(
        const TextEditingValue(text: 'abc\ndef'),
      );
      expect(selected.selection.start, 0);
      expect(selected.selection.end, 7);
    });
  });
}
