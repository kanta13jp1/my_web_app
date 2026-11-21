import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/services/structured_tab_catalog_service.dart';
import 'package:my_web_app/data/services/structured_tab_pdf_service.dart';
import 'package:my_web_app/domain/models/structured_guitar_tab.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  group('LocalStructuredTabPdfService', () {
    test('generates non-empty valid PDF bytes for all bundled scores',
        () async {
      const catalogService = StructuredTabCatalogService();
      const pdfService = LocalStructuredTabPdfService();
      final scores = await catalogService.loadCatalog();
      final fallbackFont = pw.Font.helvetica();

      for (final score in scores) {
        final bytes = await pdfService.buildScorePdf(
          score,
          fontOverride: fallbackFont,
        );
        expect(bytes, isNotEmpty);
        final header = ascii.decode(bytes.sublist(0, 5));
        expect(header, '%PDF-');
      }
    });

    test('paginates scores with 64 chord diagrams cleanly', () async {
      const pdfService = LocalStructuredTabPdfService();
      final manyChords = <StructuredChordDiagram>[
        for (var i = 0; i < StructuredGuitarTabScore.maxChordsCount; i++)
          StructuredChordDiagram(
            name: 'C$i',
            frets: const <int>[-1, 3, 2, 0, 1, 0],
          ),
      ];
      final score = StructuredGuitarTabScore(
        id: 'many-chords-pdf',
        title: 'Many Chords PDF Pagination Test',
        artist: 'Test',
        tuning: 'Standard tuning',
        capo: 'なし',
        bpm: 120,
        chords: manyChords,
        measures: <StructuredTabMeasure>[
          StructuredTabMeasure(
            number: 1,
            beats: <StructuredTabBeat>[
              StructuredTabBeat(
                kind: StructuredTabBeatKind.rest,
                duration: StructuredTabDuration.whole,
              ),
            ],
          ),
        ],
      );

      final bytes = await pdfService.buildScorePdf(
        score,
        fontOverride: pw.Font.helvetica(),
      );
      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('sanitizes score IDs for PDF filenames', () {
      expect(
        LocalStructuredTabPdfService.sanitizePdfFileName('../evil/id:1?'),
        '___evil_id_1_',
      );
      expect(
        LocalStructuredTabPdfService.sanitizePdfFileName(''),
        'structured-tab',
      );
    });
  });
}
