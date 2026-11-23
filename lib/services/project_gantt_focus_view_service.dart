import 'package:flutter/material.dart';

import '../pages/project_gantt_page.dart';

/// `/project-gantt` の WBS タブ内で切り替えるフォーカス View (#2230 #2231 #2233)。
enum ProjectGanttFocusView {
  wbs,
  sprint,
  milestone,
  blocker;

  String get label => switch (this) {
        ProjectGanttFocusView.wbs => '開発WBS',
        ProjectGanttFocusView.sprint => 'スプリントView',
        ProjectGanttFocusView.milestone => 'マイルストーンView',
        ProjectGanttFocusView.blocker => 'ブロッカーView',
      };

  IconData get icon => switch (this) {
        ProjectGanttFocusView.wbs => Icons.account_tree_outlined,
        ProjectGanttFocusView.sprint => Icons.bolt_outlined,
        ProjectGanttFocusView.milestone => Icons.flag_outlined,
        ProjectGanttFocusView.blocker => Icons.block_outlined,
      };

  String get keySuffix => switch (this) {
        ProjectGanttFocusView.wbs => 'wbs',
        ProjectGanttFocusView.sprint => 'sprint',
        ProjectGanttFocusView.milestone => 'milestone',
        ProjectGanttFocusView.blocker => 'blocker',
      };
}

/// スプリント View 用の集計結果 (#2230)。
class SprintViewData {
  final DateTime windowStart;
  final DateTime windowEnd;
  final List<WbsTask> activeTasks;
  final List<WbsTask> completedInWindowTasks;
  final int overdueCount;
  final int inProgressCount;
  final double averageProgress;

  const SprintViewData({
    required this.windowStart,
    required this.windowEnd,
    required this.activeTasks,
    required this.completedInWindowTasks,
    required this.overdueCount,
    required this.inProgressCount,
    required this.averageProgress,
  });
}

/// マイルストーン View 用のグループ集計結果 (#2231)。
class MilestoneViewGroup {
  final WbsMilestone? milestone;
  final List<WbsTask> tasks;
  final int completedCount;
  final int inProgressCount;
  final int daysLeft;
  final bool isAtRisk;

  const MilestoneViewGroup({
    required this.milestone,
    required this.tasks,
    required this.completedCount,
    required this.inProgressCount,
    required this.daysLeft,
    required this.isAtRisk,
  });

  double get completionRate =>
      tasks.isEmpty ? 0.0 : completedCount / tasks.length;
}

/// ブロッカー View 用のタスク項目 (#2233)。
class BlockerTaskItem {
  final WbsTask task;
  final List<WbsTask> downstreamBlockedTasks;
  final bool hasExplicitBlockedStatus;
  final bool hasRecoveryPlan;

  const BlockerTaskItem({
    required this.task,
    required this.downstreamBlockedTasks,
    required this.hasExplicitBlockedStatus,
    required this.hasRecoveryPlan,
  });
}

/// 実データ (`WbsTask` / `WbsMilestone`) からフォーカス View 用サマリーを構築する。
class ProjectGanttFocusViewService {
  const ProjectGanttFocusViewService._();

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static int _priorityRank(String priority) => switch (priority.toLowerCase()) {
        'critical' || 'p0' => 0,
        'high' || 'p1' => 1,
        'medium' || 'p2' => 2,
        _ => 3,
      };

