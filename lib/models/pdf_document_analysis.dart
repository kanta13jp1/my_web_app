import 'dart:typed_data';

const int pdfDocumentAnalysisMaxBytes = 20 * 1024 * 1024;
const int pdfDocumentAnalysisMaxPages = 200;
const double writerPdfParserUsdPerPage = 0.055;

class PdfDocumentSelection {
  final String fileName;
  final Uint8List bytes;
  final int pageCount;

  const PdfDocumentSelection({
    required this.fileName,
    required this.bytes,
    required this.pageCount,
  });

  double get estimatedParserCostUsd => pageCount * writerPdfParserUsdPerPage;
}

class PdfDocumentField {
  final String label;
  final String value;

  const PdfDocumentField({required this.label, required this.value});
}

class PdfDocumentAnalysisResult {
  final String fileName;
  final int pageCount;
  final double estimatedParserCostUsd;
  final String extractedContent;
  final bool extractionTruncated;
  final String title;
  final String summary;
  final List<String> keyPoints;
  final List<PdfDocumentField> importantFields;

  const PdfDocumentAnalysisResult({
    required this.fileName,
    required this.pageCount,
    required this.estimatedParserCostUsd,
    required this.extractedContent,
    required this.extractionTruncated,
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.importantFields,
  });

  factory PdfDocumentAnalysisResult.fromMap(Map<String, dynamic> map) {
    final document = _map(map['document']);
    final analysis = _map(map['analysis']);
    final rawPoints = analysis['key_points'];
    final rawFields = analysis['important_fields'];
    final pageCount = _integer(document['page_count']);
    final estimatedCost = _number(document['estimated_parser_cost_usd']);
    if (pageCount <= 0 || pageCount > pdfDocumentAnalysisMaxPages) {
      throw const FormatException('Invalid PDF page count');
    }
    final expectedCost = pageCount * writerPdfParserUsdPerPage;
    if (!estimatedCost.isFinite ||
        estimatedCost < 0 ||
        (estimatedCost - expectedCost).abs() > 0.000001) {
      throw const FormatException('Invalid PDF parser cost');
    }
    return PdfDocumentAnalysisResult(
      fileName: _limited(document['file_name'], 160, fallback: 'document.pdf'),
      pageCount: pageCount,
      estimatedParserCostUsd: estimatedCost,
      extractedContent: _limited(map['extracted_content'], 1000000),
      extractionTruncated: map['extraction_truncated'] == true,
      title: _limited(analysis['title'], 200, fallback: 'PDFドキュメント'),
      summary: _limited(analysis['summary'], 8000),
      keyPoints: rawPoints is List
          ? rawPoints
              .map((item) => _limited(item, 1000))
              .where((item) => item.isNotEmpty)
              .take(12)
              .toList(growable: false)
          : const <String>[],
      importantFields: rawFields is List
          ? rawFields
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(
                (item) => PdfDocumentField(
                  label: _limited(item['label'], 160),
                  value: _limited(item['value'], 1000),
                ),
              )
              .where((item) => item.label.isNotEmpty && item.value.isNotEmpty)
              .take(20)
              .toList(growable: false)
          : const <PdfDocumentField>[],
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String _limited(Object? value, int maxLength, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return fallback;
  final clean = text.replaceAll(
    RegExp('[\\u0000-\\u0008\\u000B\\u000C\\u000E-\\u001F]'),
    '',
  );
  return clean.length <= maxLength ? clean : clean.substring(0, maxLength);
}
