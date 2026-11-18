import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_enml_markdown_converter.dart';
import 'package:my_web_app/services/evernote_enex_parser.dart';

void main() {
  test('pre blocks media even when attachment bytes are available', () {
    final result = const EvernoteEnmlMarkdownConverter().convert(
      enml: '<en-note><pre><en-media hash="abc"/></pre></en-note>',
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

  test('pre media loss propagates a parser warning', () {
    final result = const EvernoteEnexParser().parseText(
      '<en-export><note><title>fixture</title><content><![CDATA['
      '<en-note><pre><en-media hash="abc"/></pre></en-note>'
      ']]></content></note></en-export>',
    );
    expect(
      result.warnings,
      anyElement(contains('could not be safely represented')),
    );
  });

  test('a preserves media reference and link href without warning', () {
    final result = const EvernoteEnmlMarkdownConverter().convert(
      enml:
          '<en-note><a href="https://example.com"><en-media hash="abc" type="image/png"/></a></en-note>',
      resources: const <EvernoteEnmlResourceReference>[
        EvernoteEnmlResourceReference(
          hash: 'abc',
          mimeType: 'image/png',
          label: 'fixture',
        ),
      ],
    );
    expect(result.unresolvedResourceHashes, isEmpty);
    expect(result.markdown, contains('evernote-resource:abc'));
    expect(result.markdown, contains('https://example.com'));
  });
}
