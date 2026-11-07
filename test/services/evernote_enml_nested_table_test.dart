import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enml_markdown_converter.dart';

void main() {
  test('nested table rows do not duplicate their attachment or content', () {
    final result = const EvernoteEnmlMarkdownConverter().convert(
      enml: '<en-note><table><tr><td>outer<table><tr><td>inner'
          '<en-media hash="abc"/><en-crypt>ciphertext</en-crypt>'
          '</td></tr></table></td></tr></table></en-note>',
      resources: const <EvernoteEnmlResourceReference>[
        EvernoteEnmlResourceReference(
          hash: 'abc',
          mimeType: 'image/png',
          label: 'fixture',
        ),
      ],
    );
    expect('evernote-resource:abc'.allMatches(result.markdown).length, 1);
    expect('inner'.allMatches(result.markdown).length, 1);
    expect(result.encryptedSectionCount, 1);
    expect(result.unresolvedResourceHashes, isEmpty);
    expect(result.markdown, isNot(contains('ciphertext')));
  });
}
