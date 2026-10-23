import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enml_markdown_converter.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';

void main() {
  for (final wrapper in <String>['pre', 'a']) {
    test('$wrapper blocks media even when attachment bytes are available', () {
      final result = const EvernoteEnmlMarkdownConverter().convert(
        enml: '<en-note><$wrapper><en-media hash="abc"/></$wrapper></en-note>',
        resources: const <EvernoteEnmlResourceReference>[
          EvernoteEnmlResourceReference(
            hash: 'abc',
            mimeType: 'image/png',
            label: 'fixture',
          ),
        ],
      );
      expect(
        result.unresolvedResourceHashes,
        contains('<unsupported-media-context>'),
      );
    });
    test('$wrapper media loss propagates a parser warning', () {
      final result = const EvernoteEnexParser().parseText(
        '<en-export><note><title>fixture</title><content><![CDATA['
        '<en-note><$wrapper><en-media hash="abc"/></$wrapper></en-note>'
        ']]></content></note></en-export>',
      );
      expect(
        result.warnings,
        anyElement(contains('could not be safely represented')),
      );
    });
  }
}
