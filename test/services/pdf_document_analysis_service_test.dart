import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/pdf_document_analysis.dart';
import 'package:my_web_app/services/pdf_document_analysis_service.dart';

void main() {
  test('inspectPdf verifies multi-page count and parser estimate', () {
    final selection = PdfDocumentAnalysisService.inspectPdf(
      'quarterly report.pdf',
      _pdf(12),
    );

    expect(selection.fileName, 'quarterly_report.pdf');
    expect(selection.pageCount, 12);
    expect(selection.estimatedParserCostUsd, closeTo(0.66, 0.000001));
  });

  test('inspectPdf rejects a non-PDF payload', () {
    expect(
      () => PdfDocumentAnalysisService.inspectPdf(
        'fake.pdf',
        Uint8List.fromList(utf8.encode('not a pdf')),
      ),
      throwsA(isA<PdfDocumentAnalysisException>()),
    );
  });

  test('inspectPdf fails closed when page metadata is ambiguous', () {
    final mismatched = Uint8List.fromList(
      latin1.encode(
        '%PDF-1.7\n1 0 obj << /Type /Pages /Count 3 >> endobj\n'
        '2 0 obj << /Type /Page >> endobj\n%%EOF',
      ),
    );
    expect(
      () => PdfDocumentAnalysisService.inspectPdf('ambiguous.pdf', mismatched),
      throwsA(isA<PdfDocumentAnalysisException>()),
    );
  });

  test('result parser rejects a server page or cost mismatch', () {
    expect(
      () => PdfDocumentAnalysisResult.fromMap(<String, dynamic>{
        'document': <String, dynamic>{
          'file_name': 'report.pdf',
          'page_count': 3,
          'estimated_parser_cost_usd': 9.99,
        },
        'analysis': const <String, dynamic>{},
      }),
      throwsFormatException,
    );
  });

  test(
    'analyze uploads owner-scoped input, invokes ai-hub, and cleans up',
    () async {
      final uploaded = <String>[];
      final removed = <String>[];
      Map<String, dynamic>? capturedBody;
      final service = PdfDocumentAnalysisService(
        userIdProvider: () => 'user-1',
        uploader: (path, bytes) async {
          expect(bytes, isNotEmpty);
          uploaded.add(path);
        },
        remover: (path) async => removed.add(path),
        offlinePolicyLoader: () async => <String, dynamic>{
          'offline_secure_mode': false,
        },
        invoker: (body) async {
          capturedBody = body;
          return <String, dynamic>{
            'success': true,
            'document': <String, dynamic>{
              'file_name': 'report.pdf',
              'page_count': 3,
              'estimated_parser_cost_usd': 0.165,
            },
            'extracted_content': '# Report\nRevenue increased.',
            'extraction_truncated': false,
            'analysis': <String, dynamic>{
              'title': 'Report',
              'summary': 'Revenue increased.',
              'key_points': <String>['Revenue +10%'],
              'important_fields': <Map<String, String>>[
                <String, String>{'label': 'Owner', 'value': 'Finance'},
              ],
            },
          };
        },
      );
      final selection = PdfDocumentAnalysisService.inspectPdf(
        'report.pdf',
        _pdf(3),
      );

      final result = await service.analyze(selection);

      expect(uploaded, hasLength(1));
      expect(uploaded.single, startsWith('user-1/writer-analysis/'));
      expect(removed, uploaded);
      expect(capturedBody, containsPair('action', 'document.pdf.analyze'));
      expect(capturedBody, containsPair('confirmed_page_count', 3));
      expect(capturedBody, containsPair('offline_secure_mode', false));
      expect(result.summary, 'Revenue increased.');
      expect(result.importantFields.single.label, 'Owner');
    },
  );

  test(
    'analyze removes temporary input when provider rejects the request',
    () async {
      final removed = <String>[];
      final service = PdfDocumentAnalysisService(
        userIdProvider: () => 'user-1',
        uploader: (_, __) async {},
        remover: (path) async => removed.add(path),
        offlinePolicyLoader: () async => const <String, dynamic>{},
        invoker: (_) async => <String, dynamic>{
          'success': false,
          'code': 'feature_unavailable',
        },
      );

      await expectLater(
        service.analyze(
          PdfDocumentAnalysisService.inspectPdf('report.pdf', _pdf(2)),
        ),
        throwsA(
          isA<PdfDocumentAnalysisException>().having(
            (error) => error.message,
            'message',
            contains('準備中'),
          ),
        ),
      );
      expect(removed, hasLength(1));
    },
  );
}

Uint8List _pdf(int pageCount) {
  final pages = List<String>.generate(
    pageCount,
    (index) => '${index + 1} 0 obj << /Type /Page /Parent 99 0 R >> endobj',
  ).join('\n');
  return Uint8List.fromList(
    latin1.encode(
      '%PDF-1.7\n99 0 obj << /Type /Pages /Count $pageCount >> endobj\n'
      '$pages\n%%EOF',
    ),
  );
}
