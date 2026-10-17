import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enml_markdown_converter.dart';

void main() {
  const converter = EvernoteEnmlMarkdownConverter();
  for (final wrapper in <String>['table', 'blockquote']) {
    String wrap(String content) => wrapper == 'table'
        ? '<table><tr><td>$content</td></tr></table>'
        : '<blockquote>$content</blockquote>';
    test('$wrapper retains attachment position and formatted text', () {
      final result = converter.convert(
        enml: '<en-note>${wrap('before <b>bold</b> <en-media hash="abc"/> after')}</en-note>',
        resources: const <EvernoteEnmlResourceReference>[
          EvernoteEnmlResourceReference(
            hash: 'abc', mimeType: 'image/png', label: 'sample',
          ),
        ],
      );
      expect(result.markdown, contains('before **bold** ![sample](evernote-resource:abc) after'));
      expect(result.unresolvedResourceHashes, isEmpty);
      expect(result.encryptedSectionCount, 0);
    });
    test('$wrapper propagates unresolved media and encrypted warnings', () {
      final result = converter.convert(
        enml: '<en-note>${wrap('<en-media hash="missing"/><en-crypt>ciphertext</en-crypt>')}</en-note>',
        resources: const <EvernoteEnmlResourceReference>[],
      );
      expect(result.unresolvedResourceHashes, <String>['missing']);
      expect(result.encryptedSectionCount, 1);
      expect(result.markdown, contains('Unresolved Evernote attachment'));
      expect(result.markdown, contains('Encrypted Evernote content'));
      expect(result.markdown, isNot(contains('ciphertext')));
    });
  }
}