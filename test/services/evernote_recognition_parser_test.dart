import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:my_web_app/services/evernote_recognition_parser.dart';
import 'package:test/test.dart';

const _sampleRecognition = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE recoIndex PUBLIC "SYSTEM" "http://xml.evernote.com/pub/recoIndex.dtd">
<recoIndex
    docType="handwritten"
    objType="image"
    objID="fc83e58282d8059be17debabb69be900"
    engineVersion="5.5.22.7"
    recoType="service"
    lang="ja"
    objWidth="2398"
    objHeight="1798">
  <item x="437" y="589" w="1415" h="190">
    <t w="83">EVER NOTE</t>
    <t w="87">EVERNOTE</t>
    <t w="71">エバーノート</t>
  </item>
  <item x="1850" y="1465" w="14" h="12">
    <t w="11">et</t>
    <t w="10">TQ</t>
  </item>
</recoIndex>''';

void main() {
  group('EvernoteRecognitionParser', () {
    const parser = EvernoteRecognitionParser();

    test('preserves metadata, regions, candidates, and source hash', () {
      final result = parser.parse(_sampleRecognition);

      expect(result.documentType, 'handwritten');
      expect(result.objectType, 'image');
      expect(result.objectId, 'fc83e58282d8059be17debabb69be900');
      expect(result.engineVersion, '5.5.22.7');
      expect(result.recognitionType, 'service');
      expect(result.language, 'ja');
      expect(result.objectWidth, 2398);
      expect(result.objectHeight, 1798);
      expect(
        result.rawSha256,
        sha256.convert(utf8.encode(_sampleRecognition)).toString(),
      );

      expect(result.regions, hasLength(2));
      expect(result.regions.first.x, 437);
      expect(result.regions.first.y, 589);
      expect(result.regions.first.width, 1415);
      expect(result.regions.first.height, 190);
      expect(
        result.regions.first.candidates
            .map((candidate) => (candidate.text, candidate.weight)),
        [
          ('EVER NOTE', 83),
          ('EVERNOTE', 87),
          ('エバーノート', 71),
        ],
      );
      expect(result.regions.first.displayCandidate.text, 'EVERNOTE');
      expect(result.searchText, contains('EVER NOTE EVERNOTE エバーノート'));
      expect(result.searchText, endsWith('et TQ'));
    });

    test('accepts the standard SYSTEM DTD form without resolving it', () {
      const raw =
          '''<!DOCTYPE recoIndex SYSTEM "https://xml.evernote.com/pub/recoIndex.dtd">
<recoIndex><item x="0" y="0" w="1" h="1"><t w="1">safe</t></item></recoIndex>''';

      final result = parser.parse(raw);

      expect(result.regions.single.displayCandidate.text, 'safe');
    });

    test('accepts a recognition index without a DTD', () {
      const raw =
          '<recoIndex><item x="0" y="0" w="1" h="1"><t w="5">plain</t></item></recoIndex>';

      expect(parser.parse(raw).searchText, 'plain');
    });

    test('rejects entity declarations before XML parsing', () {
      const raw = '''<!DOCTYPE recoIndex [
<!ENTITY secret SYSTEM "file:///etc/passwd">
]>
<recoIndex><item x="0" y="0" w="1" h="1"><t w="1">&secret;</t></item></recoIndex>''';

      expect(() => parser.parse(raw), throwsFormatException);
    });

    test('rejects an unexpected external DTD', () {
      const raw =
          '''<!DOCTYPE recoIndex SYSTEM "https://attacker.example/reco.dtd">
<recoIndex><item x="0" y="0" w="1" h="1"><t w="1">unsafe</t></item></recoIndex>''';

      expect(() => parser.parse(raw), throwsFormatException);
    });

    test('rejects includes, unknown elements, and unknown attributes', () {
      const include = '''<recoIndex xmlns:xi="http://www.w3.org/2001/XInclude">
<xi:include href="file:///etc/passwd"/>
</recoIndex>''';
      const element = '<recoIndex><script/></recoIndex>';
      const attribute = '<recoIndex unexpected="value"/>';

      expect(() => parser.parse(include), throwsFormatException);
      expect(() => parser.parse(element), throwsFormatException);
      expect(() => parser.parse(attribute), throwsFormatException);
    });

    test('rejects malformed coordinates and nested candidate elements', () {
      const coordinate =
          '<recoIndex><item x="-1" y="0" w="1" h="1"><t w="1">bad</t></item></recoIndex>';
      const nested =
          '<recoIndex><item x="0" y="0" w="1" h="1"><t w="1"><b>bad</b></t></item></recoIndex>';

      expect(() => parser.parse(coordinate), throwsFormatException);
      expect(() => parser.parse(nested), throwsFormatException);
    });

    test('enforces document, region, candidate, and text limits', () {
      const tinyDocument = EvernoteRecognitionParser(maxCharacters: 8);
      const noRegions = EvernoteRecognitionParser(maxRegions: 0);
      const noCandidates = EvernoteRecognitionParser(maxCandidates: 0);
      const shortCandidates =
          EvernoteRecognitionParser(maxCandidateCharacters: 3);
      const raw =
          '<recoIndex><item x="0" y="0" w="1" h="1"><t w="1">four</t></item></recoIndex>';

      expect(() => tinyDocument.parse(raw), throwsFormatException);
      expect(() => noRegions.parse(raw), throwsFormatException);
      expect(() => noCandidates.parse(raw), throwsFormatException);
      expect(() => shortCandidates.parse(raw), throwsFormatException);
    });

    test('keeps the original candidate order while selecting max weight', () {
      const raw = '''<recoIndex>
<item x="0" y="0" w="1" h="1">
<t w="10">first</t><t w="30">best</t><t w="20">third</t>
</item>
</recoIndex>''';

      final region = parser.parse(raw).regions.single;

      expect(
        region.candidates.map((candidate) => candidate.text),
        ['first', 'best', 'third'],
      );
      expect(region.displayCandidate.text, 'best');
    });
  });
}