  static String _normalizeDependencyKey(String raw) => raw
      .replaceFirst(RegExp(r'^\s*\[Issue #\d+\]\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  static int? _extractIssueRef(String raw) {
    final m = RegExp(r'#(\d+)').firstMatch(raw);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  /// 今週（月曜〜日曜）のスプリント対象タスクを集計する。
  static SprintViewData buildSprintSummary(
    List<WbsTask> tasks, {
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final today = _dayOnly(ref);
    final windowStart = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final windowEnd = windowStart.add(const Duration(days: 6));

    final activeTasks = <WbsTask>[];
    final completedInWindow = <WbsTask>[];
    var overdueCount = 0;
    var inProgressCount = 0;

    for (final task in tasks) {
      final start = task.scheduleStartDate != null
          ? _dayOnly(task.scheduleStartDate!)
          : null;
      final end =
          task.scheduleEndDate != null ? _dayOnly(task.scheduleEndDate!) : null;

      final bool overlapsWindow;
      if (start != null && end != null) {
        overlapsWindow =
            !start.isAfter(windowEnd) && !end.isBefore(windowStart);
      } else if (start != null) {
        overlapsWindow = !start.isAfter(windowEnd);
      } else if (end != null) {
        overlapsWindow = !end.isBefore(windowStart);
      } else {
        overlapsWindow = false;
      }

      if (task.isEffectivelyCompleted) {
        final updated =
            task.updatedAt != null ? _dayOnly(task.updatedAt!) : null;
        final updatedInWindow = updated != null &&
            !updated.isBefore(windowStart) &&
            !updated.isAfter(windowEnd);
        if (overlapsWindow || updatedInWindow) {
          completedInWindow.add(task);
        }
        continue;
      }

      final isOverdue = end != null && end.isBefore(today);
      final isInProgress = task.status == 'in_progress';
      if (isInProgress || overlapsWindow || isOverdue) {
        activeTasks.add(task);
        if (isOverdue) {
          overdueCount++;
        }
        if (isInProgress) {
          inProgressCount++;
        }
      }
    }

    activeTasks.sort((a, b) {
      final aEnd =
          a.scheduleEndDate != null ? _dayOnly(a.scheduleEndDate!) : null;
      final bEnd =
          b.scheduleEndDate != null ? _dayOnly(b.scheduleEndDate!) : null;
      final aOverdue = aEnd != null && aEnd.isBefore(today);
      final bOverdue = bEnd != null && bEnd.isBefore(today);
      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }
      final aProg = a.status == 'in_progress';
      final bProg = b.status == 'in_progress';
      if (aProg != bProg) {
        return aProg ? -1 : 1;
      }
      final pri =
          _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
      if (pri != 0) {
        return pri;
      }
      if (aEnd != null && bEnd != null) {
        final dateCmp = aEnd.compareTo(bEnd);
        if (dateCmp != 0) {
          return dateCmp;
        }
      } else if (aEnd != null || bEnd != null) {
        return aEnd != null ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });

    final averageProgress = activeTasks.isEmpty
        ? 0.0
        : activeTasks.map((t) => t.progress).reduce((a, b) => a + b) /
            activeTasks.length;

    return SprintViewData(
      windowStart: windowStart,
      windowEnd: windowEnd,
      activeTasks: activeTasks,
      completedInWindowTasks: completedInWindow,
      overdueCount: overdueCount,
      inProgressCount: inProgressCount,
      averageProgress: averageProgress,
    );
  }

  /// マイルストーン単位の完了状況を集計する。
  static List<MilestoneViewGroup> buildMilestoneSummaries(
    List<WbsMilestone> milestones,
    List<WbsTask> tasks, {
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final groupedByCode = <String, List<WbsTask>>{};
    final unassigned = <WbsTask>[];
    final knownCodes = milestones.map((m) => m.code).toSet();

    for (final task in tasks) {
      final code = task.milestoneCode?.trim() ?? '';
      if (code.isNotEmpty && knownCodes.contains(code)) {
        (groupedByCode[code] ??= <WbsTask>[]).add(task);
      } else {
        unassigned.add(task);
      }
    }

    final result = <MilestoneViewGroup>[];
    for (final milestone in milestones) {
      final bucket = groupedByCode[milestone.code] ?? const <WbsTask>[];
      final completed = bucket.where((t) => t.isEffectivelyCompleted).length;
      final inProgress = bucket
          .where((t) => !t.isEffectivelyCompleted && t.status == 'in_progress')
          .length;
      final daysLeft = milestone.daysLeft(ref);
      final remaining = bucket.length - completed;
      final isAtRisk = !milestone.achieved && daysLeft <= 14 && remaining > 0;
      result.add(
        MilestoneViewGroup(
          milestone: milestone,
          tasks: bucket,
          completedCount: completed,
          inProgressCount: inProgress,
          daysLeft: daysLeft,
          isAtRisk: isAtRisk,
        ),
      );
    }

    if (unassigned.isNotEmpty) {
      final completed =
          unassigned.where((t) => t.isEffectivelyCompleted).length;
      final inProgress = unassigned
          .where((t) => !t.isEffectivelyCompleted && t.status == 'in_progress')
          .length;
      result.add(
        MilestoneViewGroup(
          milestone: null,
          tasks: unassigned,
          completedCount: completed,
          inProgressCount: inProgress,
          daysLeft: 0,
          isAtRisk: false,
        ),
      );
    }

    return result;
  }

  /// 他タスクを停止させているタスク・明示的ブロック中タスクを抽出する。
  static List<BlockerTaskItem> buildBlockerItems(List<WbsTask> tasks) {
    final incomplete =
        tasks.where((t) => !t.isEffectivelyCompleted).toList(growable: false);
    final items = <BlockerTaskItem>[];

    for (final candidate in incomplete) {
      final candidateNormTitle = _normalizeDependencyKey(candidate.title);
      final candidateRawTitle = candidate.title.trim().toLowerCase();
      final candidateIssue = candidate.linkedGithubIssueNumber;
      final downstream = <WbsTask>[];

      for (final other in incomplete) {
        if (other.id == candidate.id) {
          continue;
        }
        var matched = false;
        for (final dep in other.dependsOnTitles) {
          final depNorm = _normalizeDependencyKey(dep);
          final depRaw = dep.trim().toLowerCase();
          final depIssue = _extractIssueRef(dep);
          if ((candidateNormTitle.isNotEmpty &&
                  depNorm == candidateNormTitle) ||
              (candidateRawTitle.isNotEmpty && depRaw == candidateRawTitle) ||
              (candidateIssue != null &&
                  depIssue != null &&
                  depIssue == candidateIssue)) {
            matched = true;
            break;
          }
        }
        if (matched) {
          downstream.add(other);
        }
      }

      final explicitBlocked = candidate.status == 'blocked';
      final hasRecovery = candidate.recoveryPlan.trim().isNotEmpty;
      if (downstream.isNotEmpty || explicitBlocked || hasRecovery) {
        items.add(
          BlockerTaskItem(
            task: candidate,
            downstreamBlockedTasks: downstream,
            hasExplicitBlockedStatus: explicitBlocked,
            hasRecoveryPlan: hasRecovery,
          ),
        );
      }
    }

    items.sort((a, b) {
      final downCmp = b.downstreamBlockedTasks.length
          .compareTo(a.downstreamBlockedTasks.length);
      if (downCmp != 0) {
        return downCmp;
      }
      if (a.hasExplicitBlockedStatus != b.hasExplicitBlockedStatus) {
        return a.hasExplicitBlockedStatus ? -1 : 1;
      }
      final pri = _priorityRank(a.task.priority)
          .compareTo(_priorityRank(b.task.priority));
      if (pri != 0) {
        return pri;
      }
      return a.task.title.compareTo(b.task.title);
    });

    return items;
  }
}
