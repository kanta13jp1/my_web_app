import 'package:flutter/material.dart';

import '../pages/project_gantt_page.dart';

/// `/project-gantt` の WBS タブ内で切り替えるフォーカス View (#2230 #2231 #2233 #2234 #2237 #2242)。
enum ProjectGanttFocusView {
  wbs,
  sprint,
  milestone,
  blocker,
  owner,
  dashboard,
  techDebt;

  String get label => switch (this) {
        ProjectGanttFocusView.wbs => '開発WBS',
        ProjectGanttFocusView.sprint => 'スプリントView',
        ProjectGanttFocusView.milestone => 'マイルストーンView',
        ProjectGanttFocusView.blocker => 'ブロッカーView',
        ProjectGanttFocusView.owner => '担当者別View',
        ProjectGanttFocusView.dashboard => '進捗ダッシュボードView',
        ProjectGanttFocusView.techDebt => '技術的負債View',
      };

  IconData get icon => switch (this) {
        ProjectGanttFocusView.wbs => Icons.account_tree_outlined,
        ProjectGanttFocusView.sprint => Icons.bolt_outlined,
        ProjectGanttFocusView.milestone => Icons.flag_outlined,
        ProjectGanttFocusView.blocker => Icons.block_outlined,
        ProjectGanttFocusView.owner => Icons.people_outline,
        ProjectGanttFocusView.dashboard => Icons.dashboard_outlined,
        ProjectGanttFocusView.techDebt => Icons.build_circle_outlined,
      };

