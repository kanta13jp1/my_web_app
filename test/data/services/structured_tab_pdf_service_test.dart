import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/services/structured_tab_catalog_service.dart';
import 'package:my_web_app/data/services/structured_tab_pdf_service.dart';
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
  });
}
