import 'package:flutter/material.dart';

import '../data/design_compliance_data.dart';
import '../data/ui_improvement_rollout_data.dart';

class UiDesignStatusPage extends StatefulWidget {
  const UiDesignStatusPage({super.key});

  @override
  State<UiDesignStatusPage> createState() => _UiDesignStatusPageState();
}

class _UiDesignStatusPageState extends State<UiDesignStatusPage> {
  static const Color _accent = Color(0xFFFF6B35);
  static const Color _figmaColor = Color(0xFF7C3AED);
  static const Color _aiDesignerColor = Color(0xFF2563EB);
  static const Color _success = Color(0xFF1E7B65);
  static const Color _warning = Color(0xFF916626);
  static const Color _danger = Color(0xFFB22323);

  final TextEditingController _searchController = TextEditingController();

  DesignCategory? _selectedCategory;
  bool _showAppliedOnly = false;
  bool _showAuditedOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PageComplianceRecord> get _filteredRecords {
    final String query = _searchController.text.trim().toLowerCase();
    final List<PageComplianceRecord> filtered =
        kDesignComplianceData.where((PageComplianceRecord record) {
      if (_selectedCategory != null && record.category != _selectedCategory) {
        return false;
      }

      final UiImprovementRollout rollout = resolveUiImprovementRollout(record);
      if (_showAppliedOnly && rollout.stage != UiImprovementStage.applied) {
        return false;
      }
      if (_showAuditedOnly && !record.isAudited) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }

      return record.route.toLowerCase().contains(query) ||
          record.name.toLowerCase().contains(query) ||
          (record.notes?.toLowerCase().contains(query) ?? false) ||
          rollout.headline.toLowerCase().contains(query) ||
          rollout.nextStep.toLowerCase().contains(query);
    }).toList();

    filtered.sort((PageComplianceRecord a, PageComplianceRecord b) {
      final UiImprovementRollout rolloutA = resolveUiImprovementRollout(a);
      final UiImprovementRollout rolloutB = resolveUiImprovementRollout(b);
      final int stageCompare = _stagePriority(rolloutA.stage)
          .compareTo(_stagePriority(rolloutB.stage));
      if (stageCompare != 0) {
        return stageCompare;
      }
      final int auditedCompare =
          (b.isAudited ? 1 : 0).compareTo(a.isAudited ? 1 : 0);
      if (auditedCompare != 0) {
        return auditedCompare;
      }
      final int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.route.compareTo(b.route);
    });

