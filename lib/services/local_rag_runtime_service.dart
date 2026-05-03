import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'offline_secure_mode_settings_service.dart';

typedef LocalRagRuntimeInvoker = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class LocalRagRuntimeException implements Exception {
  final String message;

  const LocalRagRuntimeException(this.message);

  @override
  String toString() => message;
}

class LocalRagCitation {
  final String sourceId;
  final String title;
  final String path;
  final String snippet;
  final double score;

  const LocalRagCitation({
    required this.sourceId,
    required this.title,
    required this.path,
    required this.snippet,
    required this.score,
  });

  factory LocalRagCitation.fromMap(Map<String, dynamic> map) {
    return LocalRagCitation(
      sourceId: map['source_id']?.toString().trim() ?? '',
      title: map['title']?.toString().trim() ?? '',
      path: map['path']?.toString().trim() ?? '',
      snippet: map['snippet']?.toString().trim() ?? '',
      score: _asDouble(map['score']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source_id': sourceId,
      'title': title,
      'path': path,
      'snippet': snippet,
      'score': score,
    };
  }
}

class LocalRagSourceReference {
  final String sourceId;
  final String rawPayload;
  final String label;

  const LocalRagSourceReference({
    required this.sourceId,
    required this.rawPayload,
    required this.label,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source_id': sourceId,
      'raw_payload': rawPayload,
      'label': label,
    };
  }
}

class LocalRagRuntimeResponse {
  final String text;
  final String rawText;
  final String engine;
  final String model;
  final String vectorDbPath;
  final bool offlineOnly;
  final bool networkBlocked;
  final int? memoryPeakMb;
  final List<LocalRagCitation> citations;
  final List<LocalRagSourceReference> sourceReferences;
  final Map<String, dynamic> raw;

  const LocalRagRuntimeResponse({
    required this.text,
    required this.rawText,
    required this.engine,
    required this.model,
    required this.vectorDbPath,
    required this.offlineOnly,
    required this.networkBlocked,
    required this.citations,
    required this.sourceReferences,
    required this.raw,
    this.memoryPeakMb,
  });

  factory LocalRagRuntimeResponse.fromMap(Map<String, dynamic> map) {
    final citationsRaw = map['citations'];
    final citations = citationsRaw is List
        ? citationsRaw
            .whereType<Map>()
            .map(
              (item) => LocalRagCitation.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <LocalRagCitation>[];
    final rawText = (map['text'] ?? map['answer'] ?? '').toString().trim();
    final parsedText = _parsePleiasSourceTokens(rawText, citations);

    return LocalRagRuntimeResponse(
      text: parsedText.text.trim(),
      rawText: rawText,
      engine: map['engine']?.toString().trim() ?? 'local-rag',
      model: map['model']?.toString().trim() ?? 'local-model',
      vectorDbPath: map['vector_db_path']?.toString().trim() ?? '',
      offlineOnly: map['offline_only'] != false,
      networkBlocked: map['network_blocked'] == true,
      memoryPeakMb: _asInt(map['memory_peak_mb']),
      citations: citations,
      sourceReferences: parsedText.references,
      raw: map,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      if (rawText != text) 'raw_text': rawText,
      'engine': engine,
      'model': model,
      'vector_db_path': vectorDbPath,
      'offline_only': offlineOnly,
      'network_blocked': networkBlocked,
      if (memoryPeakMb != null) 'memory_peak_mb': memoryPeakMb,
      'citations': citations.map((item) => item.toJson()).toList(),
      'source_references':
          sourceReferences.map((item) => item.toJson()).toList(),
    };
  }
}

class LocalRagRuntimeService {
  final LocalRagRuntimeInvoker? _invoker;
  final Duration timeout;

  const LocalRagRuntimeService({
    LocalRagRuntimeInvoker? invoker,
    this.timeout = const Duration(seconds: 60),
  }) : _invoker = invoker;

