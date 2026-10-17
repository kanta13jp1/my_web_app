import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enml_markdown_converter.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';

void main() {
  for (final wrapper in <String>['pre', 'a']) {
    final content = '<en-note><$wrapper>'
        '<en-crypt>ciphertext</en-crypt></$wrapper></en-note>';
    test('$wrapper cannot hide encrypted content from the safety inventory', () {
      final result = const EvernoteEnmlMarkdownConverter().convert(
        enml: content,
        resources: const <EvernoteEnmlResourceReference>[],
      );
      expect(result.encryptedSectionCount, 1);
    });
    test('$wrapper encryption reaches the parser commit-blocking warning', () {
      final export = const EvernoteEnexParser().parseText(
        '<en-export><note><title>fixture</title><content><![CDATA['
        '$content]]></content></note></en-export>',
      );
      expect(
        export.warnings,
        anyElement(contains('encrypted ENML section(s)')),
      );
    });
  }
}
