import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/services/structured_tab_catalog_service.dart';
import 'package:my_web_app/domain/models/structured_guitar_tab.dart';

void main() {
  group('StructuredGuitarTabScore', () {
    test('round-trips bundled scores through pretty JSON without data loss',
        () async {
      const catalogService = StructuredTabCatalogService();
      final catalog = await catalogService.loadCatalog();

      expect(catalog, hasLength(2));
      final score = catalog.first;
      final jsonText = score.toPrettyJson();
      final decoded = StructuredGuitarTabScore.parseJsonString(
        jsonText,
        forceUserImported: true,
      );

      expect(decoded.id, score.id);
      expect(decoded.title, score.title);
      expect(decoded.capo, 'Capo fret 3');
      expect(decoded.bpm, 154);
      expect(decoded.isUserImported, isTrue);
      expect(decoded.isOriginalPractice, isFalse);
      expect(decoded.chords, hasLength(5));
      expect(decoded.chords[2].name, 'F');
      expect(decoded.chords[2].barre?.fret, 1);
      expect(decoded.chords[2].barre?.startStringIndex, 0);
      expect(decoded.chords[2].barre?.endStringIndex, 5);
      expect(decoded.measures, hasLength(24));
      expect(decoded.measures[4].hasSegno, isTrue);
      expect(decoded.measures[10].volta, '1.');
      expect(decoded.measures[10].repeatEnd, isTrue);
      expect(decoded.measures[11].volta, '2.');
      expect(decoded.measures[14].topNote, 'Da Coda');
      expect(decoded.measures[19].topNote, 'D.S. al Coda');
      expect(decoded.measures[20].hasCoda, isTrue);
      expect(decoded.measures[20].beats[3].chordSymbol, 'G/B');
    });

    test('throws descriptive FormatException on invalid JSON or values', () {
      expect(
        () => StructuredGuitarTabScore.parseJsonString(''),
        throwsFormatException,
      );
      expect(
        () => StructuredGuitarTabScore.parseJsonString('{invalid'),
        throwsFormatException,
      );
      expect(
        () => StructuredGuitarTabScore.parseJsonString(
          '{"id":"x","title":"t","bpm":120,"measures":[]}',
        ),
        throwsFormatException,
      );
      expect(
        () => StructuredGuitarTabScore.parseJsonString(
          '{"id":"x","title":"t","bpm":999,"measures":[{"number":1,"beats":[{"kind":"rest","duration":"quarter"}]}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => StructuredGuitarTabScore.parseJsonString(
          '{"id":"x","title":"t","bpm":120,"chords":[{"name":"C","frets":[-1,3,2]}],"measures":[{"number":1,"beats":[{"kind":"rest","duration":"quarter"}]}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => StructuredGuitarTabScore.parseJsonString(
          '{"id":"x","title":"t","bpm":120,"chords":[{"name":"F","frets":[1,3,3,2,1,1],"barre":{"fret":1,"startStringIndex":4,"endStringIndex":1}}],"measures":[{"number":1,"beats":[{"kind":"rest","duration":"quarter"}]}]}',
        ),
        throwsFormatException,
      );
    });

    test('expands repeats, 1st/2nd voltas, and D.S. al Coda navigation',
        () async {
      const catalogService = StructuredTabCatalogService();
      final score = (await catalogService.loadCatalog()).first;
      final timeline = expandStructuredTabTimeline(score);

      expect(timeline, isNotEmpty);

      final measureVisitOrder = <int>[];
      for (final step in timeline) {
        if (measureVisitOrder.isEmpty ||
            measureVisitOrder.last != step.measureNumber) {
          measureVisitOrder.add(step.measureNumber);
        }
      }

      // Intro(1..4)x2 -> [A](5..11 -> 5..10 -> 12) -> [B](13..16) -> [C](17..20)
      // -> D.S. to 5..10 -> 12..15 (Da Coda) -> Coda 21..24 -> Fade repeat 23..24
      expect(
        measureVisitOrder,
        <int>[
          1,
          2,
          3,
          4,
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          5,
          6,
          7,
          8,
          9,
          10,
          12,
          13,
          14,
          15,
          16,
          17,
          18,
          19,
          20,
          5,
          6,
          7,
          8,
          9,
          10,
          12,
          13,
          14,
          15,
          21,
          22,
          23,
          24,
          23,
          24,
        ],
      );
    });

    test('caps measure visits to prevent infinite loops', () {
      final score = StructuredGuitarTabScore(
        id: 'loop-guard',
        title: 'Loop Guard',
        artist: 'Test',
        tuning: 'Standard',
        capo: 'なし',
        bpm: 120,
        chords: const <StructuredChordDiagram>[],
        measures: <StructuredTabMeasure>[
          StructuredTabMeasure(
            number: 1,
            hasSegno: true,
            topNote: 'D.S. al Coda',
            beats: <StructuredTabBeat>[
              StructuredTabBeat(
                kind: StructuredTabBeatKind.rest,
                duration: StructuredTabDuration.quarter,
              ),
            ],
          ),
        ],
      );

      expect(expandStructuredTabTimeline(score, maxMeasureVisits: 1),
          hasLength(1));
      expect(expandStructuredTabTimeline(score, maxMeasureVisits: 5),
          hasLength(2));
    });
  });
}
