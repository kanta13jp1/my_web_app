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
  final List<TigerReviewHistoryEntry> history;
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
      history: _list(
        json['history'],
      ).map(TigerReviewHistoryEntry.fromJson).toList(growable: false),
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

class TigerReviewHistoryEntry {
  const TigerReviewHistoryEntry({
    required this.cycleId,
    required this.startedAt,
    required this.subject,
    required this.reviewer,
    required this.reviewStatus,
    required this.validationStatus,
    required this.findings,
    required this.countermeasure,
  });

  final String cycleId;
  final DateTime? startedAt;
  final TigerReviewHistorySubject subject;
  final TigerReviewHistoryReviewer reviewer;
  final String reviewStatus;
  final String validationStatus;
  final List<TigerReviewHistoryFinding> findings;
  final TigerCountermeasureTrace countermeasure;

  factory TigerReviewHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TigerReviewHistoryEntry(
      cycleId: json['cycle_id']?.toString() ?? '',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      subject: TigerReviewHistorySubject.fromJson(_map(json['subject'])),
      reviewer: TigerReviewHistoryReviewer.fromJson(_map(json['reviewer'])),
      reviewStatus: json['review_status']?.toString() ?? '',
      validationStatus: json['validation_status']?.toString() ?? '',
      findings: _list(
        json['findings'],
      ).map(TigerReviewHistoryFinding.fromJson).toList(growable: false),
      countermeasure: TigerCountermeasureTrace.fromJson(
        _map(json['countermeasure']),
      ),
    );
  }
}

class TigerReviewHistorySubject {
  const TigerReviewHistorySubject({
    required this.kind,
    required this.id,
    required this.title,
  });

  final String kind;
  final String id;
  final String title;

  factory TigerReviewHistorySubject.fromJson(Map<String, dynamic> json) {
    return TigerReviewHistorySubject(
      kind: json['kind']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class TigerReviewHistoryReviewer {
  const TigerReviewHistoryReviewer({required this.seat, required this.name});

  final int? seat;
  final String name;

  factory TigerReviewHistoryReviewer.fromJson(Map<String, dynamic> json) {
    return TigerReviewHistoryReviewer(
      seat: json['seat'] is int ? json['seat'] as int : null,
      name: json['name']?.toString() ?? '',
    );
  }
}

class TigerReviewHistoryFinding {
  const TigerReviewHistoryFinding({
    required this.id,
    required this.summary,
    required this.severity,
    required this.suggestedAction,
  });

  final String id;
  final String summary;
  final String severity;
  final String suggestedAction;

  factory TigerReviewHistoryFinding.fromJson(Map<String, dynamic> json) {
    return TigerReviewHistoryFinding(
      id: json['finding_id']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      suggestedAction: json['suggested_action']?.toString() ?? '',
    );
  }
}

class TigerCountermeasureTrace {
  const TigerCountermeasureTrace({
    required this.state,
    required this.label,
    required this.detail,
    required this.summary,
    required this.files,
    required this.validationStatus,
    required this.validationMessages,
    required this.findingsWithoutIndividualTrace,
    required this.issue,
    required this.implementation,
  });

  final String state;
  final String label;
  final String detail;
  final String summary;
  final List<String> files;
  final String validationStatus;
  final List<String> validationMessages;
  final List<String> findingsWithoutIndividualTrace;
  final TigerFollowUpIssue? issue;
  final TigerReviewImplementation? implementation;

  factory TigerCountermeasureTrace.fromJson(Map<String, dynamic> json) {
    return TigerCountermeasureTrace(
      state: json['state']?.toString() ?? 'unverified',
      label: json['label']?.toString() ?? '対策状況を確認できません',
      detail: json['detail']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      files: _list(json['files']).map((value) => value.toString()).toList(),
      validationStatus: json['validation_status']?.toString() ?? '',
      validationMessages: _list(
        json['validation_messages'],
      ).map((value) => value.toString()).toList(),
      findingsWithoutIndividualTrace: _list(
        json['findings_without_individual_trace'],
      ).map((value) => value.toString()).toList(),
      issue: _followUpIssue(json['issue']),
      implementation: _implementation(json['implementation']),
    );
  }
}

class TigerFollowUpIssue {
  const TigerFollowUpIssue({
    required this.number,
    required this.url,
    required this.githubState,
    this.remediationState = '',
    this.queueStatus = '',
    this.syncedAt,
  });

  final int? number;
  final Uri? url;
  final String githubState;
  final String remediationState;
  final String queueStatus;
  final DateTime? syncedAt;

  bool get isOpen => githubState.toUpperCase() == 'OPEN';
  bool get isClosed => githubState.toUpperCase() == 'CLOSED';

  factory TigerFollowUpIssue.fromJson(Map<String, dynamic> json) {
    return TigerFollowUpIssue(
      number: json['number'] is int ? json['number'] as int : null,
      url: Uri.tryParse(json['url']?.toString() ?? ''),
      githubState:
          (json['github_state'] ?? json['issue_state'])?.toString() ?? '',
      remediationState: json['remediation_state']?.toString() ?? '',
      queueStatus: json['queue_status']?.toString() ?? '',
      syncedAt: DateTime.tryParse(json['synced_at']?.toString() ?? ''),
    );
  }
}

class TigerReviewImplementation {
  const TigerReviewImplementation({
    required this.commitSha,
    required this.workflowRun,
    required this.productionUrl,
    required this.releaseStatus,
    this.prNumber,
    this.prUrl,
    this.workflowUrl,
  });

  final String commitSha;
  final String workflowRun;
  final Uri? productionUrl;
  final String releaseStatus;
  final int? prNumber;
  final Uri? prUrl;
  final Uri? workflowUrl;

  factory TigerReviewImplementation.fromJson(Map<String, dynamic> json) {
    return TigerReviewImplementation(
      commitSha: json['commit_sha']?.toString() ?? '',
      workflowRun: json['workflow_run']?.toString() ?? '',
      productionUrl: Uri.tryParse(json['production_url']?.toString() ?? ''),
      releaseStatus: json['release_status']?.toString() ?? '',
      prNumber: json['pr_number'] is int ? json['pr_number'] as int : null,
      prUrl: Uri.tryParse(json['pr_url']?.toString() ?? ''),
      workflowUrl: Uri.tryParse(json['workflow_url']?.toString() ?? ''),
    );
  }
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

List<Map<String, dynamic>> _list(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

TigerFollowUpIssue? _followUpIssue(Object? value) {
  final data = _nullableMap(value);
  return data == null || data.isEmpty
      ? null
      : TigerFollowUpIssue.fromJson(data);
}

TigerReviewImplementation? _implementation(Object? value) {
  final data = _nullableMap(value);
  return data == null ? null : TigerReviewImplementation.fromJson(data);
}
