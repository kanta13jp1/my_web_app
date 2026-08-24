import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/pdf_document_analysis.dart';
import 'package:my_web_app/pages/pdf_document_analyzer_page.dart';
import 'package:my_web_app/services/pdf_document_analysis_service.dart';

void main() {
  testWidgets('shows page cost confirmation and structured result', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: PdfDocumentAnalyzerPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pdf-picker-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('3ページ'), findsWidgets);
    expect(find.textContaining(r'$0.165 USD'), findsOneWidget);

    final analyzeButton = find.byKey(const Key('pdf-analyze-button'));
    await tester.ensureVisible(analyzeButton);
    await tester.tap(analyzeButton);
    await tester.pumpAndSettle();
    expect(find.text('解析内容と料金を確認'), findsOneWidget);
    expect(find.textContaining(r'$0.055 = $0.165'), findsWidgets);

    await tester.tap(find.byKey(const Key('pdf-analysis-confirm-button')));
    await tester.pumpAndSettle();

    expect(gateway.analyzeCalls, 1);
    expect(find.byKey(const Key('pdf-analysis-result')), findsOneWidget);
    expect(find.text('四半期レポート'), findsOneWidget);
    expect(find.text('売上が増加しました。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout renders without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: PdfDocumentAnalyzerPage(gateway: _FakeGateway())),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDFドキュメント解析'), findsOneWidget);
    expect(find.text('解析結果はここに表示されます'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeGateway implements PdfDocumentAnalysisGateway {
  int analyzeCalls = 0;

  @override
  Future<PdfDocumentSelection?> pickPdf() async => PdfDocumentSelection(
        fileName: 'report.pdf',
        bytes: Uint8List.fromList(latin1.encode('%PDF-test')),
        pageCount: 3,
      );

  @override
  Future<PdfDocumentAnalysisResult> analyze(
    PdfDocumentSelection selection,
  ) async {
    analyzeCalls++;
    return const PdfDocumentAnalysisResult(
      fileName: 'report.pdf',
      pageCount: 3,
      estimatedParserCostUsd: 0.165,
      extractedContent: '# 四半期レポート',
      extractionTruncated: false,
      title: '四半期レポート',
      summary: '売上が増加しました。',
      keyPoints: <String>['売上10%増'],
      importantFields: <PdfDocumentField>[
        PdfDocumentField(label: '担当', value: '財務部'),
      ],
    );
  }
}
