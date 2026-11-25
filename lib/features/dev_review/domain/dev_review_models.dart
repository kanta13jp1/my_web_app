import 'package:flutter/foundation.dart';

Map<String, Object?> normalizeJsonObject(Object? raw, String context) {
  if (raw is! Map<Object?, Object?>) {
    throw FormatException('Expected JSON object for $context.');
  }
  final result = <String, Object?>{};
  for (final entry in raw.entries) {
    final Object? key = entry.key;
    if (key is! String) {
      throw FormatException('Expected String key in $context.');
    }
    result[key] = entry.value;
  }
  return result;
}

String _readString(Map<String, Object?> json, String key, {String def = ''}) {
  final Object? raw = json[key];
  if (raw == null) {
    return def;
  }
  if (raw is! String) {
    throw FormatException('Expected String for "$key".');
  }
  return raw;
}

String _requireNonEmptyString(Map<String, Object?> json, String key) {
  final val = _readString(json, key).trim();
  if (val.isEmpty) {
    throw FormatException('Missing non-empty String "$key".');
  }
  return val;
}

int _requireInt(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! int) {
    throw FormatException('Expected int for "$key".');
  }
  return raw;
}

enum DevReviewPhase {
  intake('intake', '受付 (Intake)'),
  design('design', '設計 (Design)'),
  implementation('implementation', '実装 (Implementation)'),
  verification('verification', '検証 (Verification)'),
  release('release', '公開 (Release)');

  const DevReviewPhase(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  DevReviewPhase? get nextPhase {
    final idx = DevReviewPhase.values.indexOf(this);
    if (idx < 0 || idx + 1 >= DevReviewPhase.values.length) {
      return null;
    }
    return DevReviewPhase.values[idx + 1];
  }

  static DevReviewPhase fromWire(Object? raw) {
    if (raw is String) {
      for (final value in DevReviewPhase.values) {
        if (value.wireValue == raw) {
          return value;
        }
      }
    }
    throw FormatException('Unknown DevReviewPhase: "$raw".');
  }
}

enum DevReviewItemStatus {
  pending('pending', '未着手'),
  inReview('in_review', 'レビュー中'),
  changesRequested('changes_requested', '要修正'),
  approved('approved', '承認済み');

  const DevReviewItemStatus(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static DevReviewItemStatus fromWire(Object? raw) {
    if (raw is String) {
      for (final value in DevReviewItemStatus.values) {
        if (value.wireValue == raw) {
          return value;
        }
      }
    }
    throw FormatException('Unknown DevReviewItemStatus: "$raw".');
  }
}

enum DevReviewItemKind {
  checklist('checklist', 'チェックリスト'),
  testVariation('test_variation', 'テスト観点'),
  finding('finding', '指摘事項');

  const DevReviewItemKind(this.wireValue, this.labelJa);

  final String wireValue;
  final String labelJa;

  static DevReviewItemKind fromWire(Object? raw) {
    if (raw is String) {
      for (final value in DevReviewItemKind.values) {
        if (value.wireValue == raw) {
          return value;
        }
      }
    }
    throw FormatException('Unknown DevReviewItemKind: "$raw".');
  }
}

@immutable
class DevReviewChecklistItem {
  const DevReviewChecklistItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.status,
    required this.assignee,
    required this.note,
    required this.updatedAt,
  });

  final String id;
  final DevReviewItemKind kind;
  final String title;
  final String category;
  final DevReviewItemStatus status;
  final String assignee;
  final String note;
  final String updatedAt;

  bool get isApproved => status == DevReviewItemStatus.approved;

  factory DevReviewChecklistItem.fromJson(Map<String, Object?> json) {
    return DevReviewChecklistItem(
      id: _requireNonEmptyString(json, 'id'),
      kind: DevReviewItemKind.fromWire(json['kind']),
      title: _requireNonEmptyString(json, 'title'),
      category: _readString(json, 'category'),
      status: DevReviewItemStatus.fromWire(json['status']),
      assignee: _readString(json, 'assignee', def: 'unassigned'),
      note: _readString(json, 'note'),
      updatedAt: _readString(json, 'updatedAt'),
    );
  }
}

@immutable
class DevReviewGithubSnapshot {
  const DevReviewGithubSnapshot({
    required this.repo,
    required this.targetType,
    required this.number,
    required this.url,
    required this.state,
    required this.reviewDecision,
    required this.syncedAt,
  });

