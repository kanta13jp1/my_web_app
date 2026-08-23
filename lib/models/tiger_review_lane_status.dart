import 'dart:convert';

class TigerReviewLaneStatus {
  const TigerReviewLaneStatus({
    required this.schemaVersion,
    required this.lane,
    required this.generatedAt,
    required this.publicationState,
    required this.automation,
    required this.pool,
    required this.latest,
    required this.history,
    required this.entries,
    required this.disclaimer,
  });

  final int schemaVersion;
  final String lane;
  final DateTime? generatedAt;
  final String publicationState;
  final TigerLaneAutomation automation;
  final Map<String, dynamic> pool;
  final Map<String, dynamic>? latest;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> entries;
  final String disclaimer;

  factory TigerReviewLaneStatus.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Tiger review lane snapshot must be an object.',
      );
    }
    return TigerReviewLaneStatus.fromJson(decoded);
  }

  factory TigerReviewLaneStatus.fromJson(Map<String, dynamic> json) {
    final lane = json['lane'];
    if (lane is! String || lane.isEmpty) {
      throw const FormatException('Tiger review lane is required.');
    }
    final listKey = switch (lane) {
      'reviewer_league' => 'reviewers',
      'course_review' => 'courses',
      'feature_review' => 'features',
      _ => null,
    };
    final rawEntries = listKey == null ? const <dynamic>[] : json[listKey];
    return TigerReviewLaneStatus(
      schemaVersion:
          json['schema_version'] is int ? json['schema_version'] as int : 0,
      lane: lane,
      generatedAt: DateTime.tryParse(json['generated_at']?.toString() ?? ''),
      publicationState: json['publication_state']?.toString() ?? '',
      automation: TigerLaneAutomation.fromJson(_map(json['automation'])),
      pool: _map(json['pool']),
      latest: _nullableMap(
        lane == 'reviewer_league'
            ? json['latest_assignment']
            : json['latest_review'],
      ),
      history: _mapList(json['history']),
      entries: rawEntries is List
          ? rawEntries
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .toList(growable: false)
          : const <Map<String, dynamic>>[],
      disclaimer: json['disclaimer']?.toString() ?? '',
    );
  }
}

List<Map<String, dynamic>> _mapList(Object? value) {
  return value is List
      ? value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];
}

class TigerLaneAutomation {
  const TigerLaneAutomation({
    required this.id,
    required this.name,
    required this.status,
    required this.schedule,
  });

  final String id;
  final String name;
  final String status;
  final String schedule;

  factory TigerLaneAutomation.fromJson(Map<String, dynamic> json) {
    return TigerLaneAutomation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      schedule: json['schedule']?.toString() ?? '',
    );
  }
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

Map<String, dynamic>? _nullableMap(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}
