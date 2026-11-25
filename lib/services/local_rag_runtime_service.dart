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
  final String locationLabel;

  const LocalRagCitation({
    required this.sourceId,
    required this.title,
    required this.path,
    required this.snippet,
    required this.score,
    this.locationLabel = '',
  });

  factory LocalRagCitation.fromMap(Map<String, Object?> map) {
    final position = _asStringMap(map['position']);
    final locationLabel = _firstNonEmpty(<Object?>[
      map['location_label'],
      position?['label'],
    ]);
    return LocalRagCitation(
      sourceId: _firstNonEmpty(<Object?>[
        map['source_id'],
        map['citation_id'],
        map['reference_id'],
        map['id'],
      ]),
      title: _firstNonEmpty(<Object?>[
        map['title'],
        map['file_name'],
      ]),
      path: _firstNonEmpty(<Object?>[
        map['path'],
        map['source_url'],
      ]),
      snippet: _firstNonEmpty(<Object?>[
        map['snippet'],
        map['highlight_text'],
        map['excerpt'],
        map['preview_text'],
      ]),
      score: _asDouble(map['score'] ?? map['confidence']) ?? 0,
      locationLabel: locationLabel,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source_id': sourceId,
      'title': title,
      'path': path,
      'snippet': snippet,
      'score': score,
      if (locationLabel.isNotEmpty) 'location_label': locationLabel,
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

  factory PleiasCitationSegment.fromMap(Map<String, Object?> map) {
    final rawRef = map['reference_id'] ?? map['source_id'];
    final ref = rawRef?.toString().trim() ?? '';
    return PleiasCitationSegment(
      text: map['text']?.toString() ?? '',
      sourceId: ref.isEmpty ? null : ref,
      markerOnly: map['marker_only'] == true,
    );
  }

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

  factory PleiasCitationParseResult.fromMap(Map<String, Object?> map) {
    final segmentsRaw = map['segments'];
    final segments = segmentsRaw is List
        ? segmentsRaw
            .whereType<Map>()
            .map(
              (item) => PleiasCitationSegment.fromMap(
                Map<String, Object?>.from(item),
              ),
            )
            .where((segment) => segment.text.isNotEmpty)
            .toList(growable: false)
        : const <PleiasCitationSegment>[];

    final refsRaw = map['reference_ids'] ?? map['source_ids'];
    final refs = <String>{
      if (refsRaw is List)
        for (final item in refsRaw)
          if (item != null && item.toString().trim().isNotEmpty)
            item.toString().trim(),
      for (final seg in segments)
        if (seg.cited) seg.sourceId!.trim(),
    }.toList(growable: false);

    final plain = map['plain_text']?.toString() ??
        segments.map((segment) => segment.text).join();
    final found = map['has_native_tokens'] == true ||
        map['has_citation_tokens'] == true ||
        refs.isNotEmpty ||
        segments.any((segment) => segment.cited);

    return PleiasCitationParseResult(
      plainText: plain,
      segments: segments,
      sourceIds: refs,
      hasCitationTokens: found,
    );
  }

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
  final int? memoryLimitMb;
  final bool memoryGuardPassed;
  final List<LocalRagCitation> citations;
  final PleiasCitationParseResult citationText;
  final Map<String, Object?> raw;

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
    this.memoryLimitMb,
    this.memoryGuardPassed = true,
  });

  factory LocalRagRuntimeResponse.fromMap(Map<String, Object?> map) {
    final citationsRaw = map['citations'];
    final citations = citationsRaw is List
        ? citationsRaw
            .whereType<Map>()
            .map(
              (item) => LocalRagCitation.fromMap(
                Map<String, Object?>.from(item),
              ),
            )
            .toList()
        : const <LocalRagCitation>[];

    final parsedMap = _asStringMap(map['parsed_answer']);
    final text =
        (map['text'] ?? map['answer'] ?? parsedMap?['plain_text'] ?? '')
            .toString()
            .trim();
    final citationText = parsedMap != null
        ? PleiasCitationParseResult.fromMap(parsedMap)
        : parsePleiasCitationText(text);
    return LocalRagRuntimeResponse(
      text: text,
      engine: map['engine']?.toString().trim() ?? 'local-rag',
      model: map['model']?.toString().trim() ?? 'local-model',
      vectorDbPath: map['vector_db_path']?.toString().trim() ?? '',
      offlineOnly: map['offline_only'] != false,
      networkBlocked: map['network_blocked'] == true,
      memoryPeakMb: _asInt(map['memory_peak_mb']),
      memoryLimitMb: _asInt(map['memory_limit_mb']),
      memoryGuardPassed: map['memory_guard_passed'] != false,
      citations: citations,
      citationText: citationText,
      raw: map,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'text': text,
      'engine': engine,
      'model': model,
      'vector_db_path': vectorDbPath,
      'offline_only': offlineOnly,
      'network_blocked': networkBlocked,
      if (memoryPeakMb != null) 'memory_peak_mb': memoryPeakMb,
      if (memoryLimitMb != null) 'memory_limit_mb': memoryLimitMb,
      'memory_guard_passed': memoryGuardPassed,
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
      'memory_limit_mb': settings.memoryLimitMb
          .clamp(
            OfflineSecureModeSettings.minMemoryLimitMb,
            OfflineSecureModeSettings.defaultMemoryLimitMb,
          )
          .toInt(),
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

  Future<Map<String, Object?>> _post(
    String endpoint,
    Map<String, Object?> body,
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
    if (decoded is Map<String, Object?>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return <String, Object?>{
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

String _firstNonEmpty(List<Object?> candidates) {
  for (final item in candidates) {
    final value = item?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return null;
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
  final bracketSource =
      RegExp(r'\[source\s*:\s*([^\]]+)\]', caseSensitive: false);
  final segments = <PleiasCitationSegment>[];
  final sourceIds = <String>{};
  var cursor = 0;
  var hasCitationTokens = false;

  const answerStart = '<|answer_start|>';
  const answerEnd = '<|answer_end|>';
  const citationStart = '<|citation_start|>';
  const citationEnd = '<|citation_end|>';
  const citationClosers = <String>[
    '<|/citation|>',
    '<|citation_close|>',
    '<|citation_stop|>',
    '<|citation_finish|>',
    ...closeTokens,
  ];

  var text = raw;
  final answerStartIdx = text.indexOf(answerStart);
  final answerEndIdx = text.indexOf(answerEnd);
  if (answerStartIdx >= 0 || answerEndIdx >= 0) {
    hasCitationTokens = true;
    if (answerStartIdx >= 0) {
      final bodyStart = answerStartIdx + answerStart.length;
      final bodyEnd = text.indexOf(answerEnd, bodyStart);
      text = bodyEnd >= 0
          ? text.substring(bodyStart, bodyEnd)
          : text.substring(bodyStart);
    }
    text = text
        .replaceAll(
          RegExp(
            r'<\|\/?(?:answer_start|answer_end|answer)\|>',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  final refOpen = RegExp(r'<ref\b([^>]*)>', caseSensitive: false);
  final numericBracket = RegExp(r'\[(\d+)\](?!\()');

  void addPlain(String value) {
    if (value.isNotEmpty) {
      segments.add(PleiasCitationSegment(text: value));
    }
  }

  void addCited(String value, String id, {bool markerOnly = false}) {
    if (id.isNotEmpty) sourceIds.add(id);
    if (markerOnly) {
      segments.add(
        PleiasCitationSegment(
          text: value,
          sourceId: id.isEmpty ? null : id,
          markerOnly: true,
        ),
      );
    } else if (value.isNotEmpty) {
      segments.add(
        PleiasCitationSegment(
          text: value,
          sourceId: id.isEmpty ? null : id,
        ),
      );
    }
  }

  while (cursor < text.length) {
    final sourceIdx = text.indexOf(sourceStart, cursor);
    final citationIdx = text.indexOf(citationStart, cursor);
    final refMatch = refOpen.firstMatch(text.substring(cursor));
    final refIdx = refMatch != null ? cursor + refMatch.start : -1;
    final bSourceMatch = bracketSource.firstMatch(text.substring(cursor));
    final bSourceIdx = bSourceMatch != null ? cursor + bSourceMatch.start : -1;
    final numMatch = numericBracket.firstMatch(text.substring(cursor));
    final numIdx = numMatch != null ? cursor + numMatch.start : -1;

    final indices = <int>[
      if (sourceIdx >= 0) sourceIdx,
      if (citationIdx >= 0) citationIdx,
      if (refIdx >= 0) refIdx,
      if (bSourceIdx >= 0) bSourceIdx,
      if (numIdx >= 0) numIdx,
    ];
    if (indices.isEmpty) {
      addPlain(text.substring(cursor));
      break;
    }
    indices.sort();
    final nextIndex = indices.first;
    addPlain(text.substring(cursor, nextIndex));

    if (numIdx == nextIndex && numMatch != null) {
      final id = (numMatch.group(1) ?? '').trim();
      hasCitationTokens = true;
      addCited('[$id]', id, markerOnly: true);
      cursor = nextIndex + numMatch.group(0)!.length;
      continue;
    }

    if (bSourceIdx == nextIndex && bSourceMatch != null) {
      final id = _normalizeSourceId(bSourceMatch.group(1) ?? '');
      hasCitationTokens = true;
      addCited('[source:$id]', id, markerOnly: true);
      cursor = nextIndex + bSourceMatch.group(0)!.length;
      continue;
    }

    if (sourceIdx == nextIndex) {
      final idStart = nextIndex + sourceStart.length;
      final idEnd = text.indexOf(sourceEnd, idStart);
      if (idEnd < 0) {
        addPlain(text.substring(nextIndex));
        break;
      }
      final sourceId = _normalizeSourceId(text.substring(idStart, idEnd));
      final contentStart = idEnd + sourceEnd.length;
      final close = _findFirstCloseToken(
        text,
        contentStart,
        closeTokens,
      );
      hasCitationTokens = true;
      if (close == null) {
        addCited('[source:$sourceId]', sourceId, markerOnly: true);
        cursor = contentStart;
        continue;
      }
      final citedText = text.substring(contentStart, close.index);
      if (citedText.isEmpty) {
        addCited('[source:$sourceId]', sourceId, markerOnly: true);
      } else {
        addCited(citedText, sourceId);
      }
      cursor = close.index + close.token.length;
      continue;
    }

    if (citationIdx == nextIndex) {
      final innerStart = nextIndex + citationStart.length;
      final endIdx = text.indexOf(citationEnd, innerStart);
      if (endIdx < 0) {
        hasCitationTokens = true;
        cursor = innerStart;
        continue;
      }
      hasCitationTokens = true;
      final inner = text.substring(innerStart, endIdx);
      final afterEnd = endIdx + citationEnd.length;
      final close = _findFirstCloseToken(
        text,
        afterEnd,
        citationClosers,
      );
      final nextCit = text.indexOf(citationStart, afterEnd);
      final pairedClose =
          close != null && (nextCit < 0 || close.index < nextCit)
              ? close
              : null;
      if (pairedClose != null && _isBareReferenceId(inner)) {
        final sourceId = _normalizeSourceId(inner);
        final citedText = text.substring(afterEnd, pairedClose.index);
        if (citedText.isEmpty) {
          addCited('[source:$sourceId]', sourceId, markerOnly: true);
        } else {
          addCited(citedText, sourceId);
        }
        cursor = pairedClose.index + pairedClose.token.length;
        continue;
      }
      final nested = parsePleiasCitationText(inner);
      for (final seg in nested.segments) {
        addCited(
          seg.text,
          seg.sourceId ?? '',
          markerOnly: seg.markerOnly,
        );
      }
      cursor = afterEnd;
      continue;
    }

    if (refIdx == nextIndex && refMatch != null) {
      hasCitationTokens = true;
      final rawTag = refMatch.group(0) ?? '';
      final attrs = refMatch.group(1) ?? '';
      final attrId = _parseRefIdFromAttributes(attrs);
      final tagEnd = nextIndex + rawTag.length;
      if (rawTag.trimRight().endsWith('/>')) {
        if (attrId.isNotEmpty) {
          addCited('[source:$attrId]', attrId, markerOnly: true);
        }
        cursor = tagEnd;
        continue;
      }
      final closeTagIdx = text.toLowerCase().indexOf('</ref>', tagEnd);
      if (closeTagIdx < 0) {
        if (attrId.isNotEmpty) {
          addCited('[source:$attrId]', attrId, markerOnly: true);
        }
        cursor = tagEnd;
        continue;
      }
      final inner = text.substring(tagEnd, closeTagIdx);
      if (attrId.isNotEmpty) {
        if (inner.trim().isEmpty) {
          addCited('[source:$attrId]', attrId, markerOnly: true);
        } else {
          addCited(inner, attrId);
        }
      } else if (_isBareReferenceId(inner)) {
        final bareId = _normalizeSourceId(inner);
        addCited('[source:$bareId]', bareId, markerOnly: true);
      } else {
        addPlain(inner);
      }
      cursor = closeTagIdx + '</ref>'.length;
      continue;
    }
  }

  _mergeAdjacentPlainSegments(segments);
  final plainText = segments.map((segment) => segment.text).join();
  return PleiasCitationParseResult(
    plainText: plainText,
    segments: segments,
    sourceIds: sourceIds.toList(growable: false),
    hasCitationTokens: hasCitationTokens,
  );
}

void _mergeAdjacentPlainSegments(List<PleiasCitationSegment> segments) {
  var writeIdx = 0;
  for (final item in segments) {
    if (item.text.isEmpty) continue;
    if (writeIdx > 0 && !segments[writeIdx - 1].cited && !item.cited) {
      segments[writeIdx - 1] = PleiasCitationSegment(
        text: '${segments[writeIdx - 1].text}${item.text}',
      );
    } else {
      segments[writeIdx++] = item;
    }
  }
  segments.length = writeIdx;
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
  return value
      .trim()
      .replaceAll(
        RegExp(r'^(?:source|reference|ref|id)\s*:\s*', caseSensitive: false),
        '',
      )
      .trim();
}

String _parseRefIdFromAttributes(String attrsRaw) {
  final trimmed = attrsRaw.replaceAll(RegExp(r'/$'), '').trim();
  if (trimmed.isEmpty) return '';
  final attrMatch = RegExp(
    r'''\b(?:reference_id|source_id|source|id|ref|doc|name)\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s"'>/]+))''',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (attrMatch != null) {
    return _normalizeSourceId(
      attrMatch.group(1) ?? attrMatch.group(2) ?? attrMatch.group(3) ?? '',
    );
  }
  if (RegExp(r'^(?:source\s*:\s*)?[A-Za-z0-9._-]+$', caseSensitive: false)
      .hasMatch(trimmed)) {
    return _normalizeSourceId(trimmed);
  }
  return '';
}

bool _isBareReferenceId(String value) {
  final trimmed = value.trim();
  return RegExp(
    r'^(?:source\s*:\s*)?(?:\d+|(?:doc|source)[-_][A-Za-z0-9._-]+)$',
    caseSensitive: false,
  ).hasMatch(trimmed);
}
