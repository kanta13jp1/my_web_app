import '../services/local_rag_runtime_service.dart';

class KnowledgeGraphCitationPosition {
  const KnowledgeGraphCitationPosition({
    required this.label,
    this.pageNumber,
    this.section,
    this.startLine,
    this.endLine,
  });

  final String label;
  final int? pageNumber;
  final String? section;
  final int? startLine;
  final int? endLine;

  factory KnowledgeGraphCitationPosition.fromJson(Map<String, Object?> json) {
    final pageNumber = _integer(json['page_number']);
    final section = _nullableText(json['section']);
    final startLine = _integer(json['start_line']);
    final endLine = _integer(json['end_line']);
    final explicitLabel = _text(json['label']);
    final derivedLabel = <String>[
      if (pageNumber != null) 'page $pageNumber',
      if (section != null) section,
      if (startLine != null && endLine != null)
        startLine == endLine ? 'line $startLine' : 'lines $startLine-$endLine',
    ].join(' · ');
    return KnowledgeGraphCitationPosition(
      label: explicitLabel.isEmpty ? derivedLabel : explicitLabel,
      pageNumber: pageNumber,
      section: section,
      startLine: startLine,
      endLine: endLine,
    );
  }
}

class KnowledgeGraphRagCitation {
  const KnowledgeGraphRagCitation({
    required this.id,
    required this.fileName,
    required this.title,
    required this.sourceType,
    required this.sourceUrl,
    required this.excerpt,
    required this.previewText,
    required this.highlightStart,
    required this.highlightEnd,
    required this.highlightText,
    required this.position,
    required this.confidence,
    required this.previewTruncatedBefore,
    required this.previewTruncatedAfter,
    this.lastSyncedAt,
  });

  final String id;
  final String fileName;
  final String title;
  final String sourceType;
  final String sourceUrl;
  final String excerpt;
  final String previewText;
  final int highlightStart;
  final int highlightEnd;
  final String highlightText;
  final KnowledgeGraphCitationPosition position;
  final double confidence;
  final bool previewTruncatedBefore;
  final bool previewTruncatedAfter;
  final DateTime? lastSyncedAt;

  factory KnowledgeGraphRagCitation.fromJson(
    Map<String, Object?> json, {
    required int fallbackIndex,
  }) {
    final excerpt = _text(json['excerpt']);
    final previewValue = json['preview_text'];
    final rawPreview = previewValue is String ? previewValue : '';
    final previewText = rawPreview.isEmpty ? excerpt : rawPreview;
    var highlightStart = _integer(json['highlight_start']) ?? 0;
    var highlightEnd = _integer(json['highlight_end']) ?? previewText.length;
    highlightStart = highlightStart.clamp(0, previewText.length).toInt();
    highlightEnd =
        highlightEnd.clamp(highlightStart, previewText.length).toInt();

    final title = _text(json['title'], fallback: 'Untitled source');
    return KnowledgeGraphRagCitation(
      id: _text(json['citation_id'], fallback: '$fallbackIndex'),
      fileName: _text(json['file_name'], fallback: title),
      title: title,
      sourceType: _text(json['source_type'], fallback: 'unknown'),
      sourceUrl: _text(json['source_url']),
      excerpt: excerpt,
      previewText: previewText,
      highlightStart: highlightStart,
      highlightEnd: highlightEnd,
      highlightText: _text(
        json['highlight_text'],
        fallback: previewText.substring(highlightStart, highlightEnd),
      ),
      position: KnowledgeGraphCitationPosition.fromJson(_map(json['position'])),
      confidence: (_number(json['confidence']) ?? 0).clamp(0, 1).toDouble(),
      previewTruncatedBefore: json['preview_truncated_before'] == true,
      previewTruncatedAfter: json['preview_truncated_after'] == true,
      lastSyncedAt: DateTime.tryParse(_text(json['last_synced_at'])),
    );
  }
}

class KnowledgeGraphRagAnswer {
  const KnowledgeGraphRagAnswer({
    required this.query,
    required this.answer,
    required this.status,
    required this.traceId,
    required this.citations,
    this.parsedSegments = const <KnowledgeGraphAnswerSegment>[],
    this.temperatureUsed,
  });

  final String query;
  final String answer;
  final String status;
  final String traceId;
  final List<KnowledgeGraphRagCitation> citations;
  final List<KnowledgeGraphAnswerSegment> parsedSegments;
  final double? temperatureUsed;

  factory KnowledgeGraphRagAnswer.fromJson(Map<String, Object?> json) {
    final citations = _maps(json['citations']);
    final parsedMap = _map(json['parsed_answer']);
    final parsedSegmentsRaw = _maps(parsedMap['segments']);
    final parsedSegments = parsedSegmentsRaw
        .map(
          (item) => KnowledgeGraphAnswerSegment(
            text: item['text']?.toString() ?? '',
            citationId: _nullableText(
              item['reference_id'] ?? item['citation_id'] ?? item['source_id'],
            ),
            markerOnly: item['marker_only'] == true,
          ),
        )
        .where((segment) => segment.text.isNotEmpty)
        .toList(growable: false);
    final rawAnswer = _text(json['answer']);
    final fallbackPlain = _text(parsedMap['plain_text']);

    return KnowledgeGraphRagAnswer(
      query: _text(json['query']),
      answer: rawAnswer.isNotEmpty ? rawAnswer : fallbackPlain,
      status: _text(json['answer_status'], fallback: 'unknown'),
      traceId: _text(json['trace_id']),
      parsedSegments: parsedSegments,
      temperatureUsed: _number(json['temperature_used']),
      citations: <KnowledgeGraphRagCitation>[
        for (var index = 0; index < citations.length; index++)
          KnowledgeGraphRagCitation.fromJson(
            citations[index],
            fallbackIndex: index + 1,
          ),
      ],
    );
  }

  KnowledgeGraphRagCitation? citationById(String id) {
    final normalized = id.trim().toLowerCase();
    for (final citation in citations) {
      if (citation.id.trim().toLowerCase() == normalized) return citation;
    }
    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric > 0 && numeric <= citations.length) {
      return citations[numeric - 1];
    }
    for (final citation in citations) {
      final candidate = citation.id.trim().toLowerCase();
      if (candidate == 'doc-$normalized' ||
          candidate == 'source-$normalized' ||
          candidate.endsWith('-$normalized')) {
        return citation;
      }
    }
    return null;
  }
}

class KnowledgeGraphAnswerSegment {
  const KnowledgeGraphAnswerSegment({
    required this.text,
    this.citationId,
    this.markerOnly = true,
  });

  final String text;
  final String? citationId;
  final bool markerOnly;

  bool get isCitation => citationId != null;
}

List<KnowledgeGraphAnswerSegment> parseKnowledgeGraphAnswer(String answer) {
  final parsed = parsePleiasCitationText(answer);
  if (parsed.segments.isEmpty) {
    return <KnowledgeGraphAnswerSegment>[
      KnowledgeGraphAnswerSegment(text: answer),
    ];
  }
  return parsed.segments
      .map(
        (segment) => KnowledgeGraphAnswerSegment(
          text: segment.text,
          citationId: segment.sourceId,
          markerOnly: segment.markerOnly,
        ),
      )
      .toList(growable: false);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value.whereType<Map>().map(_map).toList(growable: false);
}

String _text(Object? value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableText(Object? value) {
  final normalized = _text(value);
  return normalized.isEmpty ? null : normalized;
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
