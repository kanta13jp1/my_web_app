import 'package:flutter/material.dart';

import '../application/feature_architecture_controller.dart';

/// 状態・ネットワークに一切依存しない純粋 Presentational ビュー (#2603)。
class FeatureArchitectureView extends StatelessWidget {
  const FeatureArchitectureView({
    super.key,
    required this.state,
    required this.searchController,
    required this.onSelectFilter,
    required this.onSelectRule,
    required this.onToggleChecklist,
    required this.onSearchChanged,
    required this.onReset,
  });

  final ArchitectureGuideState state;
  final TextEditingController searchController;
  final ValueChanged<ArchitectureLayerFilter> onSelectFilter;
  final ValueChanged<String> onSelectRule;
  final ValueChanged<String> onToggleChecklist;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _GuidePalette.fromBrightness(isDark);
    final rules = state.filteredRules;
    final selected = state.selectedRule;

    return Card(
      key: const ValueKey<String>('feature_architecture_view_card'),
      color: palette.cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.account_tree_outlined, color: palette.accentFg),
                const SizedBox(width: 8),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    'Feature 単位構成・責務分離ガイド',
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: IconButton(
                    key: const ValueKey<String>('arch_reset_btn'),
                    tooltip: '初期状態へリセット',
                    color: palette.textPrimary,
                    onPressed: onReset,
                    icon: const Icon(Icons.restart_alt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Container（状態・ライフサイクル）と Presentation（純粋UI）を分離し、複数機能共通UIのみを lib/widgets/ へ配置します。',
              softWrap: true,
              style: TextStyle(
                fontSize: 13,
                color: palette.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildKpiBadge(
                  key: const ValueKey<String>('arch_kpi_rules'),
                  label: '表示規約',
                  value: '${rules.length} 件',
                  fg: palette.infoFg,
                  bg: palette.infoBg,
                ),
                _buildKpiBadge(
                  key: const ValueKey<String>('arch_kpi_checklist'),
                  label: '遵守チェック',
                  value:
                      '${state.completedChecklistCount}/${state.checklist.length}',
                  fg: palette.successFg,
                  bg: palette.successBg,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('arch_search_input'),
              controller: searchController,
              onChanged: onSearchChanged,
              style: TextStyle(color: palette.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: '規約・ディレクトリを検索',
                labelStyle: TextStyle(color: palette.textSecondary),
                filled: true,
                fillColor: palette.surfaceAltBg,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: palette.accentFg, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ArchitectureLayerFilter.values.map((layer) {
                final isSelected = state.filter == layer;
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ChoiceChip(
                    key: ValueKey<String>('arch_filter_${layer.wireValue}'),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    selected: isSelected,
                    backgroundColor: palette.chipUnselectedBg,
                    selectedColor: palette.chipSelectedBg,
                    checkmarkColor: palette.chipSelectedFg,
                    side: BorderSide(color: palette.border),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? palette.chipSelectedFg
                          : palette.chipUnselectedFg,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => onSelectFilter(layer),
                    label: Text(layer.label),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
            if (rules.isEmpty)
              Container(
                key: const ValueKey<String>('arch_empty_state'),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surfaceAltBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '条件に一致する設計ルールはありません。',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
              )
            else
              Column(
                children: rules
                    .map(
                      (rule) => _buildRuleCard(
                        rule: rule,
                        isSelected: selected?.id == rule.id,
                        palette: palette,
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 12),
            Text(
              'アーキテクチャ遵守チェックリスト',
              softWrap: true,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: state.checklist
                  .map(
                    (item) => _buildChecklistRow(item, palette),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiBadge({
    required Key key,
    required String label,
    required String value,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            softWrap: true,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            softWrap: true,
            style: TextStyle(
              fontSize: 16,
              color: fg,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard({
    required ArchitectureStandardRule rule,
    required bool isSelected,
    required _GuidePalette palette,
  }) {
    return Container(
      key: ValueKey<String>('arch_rule_${rule.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? palette.infoBg : palette.surfaceAltBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? palette.accentFg : palette.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                fit: FlexFit.tight,
                child: Text(
                  rule.title,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: OutlinedButton(
                  key: ValueKey<String>('arch_select_${rule.id}'),
                  onPressed: () => onSelectRule(rule.id),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: palette.cardBg,
                    foregroundColor: palette.secondaryBtnFg,
                    side: BorderSide(color: palette.secondaryBtnFg),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: Text(isSelected ? '選択中' : '詳細を選択'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '配置先: ${rule.directoryPattern}',
            softWrap: true,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.accentFg,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            rule.responsibility,
            softWrap: true,
            style: TextStyle(
              fontSize: 12,
              color: palette.textSecondary,
              height: 1.5,
            ),
          ),
          if (rule.prohibitedDependencies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: rule.prohibitedDependencies
                  .map(
                    (dep) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.warningBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '禁止: $dep',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.warningFg,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistRow(
    ArchitectureChecklistItem item,
    _GuidePalette palette,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: palette.surfaceAltBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: CheckboxListTile(
          key: ValueKey<String>('arch_check_${item.id}'),
          value: item.checked,
          activeColor: palette.primaryBtnBg,
          checkColor: palette.primaryBtnFg,
          onChanged: (_) => onToggleChecklist(item.id),
          title: Text(
            item.label,
            softWrap: true,
            style: TextStyle(
              fontSize: 13,
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidePalette {
  const _GuidePalette({
    required this.cardBg,
    required this.surfaceAltBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentFg,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
    required this.secondaryBtnFg,
    required this.infoFg,
    required this.infoBg,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
    required this.chipUnselectedBg,
    required this.chipUnselectedFg,
  });

  final Color cardBg;
  final Color surfaceAltBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentFg;
  final Color primaryBtnBg;
  final Color primaryBtnFg;
  final Color secondaryBtnFg;
  final Color infoFg;
  final Color infoBg;
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color chipSelectedBg;
  final Color chipSelectedFg;
  final Color chipUnselectedBg;
  final Color chipUnselectedFg;

  factory _GuidePalette.fromBrightness(bool isDark) {
    if (isDark) {
      return const _GuidePalette(
        cardBg: Color(0xFF0F172A),
        surfaceAltBg: Color(0xFF1E293B),
        border: Color(0xFF475569),
        textPrimary: Color(0xFFF8FAFC),
        textSecondary: Color(0xFFE2E8F0),
        accentFg: Color(0xFF93C5FD),
        primaryBtnBg: Color(0xFFE0E7FF),
        primaryBtnFg: Color(0xFF1E1B4B),
        secondaryBtnFg: Color(0xFFE0E7FF),
        infoFg: Color(0xFFE0E7FF),
        infoBg: Color(0xFF1E1B4B),
        successFg: Color(0xFFD1FAE5),
        successBg: Color(0xFF022C22),
        warningFg: Color(0xFFFEF3C7),
        warningBg: Color(0xFF451A03),
        chipSelectedBg: Color(0xFFE0E7FF),
        chipSelectedFg: Color(0xFF1E1B4B),
        chipUnselectedBg: Color(0xFF1E293B),
        chipUnselectedFg: Color(0xFFF8FAFC),
      );
    }
    return const _GuidePalette(
      cardBg: Color(0xFFFFFFFF),
      surfaceAltBg: Color(0xFFF8FAFC),
      border: Color(0xFFCBD5E1),
      textPrimary: Color(0xFF0F172A),
      textSecondary: Color(0xFF334155),
      accentFg: Color(0xFF1E3A8A),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
      secondaryBtnFg: Color(0xFF1E3A8A),
      infoFg: Color(0xFF1E1B4B),
      infoBg: Color(0xFFEEF2FF),
      successFg: Color(0xFF064E3B),
      successBg: Color(0xFFECFDF5),
      warningFg: Color(0xFF78350F),
      warningBg: Color(0xFFFFFBEB),
      chipSelectedBg: Color(0xFF1E3A8A),
      chipSelectedFg: Color(0xFFFFFFFF),
      chipUnselectedBg: Color(0xFFF1F5F9),
      chipUnselectedFg: Color(0xFF0F172A),
    );
  }
}
