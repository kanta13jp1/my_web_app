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

      expect(
        expandStructuredTabTimeline(score, maxMeasureVisits: 1),
        hasLength(1),
      );
      expect(
        expandStructuredTabTimeline(score, maxMeasureVisits: 5),
        hasLength(2),
      );
    });

    test('enforces JSON size, element count, and string length limits', () {
      expect(
        () => StructuredGuitarTabScore.parseJsonString(
          ' ' * (StructuredGuitarTabScore.maxJsonLength + 1),
        ),
        throwsFormatException,
      );

      final tooManyChords = <Map<String, Object?>>[
        for (var i = 0; i <= StructuredGuitarTabScore.maxChordsCount; i++)
          <String, Object?>{
            'name': 'C$i',
            'frets': <int>[-1, 3, 2, 0, 1, 0],
          },
      ];
      expect(
        () => StructuredGuitarTabScore.fromJson(<String, Object?>{
          'id': 'too-many-chords',
          'title': 'Too Many Chords',
          'bpm': 120,
          'chords': tooManyChords,
          'measures': <Map<String, Object?>>[
            <String, Object?>{
              'number': 1,
              'beats': <Map<String, Object?>>[
                <String, Object?>{'kind': 'rest', 'duration': 'quarter'},
              ],
            },
          ],
        }),
        throwsFormatException,
      );

      final tooManyMeasures = <Map<String, Object?>>[
        for (var i = 0; i <= StructuredGuitarTabScore.maxMeasuresCount; i++)
          <String, Object?>{
            'number': i + 1,
            'beats': <Map<String, Object?>>[
              <String, Object?>{'kind': 'rest', 'duration': 'quarter'},
            ],
          },
      ];
      expect(
        () => StructuredGuitarTabScore.fromJson(<String, Object?>{
          'id': 'too-many-measures',
          'title': 'Too Many Measures',
          'bpm': 120,
          'measures': tooManyMeasures,
        }),
        throwsFormatException,
      );

      final tooManyBeats = <Map<String, Object?>>[
        for (var i = 0; i <= StructuredTabMeasure.maxBeatsPerMeasure; i++)
          <String, Object?>{'kind': 'rest', 'duration': 'sixteenth'},
      ];
      expect(
        () => StructuredGuitarTabScore.fromJson(<String, Object?>{
          'id': 'too-many-beats',
          'title': 'Too Many Beats',
          'bpm': 120,
          'measures': <Map<String, Object?>>[
            <String, Object?>{
              'number': 1,
              'beats': tooManyBeats,
            },
          ],
        }),
        throwsFormatException,
      );

      expect(
        () => StructuredGuitarTabScore.fromJson(<String, Object?>{
          'id': 'long-title',
          'title': 'a' * 121,
          'bpm': 120,
          'measures': <Map<String, Object?>>[
            <String, Object?>{
              'number': 1,
              'beats': <Map<String, Object?>>[
                <String, Object?>{'kind': 'rest', 'duration': 'quarter'},
              ],
            },
          ],
        }),
        throwsFormatException,
      );
    });

    test(
      'handles 1st/2nd voltas inside Coda and resets volta skip after non-volta repeat',
      () {
        List<int> visitOrderOf(StructuredGuitarTabScore score) {
          final order = <int>[];
          for (final step in expandStructuredTabTimeline(score)) {
            if (order.isEmpty || order.last != step.measureNumber) {
              order.add(step.measureNumber);
            }
          }
          return order;
        }

        StructuredTabMeasure bar(
          int number, {
          bool repeatStart = false,
          bool repeatEnd = false,
          String? volta,
          bool hasSegno = false,
          bool hasCoda = false,
          String? topNote,
        }) {
          return StructuredTabMeasure(
            number: number,
            repeatStart: repeatStart,
            repeatEnd: repeatEnd,
            volta: volta,
            hasSegno: hasSegno,
            hasCoda: hasCoda,
            topNote: topNote,
            beats: <StructuredTabBeat>[
              StructuredTabBeat(
                kind: StructuredTabBeatKind.rest,
                duration: StructuredTabDuration.quarter,
              ),
            ],
          );
        }

        final nonVoltaLeakCheck = StructuredGuitarTabScore(
          id: 'non-volta-reset',
          title: 'Non-volta Reset',
          artist: 'Test',
          tuning: 'Standard',
          capo: 'なし',
          bpm: 120,
          chords: const <StructuredChordDiagram>[],
          measures: <StructuredTabMeasure>[
            bar(1, repeatStart: true),
            bar(2, repeatEnd: true),
            bar(3, volta: '1.'),
            bar(4, volta: '2.'),
          ],
        );
        expect(visitOrderOf(nonVoltaLeakCheck), <int>[1, 2, 1, 2, 3, 4]);

        final codaVoltaScore = StructuredGuitarTabScore(
          id: 'coda-volta',
          title: 'Coda Volta',
          artist: 'Test',
          tuning: 'Standard',
          capo: 'なし',
          bpm: 120,
          chords: const <StructuredChordDiagram>[],
          measures: <StructuredTabMeasure>[
            bar(1, hasSegno: true),
            bar(2, topNote: 'Da Coda'),
            bar(3, topNote: 'D.S. al Coda'),
            bar(4, hasCoda: true, repeatStart: true),
            bar(5, volta: '1.', repeatEnd: true),
            bar(6, volta: '2.'),
          ],
        );
        expect(
          visitOrderOf(codaVoltaScore),
          <int>[1, 2, 3, 1, 2, 4, 5, 4, 6],
        );

        final dsWithoutCodaFade = StructuredGuitarTabScore(
          id: 'ds-fade-no-coda',
          title: 'DS Fade',
          artist: 'Test',
          tuning: 'Standard',
          capo: 'なし',
          bpm: 120,
          chords: const <StructuredChordDiagram>[],
          measures: <StructuredTabMeasure>[
            bar(1, hasSegno: true),
            bar(2, topNote: 'D.S.'),
            bar(3, repeatStart: true),
            bar(4, repeatEnd: true, topNote: 'Repeat & Fade Out.'),
          ],
        );
        expect(
          visitOrderOf(dsWithoutCodaFade),
          <int>[1, 2, 1, 2, 3, 4, 3, 4],
        );
      },
    );
  });
}
