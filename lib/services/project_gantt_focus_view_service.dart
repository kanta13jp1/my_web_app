import 'package:flutter/material.dart';

import '../pages/project_gantt_page.dart';

/// `/project-gantt` の WBS タブ内で切り替えるフォーカス View (#2230 #2231 #2233 #2234 #2235 #2237 #2240 #2241 #2242)。
enum ProjectGanttFocusView {
  wbs,
  sprint,
  milestone,
  blocker,
  owner,
  dashboard,
  techDebt,
  githubIssues,
  risk,
  testTargets;

  String get label => switch (this) {
        ProjectGanttFocusView.wbs => '開発WBS',
        ProjectGanttFocusView.sprint => 'スプリントView',
        ProjectGanttFocusView.milestone => 'マイルストーンView',
        ProjectGanttFocusView.blocker => 'ブロッカーView',
        ProjectGanttFocusView.owner => '担当者別View',
        ProjectGanttFocusView.dashboard => '進捗ダッシュボードView',
        ProjectGanttFocusView.techDebt => '技術的負債View',
        ProjectGanttFocusView.githubIssues => 'GitHub Issue連携View',
        ProjectGanttFocusView.risk => 'リスクView',
        ProjectGanttFocusView.testTargets => 'テスト対象View',
      };

  IconData get icon => switch (this) {
        ProjectGanttFocusView.wbs => Icons.account_tree_outlined,
        ProjectGanttFocusView.sprint => Icons.bolt_outlined,
        ProjectGanttFocusView.milestone => Icons.flag_outlined,
        ProjectGanttFocusView.blocker => Icons.block_outlined,
        ProjectGanttFocusView.owner => Icons.people_outline,
        ProjectGanttFocusView.dashboard => Icons.dashboard_outlined,
        ProjectGanttFocusView.techDebt => Icons.build_circle_outlined,
        ProjectGanttFocusView.githubIssues => Icons.link_outlined,
        ProjectGanttFocusView.risk => Icons.warning_amber_outlined,
        ProjectGanttFocusView.testTargets => Icons.science_outlined,
      };