  Future<LocalRagRuntimeResponse> query({
    required String query,
    required OfflineSecureModeSettings settings,
    String systemPrompt = '',
    Object? contextData,
    String? sessionId,
    String? traceId,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw const LocalRagRuntimeException('Local RAG query is empty');
    }
    if (!settings.localRuntimeConfigured) {
      throw const LocalRagRuntimeException(
        'Local model path and vector DB path are required',
      );
    }

    final body = <String, dynamic>{
      'query': normalizedQuery,
      'system_prompt': systemPrompt.trim(),
      'context_data': contextData,
      'model_path': settings.localModelPath,
      'vector_db_path': settings.localVectorDbPath,
      'engine': settings.inferenceEngine,
      'offline_only': true,
      'network_policy': 'offline_only',
      'temperature': 0,
      'include_citations': true,
      'citation_token_format': 'pleias_source_start_end',
      if (sessionId != null && sessionId.trim().isNotEmpty)
        'session_id': sessionId.trim(),
      if (traceId != null && traceId.trim().isNotEmpty)
        'trace_id': traceId.trim(),
    };

    final invoker = _invoker;
    final data = invoker != null
        ? await invoker(body)
        : await _post(settings.localRuntimeUrl, body);
    if (data['success'] != true) {
      final detail =
          (data['message'] ?? data['detail'] ?? 'Local RAG runtime failed')
              .toString()
              .trim();
      throw LocalRagRuntimeException(
        detail.isEmpty ? 'Local RAG runtime failed' : detail,
      );
    }

    final response = LocalRagRuntimeResponse.fromMap(data);
    if (response.text.isEmpty) {
      throw const LocalRagRuntimeException('Local RAG response was empty');
    }
    return response;
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(endpoint);
    final response = await http
        .post(
          uri,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{
      'success': false,
      'message': 'Unexpected local RAG response',
      'status_code': response.statusCode,
    };
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _asDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}

class _PleiasSourceParseResult {
  final String text;
  final List<LocalRagSourceReference> references;

  const _PleiasSourceParseResult({
    required this.text,
    required this.references,
  });
}

_PleiasSourceParseResult _parsePleiasSourceTokens(
  String text,
  List<LocalRagCitation> citations,
) {
  final pattern = RegExp(
    r'<\|source_start\|>(.*?)<\|source_end\|>',
    dotAll: true,
  );
  final matches = pattern.allMatches(text).toList();
  if (matches.isEmpty) {
    return _PleiasSourceParseResult(
      text: text,
      references: const <LocalRagSourceReference>[],
    );
  }

  final citationById = <String, LocalRagCitation>{
    for (final citation in citations)
      if (citation.sourceId.trim().isNotEmpty)
        citation.sourceId.trim(): citation,
  };
  final buffer = StringBuffer();
  final references = <LocalRagSourceReference>[];
  var cursor = 0;

  for (final match in matches) {
    buffer.write(text.substring(cursor, match.start));
    final rawPayload = (match.group(1) ?? '').trim();
    final sourceId = _sourceIdFromPleiasPayload(rawPayload);
    final citation = citationById[sourceId];
    final citationTitle = citation?.title.trim() ?? '';
    final label = citationTitle.isNotEmpty
        ? citationTitle
        : (sourceId.isEmpty ? 'source-${references.length + 1}' : sourceId);
    references.add(
      LocalRagSourceReference(
        sourceId: sourceId,
        rawPayload: rawPayload,
        label: label,
      ),
    );
    buffer.write('[$label]');
    cursor = match.end;
  }
  buffer.write(text.substring(cursor));

  return _PleiasSourceParseResult(
    text: buffer.toString(),
    references: references,
  );
}

String _sourceIdFromPleiasPayload(String payload) {
  final value = payload.trim();
  if (value.isEmpty) return '';
  final decoded = _tryDecodeJsonMap(value);
  final fromJson = decoded == null
      ? null
      : decoded['source_id'] ??
          decoded['sourceId'] ??
          decoded['id'] ??
          decoded['source'];
  final normalized = (fromJson ?? value).toString().trim();
  final match = RegExp(r'[A-Za-z0-9._:-]+').firstMatch(normalized);
  return match?.group(0) ?? normalized;
}

Map<String, dynamic>? _tryDecodeJsonMap(String value) {
  if (!value.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } on FormatException {
    return null;
  }
  return null;
}
