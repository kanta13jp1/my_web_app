import 'package:flutter/material.dart';

import '../data/design_compliance_data.dart';
import '../data/ui_improvement_rollout_data.dart';

class UiRolloutSummaryCard extends StatelessWidget {
  const UiRolloutSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_ScreenSnapshot> screens = kDesignComplianceData
        .map(
          (PageComplianceRecord record) => _ScreenSnapshot(
            record: record,
            rollout: resolveUiImprovementRollout(record),
          ),
        )
        .toList()
      ..sort(_compareScreens);

    final int totalCount = screens.length;
    final int appliedCount = screens
        .where((screen) => screen.rollout.stage == UiImprovementStage.applied)
        .length;
    final int inProgressCount = screens
        .where(
          (screen) => screen.rollout.stage == UiImprovementStage.inProgress,
        )
        .length;
    final int plannedCount = screens
        .where((screen) => screen.rollout.stage == UiImprovementStage.planned)
        .length;
    final int auditedCount =
        screens.where((screen) => screen.record.isAudited).length;

    final List<_ToolCoverage> tooling = <_ToolCoverage>[
      _ToolCoverage(
        label: 'DESIGN.md',
        color: const Color(0xFFFF6B35),
        applied: screens
            .where(
              (screen) =>
                  screen.rollout.designMd == UiImprovementAdoption.applied,
            )
            .length,
        inProgress: screens
            .where(
              (screen) =>
                  screen.rollout.designMd == UiImprovementAdoption.inProgress,
            )
            .length,
        planned: screens
            .where(
              (screen) =>
                  screen.rollout.designMd == UiImprovementAdoption.planned,
            )
            .length,
      ),
      _ToolCoverage(
        label: 'Design Skills',
        color: const Color(0xFF1E7B65),
        applied: screens
            .where(
              (screen) =>
                  screen.rollout.designSkills == UiImprovementAdoption.applied,
            )
            .length,
        inProgress: screens
            .where(
              (screen) =>
                  screen.rollout.designSkills ==
                  UiImprovementAdoption.inProgress,
            )
            .length,
        planned: screens
            .where(
              (screen) =>
                  screen.rollout.designSkills == UiImprovementAdoption.planned,
            )
            .length,
      ),
      _ToolCoverage(
        label: 'AIDesigner',
        color: const Color(0xFF7C3AED),
        applied: screens
            .where(
              (screen) =>
                  screen.rollout.aiDesignerMcp == UiImprovementAdoption.applied,
            )
            .length,
        inProgress: screens
            .where(
              (screen) =>
                  screen.rollout.aiDesignerMcp ==
                  UiImprovementAdoption.inProgress,
            )
            .length,
        planned: screens
            .where(
              (screen) =>
                  screen.rollout.aiDesignerMcp == UiImprovementAdoption.planned,
            )
            .length,
      ),
      _ToolCoverage(
        label: 'Figma MCP',
        color: const Color(0xFF2563EB),
        applied: screens
            .where(
              (screen) =>
                  screen.rollout.figmaMcp == UiImprovementAdoption.applied,
            )
            .length,
        inProgress: screens
            .where(
              (screen) =>
                  screen.rollout.figmaMcp == UiImprovementAdoption.inProgress,
            )
            .length,
        planned: screens
            .where(
              (screen) =>
                  screen.rollout.figmaMcp == UiImprovementAdoption.planned,
            )
            .length,
      ),
    ];

    final List<_CategoryCoverage> categories = DesignCategory.values
        .map(
          (DesignCategory category) => _CategoryCoverage(
            category: category,
            screens: screens
                .where((screen) => screen.record.category == category)
                .toList(),
          ),
        )
        .where((coverage) => coverage.total > 0)
        .toList()
      ..sort(
        (a, b) => b.priorityCount == a.priorityCount
            ? b.total.compareTo(a.total)
            : b.priorityCount.compareTo(a.priorityCount),
      );

