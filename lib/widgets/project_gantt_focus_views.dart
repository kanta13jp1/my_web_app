import 'package:flutter/material.dart';

import '../pages/project_gantt_page.dart';
import '../services/project_gantt_focus_view_service.dart';

/// `/project-gantt` の WBS タブ上部セグメント切替バー (#2230 #2231 #2233 #2234 #2235 #2237 #2240 #2241 #2242)。
class ProjectGanttFocusViewBar extends StatelessWidget {
  final ProjectGanttFocusView selectedView;
  final ValueChanged<ProjectGanttFocusView> onSelect;
  final int sprintCount;
  final int milestoneCount;
  final int blockerCount;
  final int ownerCount;
  final int dashboardCount;
  final int techDebtCount;
  final int githubIssueCount;
  final int riskCount;
  final int testTargetCount;

  const ProjectGanttFocusViewBar({
    super.key,
    required this.selectedView,
    required this.onSelect,
    required this.sprintCount,
    required this.milestoneCount,
    required this.blockerCount,
    this.ownerCount = 0,
    this.dashboardCount = 0,
    this.techDebtCount = 0,
    this.githubIssueCount = 0,
    this.riskCount = 0,
    this.testTargetCount = 0,
  });

  int? _badgeCountFor(ProjectGanttFocusView view) => switch (view) {
        ProjectGanttFocusView.wbs => null,
        ProjectGanttFocusView.sprint => sprintCount,
        ProjectGanttFocusView.milestone => milestoneCount,
        ProjectGanttFocusView.blocker => blockerCount,
        ProjectGanttFocusView.owner => ownerCount,
        ProjectGanttFocusView.dashboard =>
          dashboardCount > 0 ? dashboardCount : null,
        ProjectGanttFocusView.techDebt => techDebtCount,
        ProjectGanttFocusView.githubIssues => githubIssueCount,
        ProjectGanttFocusView.risk => riskCount,
        ProjectGanttFocusView.testTargets => testTargetCount,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF14171F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2F3A)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ProjectGanttFocusView.values.map((view) {
            final selected = view == selectedView;
            final badge = _badgeCountFor(view);
            final displayLabel =
                badge == null ? view.label : '${view.label} ($badge)';
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: ChoiceChip(
                  key: Key('gantt_focus_view_${view.keySuffix}'),
                  avatar: Icon(
                    view.icon,
                    size: 18,
                    color: selected
                        ? const Color(0xFF121212)
                        : const Color(0xFFB0B8C4),
                  ),
                  label: Text(
                    displayLabel,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF121212)
                          : const Color(0xFFE5E7EB),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selectedColor: const Color(0xFFFF6B35),
                  backgroundColor: const Color(0xFF1E2430),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF334155),
                  ),
                  onSelected: (_) => onSelect(view),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// スプリント View パネル (#2230)。
class ProjectGanttSprintView extends StatelessWidget {
  final SprintViewData data;

  const ProjectGanttSprintView({
    super.key,
    required this.data,
  });

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2F3A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bolt_outlined,
                    color: Color(0xFFFF6B35),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'スプリントView (${_formatDate(data.windowStart)} 〜 ${_formatDate(data.windowEnd)})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _KpiTag(
                    label: '今週対象 ${data.activeTasks.length}件',
                    color: const Color(0xFFFF6B35),
                  ),
                  _KpiTag(
                    label: '進行中 ${data.inProgressCount}件',
                    color: const Color(0xFF38BDF8),
                  ),
                  _KpiTag(
                    label: '期限超過 ${data.overdueCount}件',
                    color: data.overdueCount > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E),
                  ),
                  _KpiTag(
                    label: '今週完了 ${data.completedInWindowTasks.length}件',
                    color: const Color(0xFF22C55E),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    '平均進捗率',
                    style: TextStyle(color: Color(0xFFB0B8C4), fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (data.averageProgress / 100.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFF2A2F3A),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${data.averageProgress.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (data.activeTasks.isEmpty)
          const _FocusEmptyCard(
            icon: Icons.bolt_outlined,
            message: '今スプリント期間に該当する未完了のWBSタスクはありません。',
          )
        else
          ...data.activeTasks.map((task) {
            final end = task.scheduleEndDate;
            final isOverdue = end != null &&
                DateTime(end.year, end.month, end.day).isBefore(today);
            return _SprintTaskCard(
              task: task,
              isOverdue: isOverdue,
              dueLabel: end != null ? _formatDate(end) : '期限未設定',
            );
          }),
      ],
    );
  }
}

