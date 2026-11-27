import 'package:flutter/foundation.dart';

/// Lifecycle phase of an agricultural policy reform event (#2755).
enum AgriPolicyPhase {
  past('past', '過去の改革'),
  current('current', '進行中・見直し'),
  planned('planned', '今後の改革予定');

  const AgriPolicyPhase(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static AgriPolicyPhase fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in AgriPolicyPhase.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return AgriPolicyPhase.past;
  }
}

/// Neutral fact-checking metadata state for policy statements & outcomes.
enum FactCheckStatus {
  verified('verified', '一次情報確認済'),
  needsReview('needs_review', '要継続確認'),
  disputed('disputed', '見解相違あり'),
  unverified('unverified', '未検証');

  const FactCheckStatus(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static FactCheckStatus fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final value in FactCheckStatus.values) {
      if (value.wireValue == normalized) {
        return value;
      }
    }
    return FactCheckStatus.unverified;
  }
}

const List<String> kDefaultAgriKeywordTags = <String>[
  '減反廃止',
  '直接支払い',
  'マルキン制度',
  '水田政策',
  '2027年改革',
];

@immutable
class AgriPolicyEvent {
  const AgriPolicyEvent({
    required this.id,
    required this.slug,
    required this.eventDate,
    required this.fiscalYear,
    required this.phase,
    required this.title,
    required this.summary,
    required this.tags,
    required this.relatedNodes,
    required this.factCheckStatus,
    required this.sourceCitation,
    required this.policyImpactNotes,
    this.verifiedAt,
  });

  final String id;
  final String slug;
  final String eventDate;
  final int fiscalYear;
  final AgriPolicyPhase phase;
  final String title;
  final String summary;
  final List<String> tags;
  final List<String> relatedNodes;
  final FactCheckStatus factCheckStatus;
  final String sourceCitation;
  final String policyImpactNotes;
  final String? verifiedAt;

  factory AgriPolicyEvent.fromJson(final Map<String, Object?> json) {
    final rawDate = (json['event_date'] ?? '2018-04-01').toString().trim();
    final parsedYear = _asInt(json['fiscal_year']);
    final fallbackYear = int.tryParse(rawDate.split('-').first) ?? 2018;
    final cleanVerifiedAt = (json['verified_at'] ?? '').toString().trim();
    return AgriPolicyEvent(
      id: (json['id'] ?? '').toString().trim(),
      slug: (json['slug'] ?? '').toString().trim(),
      eventDate: rawDate,
      fiscalYear: parsedYear > 0 ? parsedYear : fallbackYear,
      phase: AgriPolicyPhase.fromWire(json['phase']?.toString()),
      title: (json['title'] ?? '').toString().trim(),
      summary: (json['summary'] ?? '').toString().trim(),
      tags: _asStringList(json['tags']),
      relatedNodes: _asStringList(json['related_nodes']),
      factCheckStatus: FactCheckStatus.fromWire(
        json['fact_check_status']?.toString(),
      ),
      sourceCitation: (json['source_citation'] ?? '').toString().trim(),
      policyImpactNotes: (json['policy_impact_notes'] ?? '').toString().trim(),
      verifiedAt: cleanVerifiedAt.isEmpty ? null : cleanVerifiedAt,
    );
  }
}

@immutable
class AgriKnowledgeEdge {
  const AgriKnowledgeEdge({
    required this.fromEventId,
    required this.toEventId,
    required this.sharedTerms,
  });

  final String fromEventId;
  final String toEventId;
  final List<String> sharedTerms;

  factory AgriKnowledgeEdge.fromJson(final Map<String, Object?> json) {
    return AgriKnowledgeEdge(
      fromEventId: (json['from_event_id'] ?? '').toString().trim(),
      toEventId: (json['to_event_id'] ?? '').toString().trim(),
      sharedTerms: _asStringList(json['shared_terms']),
    );
  }
}

@immutable
class AgriPolicyTimelineSnapshot {
  const AgriPolicyTimelineSnapshot({
    required this.events,
    required this.totalCount,
    required this.filteredCount,
    required this.seededCount,
    required this.availableTags,
    required this.knowledgeEdges,
  });

  final List<AgriPolicyEvent> events;
  final int totalCount;
  final int filteredCount;
  final int seededCount;
  final List<String> availableTags;
  final List<AgriKnowledgeEdge> knowledgeEdges;

  factory AgriPolicyTimelineSnapshot.fromJson(final Map<String, Object?> json) {
    final rawEvents = json['events'];
    final events = rawEvents is List<Object?>
        ? rawEvents
            .map(normalizeAgriJsonMap)
            .where((final Map<String, Object?> row) => row.isNotEmpty)
            .map(AgriPolicyEvent.fromJson)
            .toList(growable: false)
        : const <AgriPolicyEvent>[];

    final rawEdges = json['knowledge_edges'];
    final edges = rawEdges is List<Object?>
        ? rawEdges
            .map(normalizeAgriJsonMap)
            .where((final Map<String, Object?> row) => row.isNotEmpty)
            .map(AgriKnowledgeEdge.fromJson)
            .toList(growable: false)
        : const <AgriKnowledgeEdge>[];

    final tags = _asStringList(json['available_tags']);
    return AgriPolicyTimelineSnapshot(
      events: events,
      totalCount: _asInt(json['total_count'], fallback: events.length),
      filteredCount: _asInt(json['filtered_count'], fallback: events.length),
      seededCount: _asInt(json['seeded_count']),
      availableTags: tags.isEmpty ? kDefaultAgriKeywordTags : tags,
      knowledgeEdges: edges,
    );
  }
}

Map<String, Object?> normalizeAgriJsonMap(final Object? raw) {
  if (raw is Map<Object?, Object?>) {
    return raw.map<String, Object?>(
      (final Object? key, final Object? value) =>
          MapEntry<String, Object?>(key.toString(), value),
    );
  }
  return const <String, Object?>{};
}

int _asInt(final Object? value, {final int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _asStringList(final Object? raw) {
  if (raw is! List<Object?>) {
    return const <String>[];
  }
  return raw
      .map((final Object? item) => (item ?? '').toString().trim())
      .where((final String item) => item.isNotEmpty)
      .toList(growable: false);
}

abstract class AgriPolicyRepository {
  Future<AgriPolicyTimelineSnapshot> fetchTimeline({
    final String? query,
    final String? tag,
    final AgriPolicyPhase? phase,
    final FactCheckStatus? factCheckStatus,
    final bool seedIfEmpty = true,
  });

  Future<AgriPolicyEvent> createEvent({
    required final String eventDate,
    required final String title,
    required final String summary,
    required final List<String> tags,
    required final List<String> relatedNodes,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  });

  Future<AgriPolicyEvent> updateFactCheck({
    required final String id,
    required final FactCheckStatus factCheckStatus,
    required final String sourceCitation,
    required final String policyImpactNotes,
  });
}