    final List<_ScreenSnapshot> spotlightScreens = <_ScreenSnapshot>[
      ...screens.where(
        (screen) => screen.rollout.stage == UiImprovementStage.inProgress,
      ),
      ...screens.where(
        (screen) => screen.rollout.stage == UiImprovementStage.planned,
      ),
      ...screens.where(
        (screen) => screen.rollout.stage == UiImprovementStage.applied,
      ),
    ].take(6).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFF9F4EF), Color(0xFFFFFFFF)],
        ),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.22),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool stacked = constraints.maxWidth < 820;
                final Widget copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'UI rollout visibility',
                        style: TextStyle(
                          color: Color(0xFF9A3412),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '画面一覧と UI 改善の適用状況をホームから確認',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Figma MCP / AIDesigner / Design Skills / DESIGN.md の導入状況を、'
                      '全 $totalCount 画面の棚卸しデータから自動集計しています。'
                      ' 詳細はそのまま一覧ページで確認できます。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF374151),
                        height: 1.6,
                      ),
                    ),
                  ],
                );

                final Widget action = FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/ui-design-status'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('全画面の詳細を開く'),
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFF9A3412),
                    backgroundColor: const Color(
                      0xFFFF6B35,
                    ).withValues(alpha: 0.12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      copy,
                      const SizedBox(height: 16),
                      action,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: copy),
                    const SizedBox(width: 20),
                    action,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _StatCard(
                  label: '適用済み',
                  value: '$appliedCount',
                  helper: '${_percent(appliedCount, totalCount)}%',
                  color: const Color(0xFF1E7B65),
                  icon: Icons.check_circle_outline,
                ),
                _StatCard(
                  label: '進行中',
                  value: '$inProgressCount',
                  helper: '${_percent(inProgressCount, totalCount)}%',
                  color: const Color(0xFF916626),
                  icon: Icons.autorenew_rounded,
                ),
                _StatCard(
                  label: '予定',
                  value: '$plannedCount',
                  helper: '${_percent(plannedCount, totalCount)}%',
                  color: const Color(0xFFB22323),
                  icon: Icons.schedule_outlined,
                ),
                _StatCard(
                  label: '監査済み',
                  value: '$auditedCount',
                  helper: '${_percent(auditedCount, totalCount)}%',
                  color: const Color(0xFF2563EB),
                  icon: Icons.fact_check_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '改善施策ごとの適用率',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: tooling
                  .map(
                    (_ToolCoverage coverage) => _ToolCoverageCard(
                      coverage: coverage,
                      total: totalCount,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'カテゴリ別の優先度',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map(
                    (_CategoryCoverage coverage) => _CategoryChip(
                      coverage: coverage,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text(
              '優先画面プレビュー',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...spotlightScreens.map(
              (_ScreenSnapshot screen) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScreenPreviewRow(screen: screen),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _compareScreens(_ScreenSnapshot a, _ScreenSnapshot b) {
    final int stageCompare = _stagePriority(a.rollout.stage)
        .compareTo(_stagePriority(b.rollout.stage));
    if (stageCompare != 0) {
      return stageCompare;
    }

    final String updatedA = a.rollout.updatedAt ?? a.record.auditDate ?? '';
    final String updatedB = b.rollout.updatedAt ?? b.record.auditDate ?? '';
    final int updatedCompare = updatedB.compareTo(updatedA);
    if (updatedCompare != 0) {
      return updatedCompare;
    }

    return a.record.route.compareTo(b.record.route);
  }

  int _stagePriority(UiImprovementStage stage) {
    switch (stage) {
      case UiImprovementStage.inProgress:
        return 0;
      case UiImprovementStage.planned:
        return 1;
      case UiImprovementStage.applied:
        return 2;
    }
  }

  static int _percent(int value, int total) {
    if (total <= 0) {
      return 0;
    }
    return ((value / total) * 100).round();
  }
}

class _ScreenSnapshot {
  const _ScreenSnapshot({required this.record, required this.rollout});

  final PageComplianceRecord record;
  final UiImprovementRollout rollout;
}

class _ToolCoverage {
  const _ToolCoverage({
    required this.label,
    required this.color,
    required this.applied,
    required this.inProgress,
    required this.planned,
  });

  final String label;
  final Color color;
  final int applied;
  final int inProgress;
  final int planned;
}

class _CategoryCoverage {
  const _CategoryCoverage({required this.category, required this.screens});

  final DesignCategory category;
  final List<_ScreenSnapshot> screens;

  int get total => screens.length;

  int get priorityCount => screens
      .where((screen) => screen.rollout.stage != UiImprovementStage.applied)
      .length;

  int get appliedCount => screens
      .where((screen) => screen.rollout.stage == UiImprovementStage.applied)
      .length;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String helper;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 210),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  helper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCoverageCard extends StatelessWidget {
  const _ToolCoverageCard({required this.coverage, required this.total});

  final _ToolCoverage coverage;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int coveragePercent =
        total <= 0 ? 0 : ((coverage.applied / total) * 100).round();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: coverage.color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            coverage.label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total <= 0 ? 0 : coverage.applied / total,
              minHeight: 8,
              color: coverage.color,
              backgroundColor: coverage.color.withValues(alpha: 0.10),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$coveragePercent% 適用済み',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: coverage.color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '適用 ${coverage.applied}  進行中 ${coverage.inProgress}  予定 ${coverage.planned}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.coverage});

  final _CategoryCoverage coverage;

  @override
  Widget build(BuildContext context) {
    final String label =
        categoryLabel[coverage.category] ?? coverage.category.name;
    final Color color = coverage.priorityCount == 0
        ? const Color(0xFF1E7B65)
        : coverage.priorityCount <= 2
            ? const Color(0xFF916626)
            : const Color(0xFFB22323);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        '$label  ${coverage.appliedCount}/${coverage.total} 適用済み',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ScreenPreviewRow extends StatelessWidget {
  const _ScreenPreviewRow({required this.screen});

  final _ScreenSnapshot screen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String updatedAt =
        screen.rollout.updatedAt ?? screen.record.auditDate ?? '未更新';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _StatusBadge(
                label: _stageLabel(screen.rollout.stage),
                color: _stageColor(screen.rollout.stage),
              ),
              _StatusBadge(
                label: categoryLabel[screen.record.category] ??
                    screen.record.category.name,
                color: const Color(0xFF475569),
                backgroundAlpha: 0.10,
              ),
              Text(
                '更新 $updatedAt',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            screen.record.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            screen.record.route,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            screen.rollout.headline,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF374151),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusBadge(
                label: 'Figma ${_adoptionLabel(screen.rollout.figmaMcp)}',
                color: _adoptionColor(screen.rollout.figmaMcp),
              ),
              _StatusBadge(
                label:
                    'AIDesigner ${_adoptionLabel(screen.rollout.aiDesignerMcp)}',
                color: _adoptionColor(screen.rollout.aiDesignerMcp),
              ),
              _StatusBadge(
                label:
                    'Design Skills ${_adoptionLabel(screen.rollout.designSkills)}',
                color: _adoptionColor(screen.rollout.designSkills),
              ),
              _StatusBadge(
                label: 'DESIGN.md ${_adoptionLabel(screen.rollout.designMd)}',
                color: _adoptionColor(screen.rollout.designMd),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _stageColor(UiImprovementStage stage) {
    switch (stage) {
      case UiImprovementStage.applied:
        return const Color(0xFF1E7B65);
      case UiImprovementStage.inProgress:
        return const Color(0xFF916626);
      case UiImprovementStage.planned:
        return const Color(0xFFB22323);
    }
  }

  static String _stageLabel(UiImprovementStage stage) {
    switch (stage) {
      case UiImprovementStage.applied:
        return '適用済み';
      case UiImprovementStage.inProgress:
        return '進行中';
      case UiImprovementStage.planned:
        return '予定';
    }
  }

  static Color _adoptionColor(UiImprovementAdoption adoption) {
    switch (adoption) {
      case UiImprovementAdoption.applied:
        return const Color(0xFF1E7B65);
      case UiImprovementAdoption.inProgress:
        return const Color(0xFF916626);
      case UiImprovementAdoption.planned:
        return const Color(0xFF6B7280);
    }
  }

  static String _adoptionLabel(UiImprovementAdoption adoption) {
    switch (adoption) {
      case UiImprovementAdoption.applied:
        return '適用済み';
      case UiImprovementAdoption.inProgress:
        return '進行中';
      case UiImprovementAdoption.planned:
        return '予定';
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    this.backgroundAlpha = 0.12,
  });

  final String label;
  final Color color;
  final double backgroundAlpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
