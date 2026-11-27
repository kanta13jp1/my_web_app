import 'package:flutter/foundation.dart';

enum DiscussionStage {
  generalDebate('general_debate', '総論討議'),
  drafting('drafting', '条文起草'),
  agreed('agreed', '合意済み'),
  submitted('submitted', '原案提出');

  final String wireKey;
  final String labelJa;

  const DiscussionStage(this.wireKey, this.labelJa);

  DiscussionStage? get nextStage {
    final idx = DiscussionStage.values.indexOf(this);
    if (idx < 0 || idx + 1 >= DiscussionStage.values.length) {
      return null;
    }
    return DiscussionStage.values[idx + 1];
  }
}

class DiscussionMilestone {
  final String id;
  final String topic;
  final DiscussionStage stage;
  final DateTime targetDate;
  final String ownerGroup;
  final DateTime updatedAt;

  const DiscussionMilestone({
    required this.id,
    required this.topic,
    required this.stage,
    required this.targetDate,
    required this.ownerGroup,
    required this.updatedAt,
  });

  DiscussionMilestone copyWith({
    DiscussionStage? stage,
    DateTime? targetDate,
    DateTime? updatedAt,
  }) {
    return DiscussionMilestone(
      id: id,
      topic: topic,
      stage: stage ?? this.stage,
      targetDate: targetDate ?? this.targetDate,
      ownerGroup: ownerGroup,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MilestoneScheduleAuditEntry {
  final String id;
  final String milestoneId;
  final String topic;
  final DiscussionStage previousStage;
  final DiscussionStage nextStage;
  final DateTime previousTargetDate;
  final DateTime nextTargetDate;
  final int deltaDays;
  final String reason;
  final DateTime recordedAt;

  const MilestoneScheduleAuditEntry({
    required this.id,
    required this.milestoneId,
    required this.topic,
    required this.previousStage,
    required this.nextStage,
    required this.previousTargetDate,
    required this.nextTargetDate,
    required this.deltaDays,
    required this.reason,
    required this.recordedAt,
  });
}

/// Manages discussion roadmap milestones and immutable schedule-change audits.
class DiscussionRoadmapService extends ChangeNotifier {
  final Map<String, DiscussionMilestone> _milestones =
      <String, DiscussionMilestone>{};
  final List<MilestoneScheduleAuditEntry> _auditHistory =
      <MilestoneScheduleAuditEntry>[];
  final DateTime Function() _now;
  int _auditSeq = 0;

  DiscussionRoadmapService({
    List<DiscussionMilestone> initialMilestones = const <DiscussionMilestone>[],
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    for (final item in initialMilestones) {
      _milestones[item.id] = item;
    }
  }

  List<DiscussionMilestone> listMilestones({DiscussionStage? stageFilter}) {
    final values = _milestones.values;
    if (stageFilter == null) {
      return values.toList(growable: false);
    }
    return values
        .where((item) => item.stage == stageFilter)
        .toList(growable: false);
  }

  List<MilestoneScheduleAuditEntry> listAuditHistory({String? milestoneId}) {
    if (milestoneId == null) {
      return List<MilestoneScheduleAuditEntry>.unmodifiable(_auditHistory);
    }
    return _auditHistory
        .where((entry) => entry.milestoneId == milestoneId)
        .toList(growable: false);
  }

  void registerMilestone({
    required String id,
    required String topic,
    required DiscussionStage stage,
    required DateTime targetDate,
    required String ownerGroup,
  }) {
    _milestones[id] = DiscussionMilestone(
      id: id,
      topic: topic.trim(),
      stage: stage,
      targetDate:
          DateTime.utc(targetDate.year, targetDate.month, targetDate.day),
      ownerGroup: ownerGroup.trim(),
      updatedAt: _now().toUtc(),
    );
    notifyListeners();
  }

  MilestoneScheduleAuditEntry? updateMilestoneSchedule({
    required String milestoneId,
    DiscussionStage? nextStage,
    DateTime? nextTargetDate,
    required String reason,
  }) {
    final existing = _milestones[milestoneId];
    if (existing == null) return null;

    final nowUtc = _now().toUtc();
    final targetStage = nextStage ?? existing.stage;
    final normalizedNextDate = nextTargetDate != null
        ? DateTime.utc(
            nextTargetDate.year,
            nextTargetDate.month,
            nextTargetDate.day,
          )
        : existing.targetDate;
    final deltaDays = normalizedNextDate.difference(existing.targetDate).inDays;

    _milestones[milestoneId] = existing.copyWith(
      stage: targetStage,
      targetDate: normalizedNextDate,
      updatedAt: nowUtc,
    );

    _auditSeq += 1;
    final audit = MilestoneScheduleAuditEntry(
      id: 'audit-$_auditSeq',
      milestoneId: milestoneId,
      topic: existing.topic,
      previousStage: existing.stage,
      nextStage: targetStage,
      previousTargetDate: existing.targetDate,
      nextTargetDate: normalizedNextDate,
      deltaDays: deltaDays,
      reason: reason.trim(),
      recordedAt: nowUtc,
    );
    _auditHistory.insert(0, audit);
    notifyListeners();
    return audit;
  }
}
