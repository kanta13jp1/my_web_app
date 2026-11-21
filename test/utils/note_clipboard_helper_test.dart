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

    test('selectTokenOrValue selects full hyphenated password value', () {
      const text = 'パスワード: t-C22P7VKxxhCyRB7a3kZyG5K-6ihKPuWJ';
      final partialStart = text.indexOf('6ihKPuWJ');
      final partial = NoteClipboardHelper.selectTokenOrValue(
        TextEditingValue(
          text: text,
          selection: TextSelection(
            baseOffset: partialStart,
            extentOffset: partialStart + 8,
          ),
        ),
      );
      expect(
        partial.selection.textInside(text),
        't-C22P7VKxxhCyRB7a3kZyG5K-6ihKPuWJ',
      );

      final onLabel = NoteClipboardHelper.selectTokenOrValue(
        const TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(
        onLabel.selection.textInside(text),
        't-C22P7VKxxhCyRB7a3kZyG5K-6ihKPuWJ',
      );
    });

    test('selectTokenOrValue handles full-width colon, URL, and prose', () {
      const fullWidth = 'ユーザー名：ml_user-123';
      expect(
        NoteClipboardHelper.selectTokenOrValue(
          const TextEditingValue(
            text: fullWidth,
            selection: TextSelection.collapsed(offset: 8),
          ),
        ).selection.textInside(fullWidth),
        'ml_user-123',
      );

      const urlOnly = 'https://mightylink-app.com/a-b';
      expect(
        NoteClipboardHelper.selectTokenOrValue(
          const TextEditingValue(
            text: urlOnly,
            selection: TextSelection.collapsed(offset: 12),
          ),
        ).selection.textInside(urlOnly),
        urlOnly,
      );

      const prose = 'コメント: Hello world-wide test';
      final offsetInWord = prose.indexOf('wide');
      expect(
        NoteClipboardHelper.selectTokenOrValue(
          TextEditingValue(
            text: prose,
            selection: TextSelection.collapsed(offset: offsetInWord),
          ),
        ).selection.textInside(prose),
        'world-wide',
      );
    });

    test('extractCopyableItems extracts keyValues, URLs, and lines', () {
      const text = '18:28 メモ\n'
          'ユーザー名: ml_user_1\n'
          'パスワード: pass-123-xyz\n'
          '詳細（https://mightylink-app.com/login）。\n'
          'https://example.com/\n'
          '末尾メモ';
      final items = NoteClipboardHelper.extractCopyableItems(text);
      final primaries = items
          .where((e) => e.kind != NoteCopyableItemKind.line)
          .toList();
      final lines = items
          .where((e) => e.kind == NoteCopyableItemKind.line)
          .toList();

      expect(
        primaries.map((e) => '${e.label}=${e.value}').toList(),
        const [
          'ユーザー名=ml_user_1',
          'パスワード=pass-123-xyz',
          'URL=https://mightylink-app.com/login',
          'URL=https://example.com/',
        ],
      );
      expect(
        lines.map((e) => e.value).toList(),
        const [
          '18:28 メモ',
          'ユーザー名: ml_user_1',
          'パスワード: pass-123-xyz',
          '詳細（https://mightylink-app.com/login）。',
          '末尾メモ',
        ],
      );
    });

    test('adjustSelection moves boundaries safely without inversion', () {
      const text = 'abcdef';
      final moved = NoteClipboardHelper.adjustSelection(
        text,
        const TextSelection(baseOffset: 1, extentOffset: 4),
        startDelta: 1,
        endDelta: 2,
      );
      expect(moved.start, 2);
      expect(moved.end, 6);

      final clamped = NoteClipboardHelper.adjustSelection(
        text,
        const TextSelection(baseOffset: 2, extentOffset: 3),
        startDelta: 5,
      );
      expect(clamped.start, 2);
      expect(clamped.end, 3);
    });
  });
}