  final String repo;
  final String targetType;
  final int number;
  final String url;
  final String state;
  final String reviewDecision;
  final String syncedAt;

  factory DevReviewGithubSnapshot.fromJson(Map<String, Object?> json) {
    return DevReviewGithubSnapshot(
      repo: _readString(json, 'repo'),
      targetType: _readString(json, 'targetType', def: 'issue'),
      number: _requireInt(json, 'number'),
      url: _readString(json, 'url'),
      state: _readString(json, 'state', def: 'open'),
      reviewDecision: _readString(json, 'reviewDecision', def: 'none'),
      syncedAt: _readString(json, 'syncedAt'),
    );
  }
}

@immutable
class DevReviewSession {
  const DevReviewSession({
    required this.id,
    required this.title,
    required this.targetType,
    required this.githubRepo,
    required this.targetNumber,
    required this.currentPhase,
    required this.approver,
    required this.items,
    required this.githubSnapshot,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String targetType;
  final String githubRepo;
  final int targetNumber;
  final DevReviewPhase currentPhase;
  final String approver;
  final List<DevReviewChecklistItem> items;
  final DevReviewGithubSnapshot? githubSnapshot;
  final String updatedAt;

  int get approvedCount => items.where((item) => item.isApproved).length;

  List<String> blockingReasonsForNextPhase() {
    final reasons = <String>[];
    if (items.isEmpty) {
      reasons.add('レビュー項目が 0 件のためフェーズ移行できません。');
    }
    for (final item in items) {
      if (!item.isApproved) {
        reasons.add('${item.title} (${item.status.labelJa})');
      }
    }
    if (githubSnapshot?.reviewDecision == 'changes_requested') {
      reasons.add('GitHub レビューが changes_requested です。');
    }
    if (approver.trim().isEmpty) {
      reasons.add('最終承認者 (approver) が未設定です。');
    }
    return List<String>.unmodifiable(reasons);
  }

  factory DevReviewSession.fromJson(Map<String, Object?> json) {
    final Object? rawItems = json['items'];
    if (rawItems is! List<Object?>) {
      throw const FormatException('Missing List "items".');
    }
    final items = rawItems
        .map(
          (item) => DevReviewChecklistItem.fromJson(
            normalizeJsonObject(item, 'items[]'),
          ),
        )
        .toList(growable: false);

    final Object? rawSnap = json['githubSnapshot'];
    final DevReviewGithubSnapshot? snapshot = rawSnap == null
        ? null
        : DevReviewGithubSnapshot.fromJson(
            normalizeJsonObject(rawSnap, 'githubSnapshot'),
          );

    return DevReviewSession(
      id: _requireNonEmptyString(json, 'id'),
      title: _requireNonEmptyString(json, 'title'),
      targetType: _readString(json, 'targetType', def: 'issue'),
      githubRepo: _readString(json, 'githubRepo'),
      targetNumber: _requireInt(json, 'targetNumber'),
      currentPhase: DevReviewPhase.fromWire(json['currentPhase']),
      approver: _readString(json, 'approver'),
      items: List<DevReviewChecklistItem>.unmodifiable(items),
      githubSnapshot: snapshot,
      updatedAt: _readString(json, 'updatedAt'),
    );
  }
}

@immutable
class PhaseAdvanceOutcome {
  const PhaseAdvanceOutcome({
    required this.blocked,
    required this.blockingReasons,
    this.updatedSession,
  });

  final bool blocked;
  final List<String> blockingReasons;
  final DevReviewSession? updatedSession;
}

abstract interface class DevReviewTrackingRepository {
  Future<List<DevReviewSession>> listSessions({
    String statusFilter = 'all',
    String assigneeFilter = '',
  });

  Future<DevReviewSession> createSession({
    required String title,
    required String targetType,
    required String githubRepo,
    required int targetNumber,
    required String approver,
    required String assignee,
  });

  Future<DevReviewSession> updateItemStatus({
    required String sessionId,
    required String itemId,
    required DevReviewItemStatus status,
    required String assignee,
    required String note,
  });

  Future<DevReviewSession> addFinding({
    required String sessionId,
    required String title,
    required String assignee,
    required String note,
  });

  Future<DevReviewSession> syncGithubStatus({
    required String sessionId,
    required String state,
    required String reviewDecision,
    bool fetchLive = false,
  });

  Future<PhaseAdvanceOutcome> advancePhase({
    required String sessionId,
    required DevReviewPhase targetPhase,
    required String note,
  });
}