    return filtered;
  }

  int _stagePriority(UiImprovementStage stage) {
    return switch (stage) {
      UiImprovementStage.applied => 0,
      UiImprovementStage.inProgress => 1,
      UiImprovementStage.planned => 2,
    };
  }

  int get _appliedCount => kDesignComplianceData
      .where(
        (PageComplianceRecord record) =>
            resolveUiImprovementRollout(record).stage ==
            UiImprovementStage.applied,
      )
      .length;

  int get _inProgressCount => kDesignComplianceData
      .where(
        (PageComplianceRecord record) =>
            resolveUiImprovementRollout(record).stage ==
            UiImprovementStage.inProgress,
      )
      .length;

  int get _plannedCount => kDesignComplianceData
      .where(
        (PageComplianceRecord record) =>
            resolveUiImprovementRollout(record).stage ==
            UiImprovementStage.planned,
      )
      .length;

  int get _auditedCount => kDesignComplianceData
      .where((PageComplianceRecord record) => record.isAudited)
      .length;

  int get _strongComplianceCount => kDesignComplianceData
      .where(
        (PageComplianceRecord record) =>
            record.isAudited && record.score >= 0.8,
      )
      .length;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<PageComplianceRecord> records = _filteredRecords;

    return Scaffold(
      appBar: AppBar(title: const Text('UI Design Rollout Status')),
      body: SelectionArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildHero(theme),
                    const SizedBox(height: 16),
                    _buildProjectToolingRow(theme, colorScheme),
                    const SizedBox(height: 16),
                    _buildSummaryGrid(theme, colorScheme),
                    const SizedBox(height: 16),
                    _buildFilters(theme, colorScheme),
                    const SizedBox(height: 8),
                    Text(
                      'Screens ${records.length}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (records.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No screens matched the current filters.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ScreenStatusCard(record: records[index]),
                      );
                    },
                    childCount: records.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Text(
              'Figma MCP x AIDesigner x Design Skills x DESIGN.md',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Track every screen and see\nwhere the new UI workflow has already landed.',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This page shows the project-wide tooling rollout, screen inventory, '
            'design audit score, and whether each screen is applied, in progress, or planned.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectToolingRow(ThemeData theme, ColorScheme colorScheme) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _ProjectToolCard(
          title: 'Figma MCP',
          subtitle: 'Source-of-truth layout reference',
          color: _figmaColor,
          icon: Icons.grid_view_rounded,
        ),
        _ProjectToolCard(
          title: 'AIDesigner',
          subtitle: 'Fast exploration and variants',
          color: _aiDesignerColor,
          icon: Icons.auto_awesome,
        ),
        _ProjectToolCard(
          title: 'Design Skills',
          subtitle: 'Project-specific UI judgment rules',
          color: _success,
          icon: Icons.rule_folder_outlined,
        ),
        _ProjectToolCard(
          title: 'DESIGN.md',
          subtitle: 'Final source of design truth',
          color: _accent,
          icon: Icons.menu_book_outlined,
        ),
      ],
    );
  }

  Widget _buildSummaryGrid(ThemeData theme, ColorScheme colorScheme) {
    final List<_SummaryItem> items = <_SummaryItem>[
      _SummaryItem(
        label: 'Total screens',
        value: '${kDesignComplianceData.length}',
        color: colorScheme.onSurface,
      ),
      _SummaryItem(
        label: 'Applied',
        value: '$_appliedCount',
        color: _success,
      ),
      _SummaryItem(
        label: 'In progress',
        value: '$_inProgressCount',
        color: _warning,
      ),
      _SummaryItem(
        label: 'Planned',
        value: '$_plannedCount',
        color: _danger,
      ),
      _SummaryItem(
        label: 'Audited',
        value: '$_auditedCount',
        color: _figmaColor,
      ),
      _SummaryItem(
        label: 'Strong score',
        value: '$_strongComplianceCount',
        color: _aiDesignerColor,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 640
                ? 2
                : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxisCount == 1 ? 3.4 : 2.4,
          ),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final _SummaryItem item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: item.color.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    item.value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilters(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search by route, screen name, note, or next action',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilterChip(
                label: const Text('Applied only'),
                selected: _showAppliedOnly,
                onSelected: (bool value) {
                  setState(() => _showAppliedOnly = value);
                },
              ),
              FilterChip(
                label: const Text('Audited only'),
                selected: _showAuditedOnly,
                onSelected: (bool value) {
                  setState(() => _showAuditedOnly = value);
                },
              ),
              for (final DesignCategory category in DesignCategory.values)
                ChoiceChip(
                  label: Text(category.name),
                  selected: _selectedCategory == category,
                  onSelected: (bool selected) {
                    setState(() {
                      _selectedCategory = selected ? category : null;
                    });
                  },
                ),
              ChoiceChip(
                label: const Text('All categories'),
                selected: _selectedCategory == null,
                onSelected: (_) {
                  setState(() => _selectedCategory = null);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectToolCard extends StatelessWidget {
  const _ProjectToolCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Installed',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenStatusCard extends StatelessWidget {
  const _ScreenStatusCard({required this.record});

  final PageComplianceRecord record;

  static const Color _accent = Color(0xFFFF6B35);
  static const Color _figmaColor = Color(0xFF7C3AED);
  static const Color _aiDesignerColor = Color(0xFF2563EB);
  static const Color _success = Color(0xFF1E7B65);
  static const Color _warning = Color(0xFF916626);
  static const Color _danger = Color(0xFFB22323);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final UiImprovementRollout rollout = resolveUiImprovementRollout(record);
    final Color stageColor = _stageColor(rollout.stage);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: stageColor.withValues(alpha: 0.20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _StageBadge(stage: rollout.stage),
                _InfoChip(
                  label: record.category.name,
                  color: colorScheme.primary,
                ),
                if (record.auditDate != null)
                  _InfoChip(
                    label: 'Audit ${record.auditDate}',
                    color: colorScheme.secondary,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              record.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              record.route,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              rollout.headline,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildComplianceSection(context),
            const SizedBox(height: 14),
            Text(
              'Workflow adoption',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _WorkflowToolStatusChip(
                  label: 'Figma MCP',
                  status: rollout.figmaMcp,
                  color: _figmaColor,
                ),
                _WorkflowToolStatusChip(
                  label: 'AIDesigner',
                  status: rollout.aiDesignerMcp,
                  color: _aiDesignerColor,
                ),
                _WorkflowToolStatusChip(
                  label: 'Design Skills',
                  status: rollout.designSkills,
                  color: _success,
                ),
                _WorkflowToolStatusChip(
                  label: 'DESIGN.md',
                  status: rollout.designMd,
                  color: _accent,
                ),
              ],
            ),
            if ((record.notes?.isNotEmpty ?? false) ||
                rollout.nextStep.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (record.notes?.isNotEmpty ?? false) ...<Widget>[
                      Text(
                        'Audit note',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(record.notes!, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      'Next action',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rollout.nextStep,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed(record.route);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open screen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    if (!record.isAudited) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _danger.withValues(alpha: 0.18)),
        ),
        child: Text(
          'This screen has not been audited yet. The next step is a DESIGN.md audit before deeper Figma or AIDesigner work.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: record.score,
                  minHeight: 10,
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.7),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _scoreColor(record.score),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${record.scorePercent}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _scoreColor(record.score),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(
            kComplianceItems.length,
            (int index) {
              final bool passed = index < (record.compliance?.length ?? 0) &&
                  record.compliance![index];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (passed ? _success : _danger).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        (passed ? _success : _danger).withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  '${kComplianceItems[index]['short']} ${kComplianceItems[index]['key']}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: passed ? _success : _danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.8) {
      return _success;
    }
    if (score >= 0.5) {
      return _warning;
    }
    return _danger;
  }

  Color _stageColor(UiImprovementStage stage) {
    return switch (stage) {
      UiImprovementStage.applied => _success,
      UiImprovementStage.inProgress => _warning,
      UiImprovementStage.planned => _danger,
    };
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.stage});

  final UiImprovementStage stage;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (stage) {
      UiImprovementStage.applied => ('Applied', const Color(0xFF1E7B65)),
      UiImprovementStage.inProgress => ('In progress', const Color(0xFF916626)),
      UiImprovementStage.planned => ('Planned', const Color(0xFFB22323)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
      ),
    );
  }
}

class _WorkflowToolStatusChip extends StatelessWidget {
  const _WorkflowToolStatusChip({
    required this.label,
    required this.status,
    required this.color,
  });

  final String label;
  final UiImprovementAdoption status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (String statusLabel, double alpha) = switch (status) {
      UiImprovementAdoption.applied => ('Applied', 0.12),
      UiImprovementAdoption.inProgress => ('In progress', 0.08),
      UiImprovementAdoption.planned => ('Planned', 0.05),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        <String>[label, statusLabel].join(' - '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}