  String get keySuffix => switch (this) {
        ProjectGanttFocusView.wbs => 'wbs',
        ProjectGanttFocusView.sprint => 'sprint',
        ProjectGanttFocusView.milestone => 'milestone',
        ProjectGanttFocusView.blocker => 'blocker',
        ProjectGanttFocusView.owner => 'owner',
        ProjectGanttFocusView.dashboard => 'dashboard',
        ProjectGanttFocusView.techDebt => 'tech_debt',
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

/// 担当者別 View 用のグループ集計結果 (#2234)。
class OwnerWorkloadGroup {
  final String ownerKey;
  final String ownerLabel;
  final Color ownerColor;
  final List<WbsTask> tasks;
  final int completedCount;
  final int inProgressCount;
  final int overdueCount;
  final double averageProgress;

  const OwnerWorkloadGroup({
    required this.ownerKey,
    required this.ownerLabel,
    required this.ownerColor,
    required this.tasks,
    required this.completedCount,
    required this.inProgressCount,
    required this.overdueCount,
    required this.averageProgress,
  });

  int get incompleteCount => tasks.length - completedCount;
}

/// 進捗ダッシュボード View 用の集計結果 (#2237)。
class ProgressDashboardSummary {
  final int totalCount;
  final int completedCount;
  final int incompleteCount;
  final int inProgressCount;
  final int overdueCount;
  final int blockerCount;
  final double completionRate;
  final double averageProgress;
  final Map<String, int> categoryCounts;
  final Map<String, int> priorityCounts;

  const ProgressDashboardSummary({
    required this.totalCount,
    required this.completedCount,
    required this.incompleteCount,
    required this.inProgressCount,
    required this.overdueCount,
    required this.blockerCount,
    required this.completionRate,
    required this.averageProgress,
    required this.categoryCounts,
    required this.priorityCounts,
  });
}

/// 技術的負債 View 用のタスク項目 (#2242)。
class TechDebtTaskItem {
  final WbsTask task;
  final String classificationReason;
  final bool isRescheduled;
  final bool hasRecoveryPlan;

  const TechDebtTaskItem({
    required this.task,
    required this.classificationReason,
    required this.isRescheduled,
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

  /// 担当者別に WBS タスクを集計する (#2234)。
  static List<OwnerWorkloadGroup> buildOwnerGroups(
    List<WbsTask> tasks, {
    DateTime? now,
  }) {
    if (tasks.isEmpty) {
      return const <OwnerWorkloadGroup>[];
    }
    final ref = now ?? DateTime.now();
    final today = _dayOnly(ref);
    final grouped = <String, List<WbsTask>>{};
    for (final task in tasks) {
      final key = task.activeOwnerKey;
      (grouped[key] ??= <WbsTask>[]).add(task);
    }

    final result = <OwnerWorkloadGroup>[];
    for (final entry in grouped.entries) {
      final groupTasks = entry.value;
      final completed =
          groupTasks.where((t) => t.isEffectivelyCompleted).length;
      final inProgress = groupTasks
          .where((t) => !t.isEffectivelyCompleted && t.status == 'in_progress')
          .length;
      final overdue = groupTasks.where((t) {
        if (t.isEffectivelyCompleted) {
          return false;
        }
        final end = t.scheduleEndDate;
        return end != null && _dayOnly(end).isBefore(today);
      }).length;
      final avg = groupTasks.map((t) => t.progress).reduce((a, b) => a + b) /
          groupTasks.length;
      final sample = groupTasks.first;
      result.add(
        OwnerWorkloadGroup(
          ownerKey: entry.key,
          ownerLabel: sample.activeOwnerLabel,
          ownerColor: sample.activeOwnerColor,
          tasks: groupTasks,
          completedCount: completed,
          inProgressCount: inProgress,
          overdueCount: overdue,
          averageProgress: avg,
        ),
      );
    }

    result.sort((a, b) {
      final incCmp = b.incompleteCount.compareTo(a.incompleteCount);
      if (incCmp != 0) {
        return incCmp;
      }
      final totCmp = b.tasks.length.compareTo(a.tasks.length);
      if (totCmp != 0) {
        return totCmp;
      }
      return a.ownerLabel.compareTo(b.ownerLabel);
    });
    return result;
  }

  /// 全体の進捗ダッシュボード指標を WBS 実データから集計する (#2237)。
  static ProgressDashboardSummary buildProgressDashboard(
    List<WbsTask> tasks, {
    DateTime? now,
  }) {
    if (tasks.isEmpty) {
      return const ProgressDashboardSummary(
        totalCount: 0,
        completedCount: 0,
        incompleteCount: 0,
        inProgressCount: 0,
        overdueCount: 0,
        blockerCount: 0,
        completionRate: 0.0,
        averageProgress: 0.0,
        categoryCounts: <String, int>{},
        priorityCounts: <String, int>{},
      );
    }

    final ref = now ?? DateTime.now();
    final today = _dayOnly(ref);
    var completed = 0;
    var inProgress = 0;
    var overdue = 0;
    var progressSum = 0;
    final categories = <String, int>{};
    final priorities = <String, int>{};

    for (final task in tasks) {
      progressSum += task.progress;
      categories[task.category] = (categories[task.category] ?? 0) + 1;
      final priKey = task.priority.trim().isEmpty
          ? 'medium'
          : task.priority.trim().toLowerCase();
      priorities[priKey] = (priorities[priKey] ?? 0) + 1;

      if (task.isEffectivelyCompleted) {
        completed++;
        continue;
      }
      if (task.status == 'in_progress') {
        inProgress++;
      }
      final end = task.scheduleEndDate;
      if (end != null && _dayOnly(end).isBefore(today)) {
        overdue++;
      }
    }

    final blockers = buildBlockerItems(tasks);
    final incomplete = tasks.length - completed;
    return ProgressDashboardSummary(
      totalCount: tasks.length,
      completedCount: completed,
      incompleteCount: incomplete,
      inProgressCount: inProgress,
      overdueCount: overdue,
      blockerCount: blockers.length,
      completionRate: completed / tasks.length,
      averageProgress: progressSum / tasks.length,
      categoryCounts: categories,
      priorityCounts: priorities,
    );
  }

  static const List<String> _debtKeywords = <String>[
    '技術的負債',
    'リファクタ',
    'refactor',
    'tech debt',
    'debt',
    '負債',
    '後回し',
    '暫定対応',
    'todo',
    'fixme',
    'ワークアラウンド',
  ];

  /// 明示的な負債・リファクタ・再スケジュール対象のみを抽出する (#2242)。
  static List<TechDebtTaskItem> buildTechDebtItems(List<WbsTask> tasks) {
    final items = <TechDebtTaskItem>[];
    for (final task in tasks) {
      if (task.isEffectivelyCompleted) {
        continue;
      }
      final corpus = <String>[
        task.category,
        task.title,
        task.description,
        task.remainingWork,
      ].join(' ').toLowerCase();

      String? matchedKeyword;
      for (final kw in _debtKeywords) {
        if (corpus.contains(kw.toLowerCase())) {
          matchedKeyword = kw;
          break;
        }
      }
      final isRescheduled = task.rescheduledCount > 0;
      final hasRecovery = task.recoveryPlan.trim().isNotEmpty;

      if (matchedKeyword == null && !isRescheduled && !hasRecovery) {
        continue;
      }

      final reasonParts = <String>[];
      if (matchedKeyword != null) {
        reasonParts.add('負債/リファクタ分類 ($matchedKeyword)');
      }
      if (isRescheduled) {
        reasonParts.add('再計画 ${task.rescheduledCount}回');
      }
      if (hasRecovery) {
        reasonParts.add('復旧計画あり');
      }

      items.add(
        TechDebtTaskItem(
          task: task,
          classificationReason: reasonParts.join(' / '),
          isRescheduled: isRescheduled,
          hasRecoveryPlan: hasRecovery,
        ),
      );
    }

    items.sort((a, b) {
      final resCmp = b.task.rescheduledCount.compareTo(a.task.rescheduledCount);
      if (resCmp != 0) {
        return resCmp;
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
