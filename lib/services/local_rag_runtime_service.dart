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

class PleiasCitationSegment {
  final String text;
  final String? sourceId;
  final bool markerOnly;

  const PleiasCitationSegment({
    required this.text,
    this.sourceId,
    this.markerOnly = false,
  });

  bool get cited => sourceId != null && sourceId!.trim().isNotEmpty;
}

class PleiasCitationParseResult {
  final String plainText;
  final List<PleiasCitationSegment> segments;
  final List<String> sourceIds;
  final bool hasCitationTokens;

  const PleiasCitationParseResult({
    required this.plainText,
    required this.segments,
    required this.sourceIds,
    required this.hasCitationTokens,
  });

  bool get hasCitations => sourceIds.isNotEmpty;
}

class LocalRagRuntimeResponse {
  final String text;
  final String engine;
  final String model;
  final String vectorDbPath;
  final bool offlineOnly;
  final bool networkBlocked;
  final int? memoryPeakMb;
  final List<LocalRagCitation> citations;
  final PleiasCitationParseResult citationText;
  final Map<String, dynamic> raw;

  const LocalRagRuntimeResponse({
    required this.text,
    required this.engine,
    required this.model,
    required this.vectorDbPath,
    required this.offlineOnly,
    required this.networkBlocked,
    required this.citations,
    required this.citationText,
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

    final text = (map['text'] ?? map['answer'] ?? '').toString().trim();
    return LocalRagRuntimeResponse(
      text: text,
      engine: map['engine']?.toString().trim() ?? 'local-rag',
      model: map['model']?.toString().trim() ?? 'local-model',
      vectorDbPath: map['vector_db_path']?.toString().trim() ?? '',
      offlineOnly: map['offline_only'] != false,
      networkBlocked: map['network_blocked'] == true,
      memoryPeakMb: _asInt(map['memory_peak_mb']),
      citations: citations,
      citationText: parsePleiasCitationText(text),
      raw: map,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'text': text,
      'engine': engine,
      'model': model,
      'vector_db_path': vectorDbPath,
      'offline_only': offlineOnly,
      'network_blocked': networkBlocked,
      if (memoryPeakMb != null) 'memory_peak_mb': memoryPeakMb,
      'citations': citations.map((item) => item.toJson()).toList(),
      'citation_source_ids': citationText.sourceIds,
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
      'temperature': 0,
      'offline_only': true,
      'network_policy': 'offline_only',
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

PleiasCitationParseResult parsePleiasCitationText(String raw) {
  if (raw.isEmpty) {
    return const PleiasCitationParseResult(
      plainText: '',
      segments: <PleiasCitationSegment>[],
      sourceIds: <String>[],
      hasCitationTokens: false,
    );
  }

  const sourceStart = '<|source_start|>';
  const sourceEnd = '<|source_end|>';
  const closeTokens = <String>[
    '<|/source|>',
    '<|source_close|>',
    '<|source_stop|>',
    '<|source_finish|>',
  ];
  final bracketSource = RegExp(r'\[source\s*:\s*([^\]]+)\]');
  final segments = <PleiasCitationSegment>[];
  final sourceIds = <String>{};
  var cursor = 0;
  var hasCitationTokens = false;

  void addPlain(String value) {
    if (value.isNotEmpty) {
      segments.add(PleiasCitationSegment(text: value));
    }
  }

  while (cursor < raw.length) {
    final specialIndex = raw.indexOf(sourceStart, cursor);
    final bracketMatch = bracketSource
        .allMatches(raw, cursor)
        .cast<RegExpMatch?>()
        .firstWhere((match) => match != null, orElse: () => null);
    final bracketIndex = bracketMatch?.start ?? -1;

    final nextIndex = _earliestPositive(specialIndex, bracketIndex);
    if (nextIndex < 0) {
      addPlain(raw.substring(cursor));
      break;
    }

    addPlain(raw.substring(cursor, nextIndex));

    if (bracketIndex == nextIndex && bracketMatch != null) {
      final sourceId = _normalizeSourceId(bracketMatch.group(1) ?? '');
      final markerText = '[source:$sourceId]';
      hasCitationTokens = true;
      if (sourceId.isNotEmpty) sourceIds.add(sourceId);
      segments.add(
        PleiasCitationSegment(
          text: markerText,
          sourceId: sourceId,
          markerOnly: true,
        ),
      );
      cursor = bracketMatch.end;
      continue;
    }

    final idStart = nextIndex + sourceStart.length;
    final idEnd = raw.indexOf(sourceEnd, idStart);
    if (idEnd < 0) {
      addPlain(raw.substring(nextIndex));
      break;
    }

    final sourceId = _normalizeSourceId(raw.substring(idStart, idEnd));
    final contentStart = idEnd + sourceEnd.length;
    final close = _findFirstCloseToken(raw, contentStart, closeTokens);
    hasCitationTokens = true;
    if (sourceId.isNotEmpty) sourceIds.add(sourceId);

    if (close == null) {
      segments.add(
        PleiasCitationSegment(
          text: '[source:$sourceId]',
          sourceId: sourceId,
          markerOnly: true,
        ),
      );
      cursor = contentStart;
      continue;
    }

    final citedText = raw.substring(contentStart, close.index);
    if (citedText.isEmpty) {
      segments.add(
        PleiasCitationSegment(
          text: '[source:$sourceId]',
          sourceId: sourceId,
          markerOnly: true,
        ),
      );
    } else {
      segments.add(
        PleiasCitationSegment(text: citedText, sourceId: sourceId),
      );
    }
    cursor = close.index + close.token.length;
  }

  final plainText = segments.map((segment) => segment.text).join();
  return PleiasCitationParseResult(
    plainText: plainText,
    segments: segments,
    sourceIds: sourceIds.toList(growable: false),
    hasCitationTokens: hasCitationTokens,
  );
}

int _earliestPositive(int first, int second) {
  if (first < 0) return second;
  if (second < 0) return first;
  return first < second ? first : second;
}

({int index, String token})? _findFirstCloseToken(
  String raw,
  int start,
  List<String> tokens,
) {
  ({int index, String token})? best;
  for (final token in tokens) {
    final index = raw.indexOf(token, start);
    if (index < 0) continue;
    if (best == null || index < best.index) {
      best = (index: index, token: token);
    }
  }
  return best;
}

String _normalizeSourceId(String value) {
  return value.trim().replaceAll(RegExp(r'^\s*source\s*:\s*'), '').trim();
}