/// マイルストーン View パネル (#2231)。
class ProjectGanttMilestoneView extends StatelessWidget {
  final List<MilestoneViewGroup> groups;

  const ProjectGanttMilestoneView({
    super.key,
    required this.groups,
  });

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _FocusEmptyCard(
        icon: Icons.flag_outlined,
        message: 'マイルストーンまたはWBSタスクがまだ登録されていません。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((group) {
        final milestone = group.milestone;
        final accent = milestone?.color ?? const Color(0xFF94A3B8);
        final titleText = milestone == null
            ? 'マイルストーン未割当 (${group.tasks.length}件)'
            : '${milestone.code}: ${milestone.name}';
        final pct = (group.completionRate * 100).round();

        return Container(
          key: Key(
            'gantt_milestone_group_${milestone?.code ?? 'unassigned'}',
          ),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: group.isAtRisk
                  ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                  : const Color(0xFF2A2F3A),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      titleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${group.completedCount}/${group.tasks.length} ($pct%)',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (milestone != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _KpiTag(
                      label: '目標日 ${_formatDate(milestone.targetDate)}',
                      color: const Color(0xFFB0B8C4),
                    ),
                    _KpiTag(
                      label: milestone.achieved
                          ? '達成済み'
                          : group.daysLeft >= 0
                              ? '残り${group.daysLeft}日'
                              : '${-group.daysLeft}日超過',
                      color: milestone.achieved
                          ? const Color(0xFF22C55E)
                          : group.isAtRisk
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF38BDF8),
                    ),
                    if (group.inProgressCount > 0)
                      _KpiTag(
                        label: '進行中 ${group.inProgressCount}件',
                        color: const Color(0xFFFF6B35),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: group.completionRate.clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: const Color(0xFF2A2F3A),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              if (group.tasks.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'このマイルストーンに紐づくWBSタスクはまだありません。',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ] else ...[
                const SizedBox(height: 10),
                ...group.tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          task.isEffectivelyCompleted
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: task.isEffectivelyCompleted
                              ? const Color(0xFF22C55E)
                              : task.statusColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              color: Color(0xFFE5E7EB),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${task.progress}%',
                          style: const TextStyle(
                            color: Color(0xFFB0B8C4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// ブロッカー View パネル (#2233)。
class ProjectGanttBlockerView extends StatelessWidget {
  final List<BlockerTaskItem> items;

  const ProjectGanttBlockerView({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final totalImpacted = items.fold<int>(
      0,
      (sum, item) => sum + item.downstreamBlockedTasks.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2F3A)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.block_outlined,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ブロッカーView: 停止要因 ${items.length}件 / 影響タスク $totalImpacted件',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _FocusEmptyCard(
            icon: Icons.verified_outlined,
            message: '他タスクを停止させているブロッカーやブロック中のタスクはありません。',
          )
        else
          ...items.map((item) => _BlockerCard(item: item)),
      ],
    );
  }
}

class _SprintTaskCard extends StatelessWidget {
  final WbsTask task;
  final bool isOverdue;
  final String dueLabel;

  const _SprintTaskCard({
    required this.task,
    required this.isOverdue,
    required this.dueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final issueNo = task.linkedGithubIssueNumber;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? const Color(0xFFEF4444).withValues(alpha: 0.7)
              : const Color(0xFF2A2F3A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${task.progress}%',
                style: TextStyle(
                  color: task.statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _KpiTag(label: task.statusLabel, color: task.statusColor),
              _KpiTag(
                label: '担当: ${task.activeOwnerLabel}',
                color: const Color(0xFF94A3B8),
              ),
              _KpiTag(
                label: isOverdue ? '期限超過 ($dueLabel)' : '期限: $dueLabel',
                color: isOverdue
                    ? const Color(0xFFEF4444)
                    : const Color(0xFFB0B8C4),
              ),
              if (issueNo != null)
                _KpiTag(label: '#$issueNo', color: const Color(0xFF38BDF8)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: (task.progress / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF2A2F3A),
              valueColor: AlwaysStoppedAnimation<Color>(task.statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockerCard extends StatelessWidget {
  final BlockerTaskItem item;

  const _BlockerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final issueNo = task.linkedGithubIssueNumber;
    return Container(
      key: Key('gantt_blocker_card_${task.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (issueNo != null)
                _KpiTag(label: '#$issueNo', color: const Color(0xFF38BDF8)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (item.downstreamBlockedTasks.isNotEmpty)
                _KpiTag(
                  label: '${item.downstreamBlockedTasks.length}件をブロック中',
                  color: const Color(0xFFEF4444),
                ),
              if (item.hasExplicitBlockedStatus)
                const _KpiTag(
                  label: '状態: ブロック',
                  color: Color(0xFFF97316),
                ),
              _KpiTag(
                label: '担当: ${task.activeOwnerLabel}',
                color: const Color(0xFF94A3B8),
              ),
            ],
          ),
          if (item.downstreamBlockedTasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '停止中の後続タスク:',
              style: TextStyle(color: Color(0xFFB0B8C4), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: item.downstreamBlockedTasks
                  .map(
                    (dep) => _KpiTag(
                      label: dep.title,
                      color: const Color(0xFFFBBF24),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (item.hasRecoveryPlan) ...[
            const SizedBox(height: 8),
            Text(
              '復旧計画: ${task.recoveryPlan}',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiTag extends StatelessWidget {
  final String label;
  final Color color;

  const _KpiTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

class _FocusEmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _FocusEmptyCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2F3A)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9CA3AF), size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB0B8C4), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// 担当者別 View パネル (#2234)。
class ProjectGanttOwnerView extends StatelessWidget {
  final List<OwnerWorkloadGroup> groups;

  const ProjectGanttOwnerView({
    super.key,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _FocusEmptyCard(
        icon: Icons.people_outline,
        message: '担当者別のWBSタスクがまだ登録されていません。',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groups.map((group) {
        return Container(
          key: Key('gantt_owner_group_${group.ownerKey}'),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: group.overdueCount > 0
                  ? const Color(0xFFEF4444).withValues(alpha: 0.65)
                  : const Color(0xFF2A2F3A),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 8,
                    backgroundColor: group.ownerColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.ownerLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '平均 ${group.averageProgress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: group.ownerColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _KpiTag(
                    label: '合計 ${group.tasks.length}件',
                    color: const Color(0xFFB0B8C4),
                  ),
                  _KpiTag(
                    label: '未完了 ${group.incompleteCount}件',
                    color: const Color(0xFFFF6B35),
                  ),
                  _KpiTag(
                    label: '完了 ${group.completedCount}件',
                    color: const Color(0xFF22C55E),
                  ),
                  if (group.overdueCount > 0)
                    _KpiTag(
                      label: '期限超過 ${group.overdueCount}件',
                      color: const Color(0xFFEF4444),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (group.averageProgress / 100.0).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: const Color(0xFF2A2F3A),
                  valueColor: AlwaysStoppedAnimation<Color>(group.ownerColor),
                ),
              ),
              const SizedBox(height: 10),
              ...group.tasks.take(5).map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                color: Color(0xFFE5E7EB),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${task.progress}%',
                            style: const TextStyle(
                              color: Color(0xFFB0B8C4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// 進捗ダッシュボード View パネル (#2237)。
class ProjectGanttProgressDashboardView extends StatelessWidget {
  final ProgressDashboardSummary summary;

  const ProjectGanttProgressDashboardView({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.totalCount == 0) {
      return const _FocusEmptyCard(
        icon: Icons.dashboard_outlined,
        message: '進捗ダッシュボードに表示するWBSタスクがまだありません。',
      );
    }

    final completionPct = (summary.completionRate * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: const Key('gantt_progress_dashboard_card'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2F3A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.dashboard_outlined,
                    color: Color(0xFFFF6B35),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '進捗ダッシュボードView',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '完了率 $completionPct%',
                    style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _KpiTag(
                    label: '全体 ${summary.totalCount}件',
                    color: const Color(0xFFB0B8C4),
                  ),
                  _KpiTag(
                    label: '完了 ${summary.completedCount}件',
                    color: const Color(0xFF22C55E),
                  ),
                  _KpiTag(
                    label: '未完了 ${summary.incompleteCount}件',
                    color: const Color(0xFF38BDF8),
                  ),
                  _KpiTag(
                    label: '期限切れ ${summary.overdueCount}件',
                    color: summary.overdueCount > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF22C55E),
                  ),
                  _KpiTag(
                    label: 'ブロッカー ${summary.blockerCount}件',
                    color: summary.blockerCount > 0
                        ? const Color(0xFFF97316)
                        : const Color(0xFF22C55E),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: summary.completionRate.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: const Color(0xFF2A2F3A),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF22C55E),
                  ),
                ),
              ),
              if (summary.categoryCounts.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'カテゴリ別内訳',
                  style: TextStyle(
                    color: Color(0xFFB0B8C4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: summary.categoryCounts.entries
                      .map(
                        (e) => _KpiTag(
                          label: '${e.key}: ${e.value}件',
                          color: const Color(0xFF94A3B8),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 技術的負債 View パネル (#2242)。
class ProjectGanttTechDebtView extends StatelessWidget {
  final List<TechDebtTaskItem> items;

  const ProjectGanttTechDebtView({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2F3A)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.build_circle_outlined,
                color: Color(0xFFFBBF24),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '技術的負債View: 要解消対象 ${items.length}件',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _FocusEmptyCard(
            icon: Icons.verified_outlined,
            message: '現在、明示的な技術的負債・リファクタ対象タスクはありません。',
          )
        else
          ...items.map((item) {
            final task = item.task;
            return Container(
              key: Key('gantt_tech_debt_card_${task.id}'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${task.progress}%',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _KpiTag(
                        label: item.classificationReason,
                        color: const Color(0xFFFBBF24),
                      ),
                      _KpiTag(
                        label: '担当: ${task.activeOwnerLabel}',
                        color: const Color(0xFF94A3B8),
                      ),
                      _KpiTag(
                        label: task.statusLabel,
                        color: task.statusColor,
                      ),
                    ],
                  ),
                  if (task.remainingWork.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '残作業: ${task.remainingWork}',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

enum _GitHubIssueFilterMode { all, open, closed, unlinked }

/// GitHub Issue 連携 View パネル (#2235)。
class ProjectGanttGitHubIssueView extends StatefulWidget {
  final GitHubIssueLinkSummary summary;

  const ProjectGanttGitHubIssueView({
    super.key,
    required this.summary,
  });

  @override
  State<ProjectGanttGitHubIssueView> createState() =>
      _ProjectGanttGitHubIssueViewState();
}

class _ProjectGanttGitHubIssueViewState
    extends State<ProjectGanttGitHubIssueView> {
  _GitHubIssueFilterMode _filterMode = _GitHubIssueFilterMode.all;

  List<WbsTask> get _visibleTasks => switch (_filterMode) {
        _GitHubIssueFilterMode.all => <WbsTask>[
            ...widget.summary.linkedTasks,
            ...widget.summary.unlinkedTasks,
          ],
        _GitHubIssueFilterMode.open => widget.summary.openIssueTasks,
        _GitHubIssueFilterMode.closed => widget.summary.closedIssueTasks,
        _GitHubIssueFilterMode.unlinked => widget.summary.unlinkedTasks,
      };

  String _filterLabel(_GitHubIssueFilterMode mode) => switch (mode) {
        _GitHubIssueFilterMode.all => 'すべて (${widget.summary.totalCount})',
        _GitHubIssueFilterMode.open =>
          'OPEN (${widget.summary.openIssueTasks.length})',
        _GitHubIssueFilterMode.closed =>
          'CLOSED (${widget.summary.closedIssueTasks.length})',
        _GitHubIssueFilterMode.unlinked =>
          '未紐付け (${widget.summary.unlinkedTasks.length})',
      };

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2F3A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.link_outlined,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GitHub Issue連携View (連携済 ${widget.summary.linkedTasks.length}件 / 未紐付け ${widget.summary.unlinkedTasks.length}件)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _GitHubIssueFilterMode.values.map((mode) {
                  final selected = mode == _filterMode;
                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: ChoiceChip(
                      key: Key('gantt_github_filter_${mode.name}'),
                      label: Text(
                        _filterLabel(mode),
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF121212)
                              : const Color(0xFFE5E7EB),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      selected: selected,
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      selectedColor: const Color(0xFF38BDF8),
                      backgroundColor: const Color(0xFF1E2430),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF334155),
                      ),
                      onSelected: (_) => setState(() => _filterMode = mode),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const _FocusEmptyCard(
            icon: Icons.link_off_outlined,
            message: '選択した条件に該当するWBSタスクはありません。',
          )
        else
          ...visible.map((task) {
            final issueNumber = task.linkedGithubIssueNumber;
            final issueState = task.githubIssueState.trim().toUpperCase();
            final stateLabel = issueNumber == null
                ? 'Issue未紐付け'
                : (issueState.isNotEmpty
                    ? issueState
                    : (task.isEffectivelyCompleted ? 'CLOSED' : 'OPEN/未同期'));
            final stateColor = issueNumber == null
                ? const Color(0xFF94A3B8)
                : (stateLabel == 'CLOSED'
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF38BDF8));
            return Container(
              key: Key('gantt_github_issue_card_${task.id}'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2F3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (issueNumber != null) ...[
                        _KpiTag(
                          label: '#$issueNumber',
                          color: const Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _KpiTag(label: stateLabel, color: stateColor),
                      _KpiTag(
                        label: '担当: ${task.activeOwnerLabel}',
                        color: const Color(0xFF94A3B8),
                      ),
                      _KpiTag(
                        label: '${task.category} / ${task.priority}',
                        color: const Color(0xFFCBD5E1),
                      ),
                      _KpiTag(
                        label: task.statusLabel,
                        color: task.statusColor,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// リスク View パネル (#2240)。
class ProjectGanttRiskView extends StatelessWidget {
  final RiskViewSummary summary;

  const ProjectGanttRiskView({
    super.key,
    required this.summary,
  });

  Color _severityColor(String severity) => switch (severity) {
        'high' => const Color(0xFFEF4444),
        'medium' => const Color(0xFFF59E0B),
        _ => const Color(0xFF38BDF8),
      };

  @override
  Widget build(BuildContext context) {
    final hasAny =
        summary.milestoneWarnings.isNotEmpty || summary.taskRisks.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2F3A)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                color: Color(0xFFEF4444),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'リスクView: マイルストーン警告 ${summary.milestoneWarnings.length}件 / タスクリスク ${summary.taskRisks.length}件',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (summary.milestoneRiskLoadFailed) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('gantt_risk_load_error_banner'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2B1B1B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444)),
            ),
            child: const Text(
              'wbs_milestone_risk_view の取得に失敗したため、マイルストーン別の過負荷リスクは未確認です。',
              style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!hasAny)
          const _FocusEmptyCard(
            icon: Icons.verified_user_outlined,
            message: '検知された期限・依存・技術リスクはありません。',
          )
        else ...[
          ...summary.milestoneWarnings.asMap().entries.map((entry) {
            final row = entry.value;
            final code = (row['milestone_code'] ?? row['code'] ?? 'milestone')
                .toString();
            final riskStatus = (row['risk_status'] ?? 'warning').toString();
            return Container(
              key: Key('gantt_milestone_risk_${entry.key}'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF251A17),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF97316)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    color: Color(0xFFF97316),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'マイルストーン $code ($riskStatus)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          ...summary.taskRisks.map((item) {
            final task = item.task;
            final color = _severityColor(item.severity);
            return Container(
              key: Key('gantt_risk_card_${task.id}'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _KpiTag(
                        label: item.severity.toUpperCase(),
                        color: color,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ...item.reasons.map(
                        (r) => _KpiTag(label: r, color: color),
                      ),
                      _KpiTag(
                        label: '担当: ${task.activeOwnerLabel}',
                        color: const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}

/// テスト対象 View パネル (#2241)。
class ProjectGanttTestTargetView extends StatelessWidget {
  final TestTargetSummary summary;

  const ProjectGanttTestTargetView({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final allItems = <TestTargetTaskItem>[
      ...summary.unevaluatedItems,
      ...summary.explicitTestItems,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2F3A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.science_outlined,
                    color: Color(0xFFA855F7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'テスト対象View: テスト明記 ${summary.explicitTestItems.length}件 / 未評価 ${summary.unevaluatedItems.length}件',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '※ 件数のみで「テスト十分」とは判定せず、テスト条件の紐付けが確認できない未完了タスクは「未評価」として独立表示します。',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (allItems.isEmpty)
          const _FocusEmptyCard(
            icon: Icons.check_circle_outline,
            message: '未完了のテスト対象評価タスクはありません。',
          )
        else
          ...allItems.map((item) {
            final task = item.task;
            final tagColor = item.hasExplicitTestScope
                ? const Color(0xFF22C55E)
                : const Color(0xFFF59E0B);
            return Container(
              key: Key('gantt_test_target_card_${task.id}'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tagColor.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _KpiTag(label: item.evaluationLabel, color: tagColor),
                      _KpiTag(
                        label: '担当: ${task.activeOwnerLabel}',
                        color: const Color(0xFF94A3B8),
                      ),
                      _KpiTag(
                        label: '${task.category} / ${task.priority}',
                        color: const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.reason,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