  String get keySuffix => switch (this) {
        ProjectGanttFocusView.wbs => 'wbs',
        ProjectGanttFocusView.sprint => 'sprint',
        ProjectGanttFocusView.milestone => 'milestone',
        ProjectGanttFocusView.blocker => 'blocker',
        ProjectGanttFocusView.owner => 'owner',
        ProjectGanttFocusView.dashboard => 'dashboard',
        ProjectGanttFocusView.techDebt => 'tech_debt',
        ProjectGanttFocusView.githubIssues => 'github_issues',
        ProjectGanttFocusView.risk => 'risk',
        ProjectGanttFocusView.testTargets => 'test_targets',
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

/// GitHub Issue 連携 View 用の集計結果 (#2235)。
class GitHubIssueLinkSummary {
  final List<WbsTask> linkedTasks;
  final List<WbsTask> openIssueTasks;
  final List<WbsTask> closedIssueTasks;
  final List<WbsTask> unlinkedTasks;

  const GitHubIssueLinkSummary({
    required this.linkedTasks,
    required this.openIssueTasks,
    required this.closedIssueTasks,
    required this.unlinkedTasks,
  });

  int get totalCount => linkedTasks.length + unlinkedTasks.length;
}

/// リスク View 用のタスク別項目 (#2240)。
class RiskTaskItem {
  final WbsTask task;
  final String severity;
  final List<String> reasons;

  const RiskTaskItem({
    required this.task,
    required this.severity,
    required this.reasons,
  });
}

/// リスク View 用の統合サマリー (#2240)。
class RiskViewSummary {
  final List<Map<String, dynamic>> milestoneWarnings;
  final List<RiskTaskItem> taskRisks;
  final bool milestoneRiskLoadFailed;

  const RiskViewSummary({
    required this.milestoneWarnings,
    required this.taskRisks,
    required this.milestoneRiskLoadFailed,
  });

  int get totalRiskCount => milestoneWarnings.length + taskRisks.length;
}

/// テスト対象 View 用のタスク項目 (#2241)。
class TestTargetTaskItem {
  final WbsTask task;
  final bool hasExplicitTestScope;
  final String evaluationLabel;
  final String reason;

  const TestTargetTaskItem({
    required this.task,
    required this.hasExplicitTestScope,
    required this.evaluationLabel,
    required this.reason,
  });
}

/// テスト対象 View 用の集計サマリー (#2241)。
class TestTargetSummary {
  final List<TestTargetTaskItem> explicitTestItems;
  final List<TestTargetTaskItem> unevaluatedItems;

  const TestTargetSummary({
    required this.explicitTestItems,
    required this.unevaluatedItems,
  });

  int get totalCount => explicitTestItems.length + unevaluatedItems.length;
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

  /// GitHub Issue 連携状況を集計する (#2235)。
  static GitHubIssueLinkSummary buildGitHubIssueLinkSummary(
    List<WbsTask> tasks,
  ) {
    final linked = <WbsTask>[];
    final open = <WbsTask>[];
    final closed = <WbsTask>[];
    final unlinked = <WbsTask>[];

    for (final task in tasks) {
      final issueNum = task.linkedGithubIssueNumber;
      if (issueNum == null) {
        unlinked.add(task);
        continue;
      }
      linked.add(task);
      final normalizedState = task.githubIssueState.trim().toUpperCase();
      if (normalizedState == 'CLOSED' || task.isEffectivelyCompleted) {
        closed.add(task);
      } else {
        open.add(task);
      }
    }

    int compareIssue(WbsTask a, WbsTask b) {
      final aNum = a.linkedGithubIssueNumber ?? 0;
      final bNum = b.linkedGithubIssueNumber ?? 0;
      final numCmp = aNum.compareTo(bNum);
      if (numCmp != 0) {
        return numCmp;
      }
      return a.title.compareTo(b.title);
    }

    linked.sort(compareIssue);
    open.sort(compareIssue);
    closed.sort(compareIssue);
    unlinked.sort((a, b) => a.title.compareTo(b.title));

    return GitHubIssueLinkSummary(
      linkedTasks: linked,
      openIssueTasks: open,
      closedIssueTasks: closed,
      unlinkedTasks: unlinked,
    );
  }

  static const List<String> _riskKeywords = <String>[
    'リスク',
    '未確定',
    '要確認',
    '不明',
    '障害',
    'block',
    'risk',
    'tbd',
    'unknown',
    'uncertain',
  ];

  /// 既存マイルストーン警告とタスク別リスク要因を統合集計する (#2240)。
  static RiskViewSummary buildRiskSummary(
    List<WbsTask> tasks, {
    List<Map<String, dynamic>> milestoneRisks = const <Map<String, dynamic>>[],
    bool milestoneRiskLoadFailed = false,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final today = _dayOnly(ref);
    final milestoneWarnings = milestoneRisks.where((r) {
      final status = (r['risk_status']?.toString() ?? '').trim();
      return status == 'over_capacity' ||
          status == 'critical_overdue' ||
          status == 'tight';
    }).toList(growable: false);

    final taskRisks = <RiskTaskItem>[];
    for (final task in tasks) {
      if (task.isEffectivelyCompleted) {
        continue;
      }
      final reasons = <String>[];
      var highSignal = false;

      final end =
          task.scheduleEndDate != null ? _dayOnly(task.scheduleEndDate!) : null;
      if (end != null) {
        final daysDiff = end.difference(today).inDays;
        if (daysDiff < 0) {
          highSignal = true;
          reasons.add('期限超過 (${-daysDiff}日)');
        } else if (daysDiff <= 3) {
          reasons.add('期限間近 ($daysDiff日以内)');
        }
      }
      if (task.hasInvertedSchedule) {
        highSignal = true;
        reasons.add('計画日時逆転');
      }
      if (end != null &&
          end.isBefore(today) &&
          task.recoveryPlan.trim().isEmpty) {
        reasons.add('遅延＋復旧計画未記入');
      }
      if (task.rescheduledCount > 0) {
        if (task.rescheduledCount >= 2) {
          highSignal = true;
        }
        reasons.add('再計画 ${task.rescheduledCount}回');
      }
      if (task.status == 'blocked' || task.dependsOnTitles.isNotEmpty) {
        highSignal = true;
        reasons.add(
          task.dependsOnTitles.isNotEmpty
              ? '依存待ち (${task.dependsOnTitles.length}件)'
              : '明示ブロック中',
        );
      }

      final corpus = <String>[
        task.title,
        task.description,
        task.remainingWork,
      ].join(' ').toLowerCase();
      String? matchedRiskKw;
      for (final kw in _riskKeywords) {
        if (corpus.contains(kw)) {
          matchedRiskKw = kw;
          break;
        }
      }
      if (matchedRiskKw != null) {
        reasons.add('仕様未確定/技術リスク ($matchedRiskKw)');
      }

      final priorityRank = _priorityRank(task.priority);
      if (priorityRank <= 1 && reasons.isNotEmpty) {
        reasons.add('高優先度 (${task.priority.toUpperCase()})');
      }

      if (reasons.isEmpty) {
        continue;
      }

      final severity =
          (highSignal || (priorityRank == 0 && reasons.length >= 2))
              ? 'high'
              : (reasons.length >= 2 || priorityRank <= 1 ? 'medium' : 'low');

      taskRisks.add(
        RiskTaskItem(
          task: task,
          severity: severity,
          reasons: reasons,
        ),
      );
    }

    int severityScore(String s) => switch (s) {
          'high' => 0,
          'medium' => 1,
          _ => 2,
        };

    taskRisks.sort((a, b) {
      final sevCmp =
          severityScore(a.severity).compareTo(severityScore(b.severity));
      if (sevCmp != 0) {
        return sevCmp;
      }
      final priCmp = _priorityRank(a.task.priority)
          .compareTo(_priorityRank(b.task.priority));
      if (priCmp != 0) {
        return priCmp;
      }
      return a.task.title.compareTo(b.task.title);
    });

    return RiskViewSummary(
      milestoneWarnings: milestoneWarnings,
      taskRisks: taskRisks,
      milestoneRiskLoadFailed: milestoneRiskLoadFailed,
    );
  }

  static const List<String> _testKeywords = <String>[
    'テスト',
    'test',
    'e2e',
    'integration',
    '回帰',
    'regression',
    'a11y',
    'qa',
    '検証',
  ];

  /// 未完了タスクを「テスト関連記述あり」と「未評価（テスト未紐付け）」へ分類する (#2241)。
  static TestTargetSummary buildTestTargetSummary(List<WbsTask> tasks) {
    final explicitItems = <TestTargetTaskItem>[];
    final unevaluatedItems = <TestTargetTaskItem>[];

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

      String? matchedKw;
      for (final kw in _testKeywords) {
        if (corpus.contains(kw)) {
          matchedKw = kw;
          break;
        }
      }

      if (matchedKw != null) {
        explicitItems.add(
          TestTargetTaskItem(
            task: task,
            hasExplicitTestScope: true,
            evaluationLabel: 'テスト対象明記 ($matchedKw)',
            reason: 'タイトル/詳細にテスト・検証条件が記載されています',
          ),
        );
      } else {
        unevaluatedItems.add(
          TestTargetTaskItem(
            task: task,
            hasExplicitTestScope: false,
            evaluationLabel: '未評価 (テスト対応未紐付け)',
            reason: task.linkedGithubIssueNumber != null
                ? 'Issue #${task.linkedGithubIssueNumber} の検証条件/テスト証跡が未紐付けです'
                : 'テスト対応ファイルまたは受入検証記述が未記録です',
          ),
        );
      }
    }

    int compareTarget(TestTargetTaskItem a, TestTargetTaskItem b) {
      final priCmp = _priorityRank(a.task.priority)
          .compareTo(_priorityRank(b.task.priority));
      if (priCmp != 0) {
        return priCmp;
      }
      return a.task.title.compareTo(b.task.title);
    }

    explicitItems.sort(compareTarget);
    unevaluatedItems.sort(compareTarget);

    return TestTargetSummary(
      explicitTestItems: explicitItems,
      unevaluatedItems: unevaluatedItems,
    );
  }
}
