import 'package:flutter/material.dart';

import '../application/alt_supply_controller.dart';
import '../domain/alt_supply_models.dart';

/// Pure presentation dashboard for alternative supply & import risk (#2756).
class AltSupplyRiskView extends StatelessWidget {
  const AltSupplyRiskView({
    super.key,
    required this.state,
    required this.titleController,
    required this.targetController,
    required this.procurementController,
    required this.thresholdController,
    required this.totalTargetController,
    required this.currentProductionController,
    required this.maQuotaController,
    required this.onRefresh,
    required this.onSeedDefaults,
    required this.onSelectScenario,
    required this.onInputChanged,
    required this.onSaveScenario,
    required this.onCreateScenario,
  });

  final AltSupplyState state;
  final TextEditingController titleController;
  final TextEditingController targetController;
  final TextEditingController procurementController;
  final TextEditingController thresholdController;
  final TextEditingController totalTargetController;
  final TextEditingController currentProductionController;
  final TextEditingController maQuotaController;
  final VoidCallback onRefresh;
  final VoidCallback onSeedDefaults;
  final ValueChanged<AltSupplyScenario> onSelectScenario;
  final VoidCallback onInputChanged;
  final VoidCallback onSaveScenario;
  final VoidCallback onCreateScenario;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metrics = state.liveMetrics;

    return SingleChildScrollView(
      key: const ValueKey<String>('alt_supply_scroll_view'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeaderCard(context, colors),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _buildBanner(
              key: const ValueKey<String>('alt_supply_error_banner'),
              icon: Icons.error_outline,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              title: '取得・保存エラー',
              subtitle: state.errorMessage!,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _buildBanner(
              key: const ValueKey<String>('alt_supply_notice_banner'),
              icon: Icons.check_circle_outline,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              title: '保存完了',
              subtitle: state.statusNotice!,
            ),
            const SizedBox(height: 12),
          ],
          _buildRiskIndicatorBanner(colors, metrics),
          const SizedBox(height: 12),
          _buildStockpileGapCard(context, colors, metrics),
          const SizedBox(height: 12),
          _buildTotalProductionKpiCard(context, colors, metrics),
          const SizedBox(height: 12),
          _buildScenarioEditorCard(context, colors),
          const SizedBox(height: 12),
          if (state.isLoading)
            const Padding(
              key: ValueKey<String>('alt_supply_loading'),
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _buildSavedScenariosCard(context, colors),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    final BuildContext context,
    final ColorScheme colors,
  ) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.warehouse_outlined, color: colors.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '代替供給・輸入シナリオ リスク監視',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '備蓄目標(100万t)・国内調達見込・MA米(77万t)輸入依存確率と総生産KPI乖離を監視します。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey<String>('alt_supply_refresh_button'),
              tooltip: '最新シナリオを再読込',
              onPressed: state.isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskIndicatorBanner(
    final ColorScheme colors,
    final AltSupplyMetrics metrics,
  ) {
    if (metrics.belowProcurementThreshold) {
      return _buildBanner(
        key: const ValueKey<String>('alt_supply_escalation_banner'),
        icon: Icons.warning_amber_rounded,
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
        title: '代替供給（輸入転用・MA米依存）リスク上昇: ${metrics.riskLevel.label}',
        subtitle:
            '国内調達見込み (${state.draftDomesticProcurement.toStringAsFixed(1)} 万t) が警告閾値 '
            '(${state.draftThreshold.toStringAsFixed(1)} 万t) を下回っています。\n'
            '輸入転用・代替調達確率: ${metrics.importEscalationProbability}% '
            '(MA米標準輸入枠: ${state.draftMaQuota.toStringAsFixed(1)} 万t / '
            '備蓄不足分: ${metrics.stockpileShortfall10kT.toStringAsFixed(1)} 万t)',
        badgeKey: const ValueKey<String>('alt_supply_import_prob_value'),
        badgeLabel: '輸入転用確率 ${metrics.importEscalationProbability}%',
      );
    }

    return _buildBanner(
      key: const ValueKey<String>('alt_supply_stable_banner'),
      icon: Icons.verified_outlined,
      backgroundColor: colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      title: '国内調達安定水準 (${metrics.riskLevel.label})',
      subtitle:
          '国内調達見込み (${state.draftDomesticProcurement.toStringAsFixed(1)} 万t) が警告閾値 '
          '(${state.draftThreshold.toStringAsFixed(1)} 万t) 以上を維持しています。\n'
          '輸入転用・代替調達確率: ${metrics.importEscalationProbability}% '
          '(備蓄不足分: ${metrics.stockpileShortfall10kT.toStringAsFixed(1)} 万t)',
      badgeKey: const ValueKey<String>('alt_supply_import_prob_value'),
      badgeLabel: '輸入転用確率 ${metrics.importEscalationProbability}%',
    );
  }

  Widget _buildBanner({
    required final Key key,
    required final IconData icon,
    required final Color backgroundColor,
    required final Color foregroundColor,
    required final String title,
    required final String subtitle,
    final Key? badgeKey,
    final String? badgeLabel,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: foregroundColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: foregroundColor,
                    height: 1.4,
                  ),
                ),
                if (badgeLabel != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    key: badgeKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: foregroundColor),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _alertTextColor(final BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFFB91C1C);

  Color _okTextColor(final BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF5EEAD4)
          : const Color(0xFF115E59);

  Widget _buildStockpileGapCard(
    final BuildContext context,
    final ColorScheme colors,
    final AltSupplyMetrics metrics,
  ) {
    final target =
        state.draftStockpileTarget <= 0 ? 1.0 : state.draftStockpileTarget;
    final ratio = (state.draftDomesticProcurement / target).clamp(0.0, 1.0);

    return Card(
      key: const ValueKey<String>('alt_supply_stockpile_card'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '備蓄回復バランス (目標 vs 国内調達見込)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '不足分: ${metrics.stockpileShortfall10kT.toStringAsFixed(1)} 万t',
                  key: const ValueKey<String>('alt_supply_shortfall_value'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: metrics.stockpileShortfall10kT > 0
                        ? _alertTextColor(context)
                        : _okTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: colors.surfaceContainerHighest,
              color: metrics.belowProcurementThreshold
                  ? colors.error
                  : colors.primary,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: <Widget>[
                Text(
                  '目標備蓄: ${state.draftStockpileTarget.toStringAsFixed(1)} 万t',
                  style: TextStyle(fontSize: 12, color: colors.onSurface),
                ),
                Text(
                  '国内調達見込: ${state.draftDomesticProcurement.toStringAsFixed(1)} 万t',
                  style: TextStyle(fontSize: 12, color: colors.onSurface),
                ),
                Text(
                  'MA米輸入枠: ${state.draftMaQuota.toStringAsFixed(1)} 万t',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalProductionKpiCard(
    final BuildContext context,
    final ColorScheme colors,
    final AltSupplyMetrics metrics,
  ) {
    final kpiTarget =
        state.draftTotalTarget <= 0 ? 1.0 : state.draftTotalTarget;
    final ratio = (state.draftCurrentProduction / kpiTarget).clamp(0.0, 1.0);
    final gap = metrics.totalProductionGap10kT;
    final gapSign = gap >= 0 ? '+' : '';
    final gapText =
        '$gapSign${gap.toStringAsFixed(1)} 万t (目標 ${state.draftTotalTarget.toStringAsFixed(1)} 万t比)';

    return Card(
      key: const ValueKey<String>('alt_supply_kpi_gap_card'),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '総生産目標 KPI 乖離モニタ (800万t基準)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  gapText,
                  key:
                      const ValueKey<String>('alt_supply_production_gap_value'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: gap < 0
                        ? _alertTextColor(context)
                        : _okTextColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: colors.surfaceContainerHighest,
              color: gap < 0 ? colors.tertiary : colors.primary,
            ),
            const SizedBox(height: 6),
            Text(
              '現状見込み生産量: ${state.draftCurrentProduction.toStringAsFixed(1)} 万t / '
              '目標 KPI: ${state.draftTotalTarget.toStringAsFixed(1)} 万t',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioEditorCard(
    final BuildContext context,
    final ColorScheme colors,
  ) {
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '手動シナリオ検証パラメータ',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '将来的な定期オープンデータ取得ジョブ連携を見据えた手動検証入力フォームです。',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('alt_supply_title_field'),
              controller: titleController,
              onChanged: (_) => onInputChanged(),
              decoration: const InputDecoration(
                labelText: 'シナリオ名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _buildNumericField(
                  key: const ValueKey<String>('alt_supply_target_field'),
                  controller: targetController,
                  label: '国の備蓄目標 (万t)',
                ),
                _buildNumericField(
                  key: const ValueKey<String>('alt_supply_procurement_field'),
                  controller: procurementController,
                  label: '国内調達見込 (万t)',
                ),
                _buildNumericField(
                  key: const ValueKey<String>('alt_supply_threshold_field'),
                  controller: thresholdController,
                  label: '調達警告しきい値 (万t)',
                ),
                _buildNumericField(
                  key: const ValueKey<String>('alt_supply_total_target_field'),
                  controller: totalTargetController,
                  label: '総生産目標KPI (万t)',
                ),
                _buildNumericField(
                  key: const ValueKey<String>('alt_supply_current_prod_field'),
                  controller: currentProductionController,
                  label: '現状生産見込 (万t)',
                ),
                _buildNumericField(
                  key: const ValueKey<String>('alt_supply_ma_quota_field'),
                  controller: maQuotaController,
                  label: 'MA米輸入枠 (万t)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.icon(
                  key: const ValueKey<String>('alt_supply_save_button'),
                  onPressed: state.isSaving ? null : onSaveScenario,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存・更新'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('alt_supply_create_button'),
                  onPressed: state.isSaving ? null : onCreateScenario,
                  icon: const Icon(Icons.add),
                  label: const Text('新規追加'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('alt_supply_seed_button'),
                  onPressed: state.isSaving ? null : onSeedDefaults,
                  icon: const Icon(Icons.auto_fix_high_outlined),
                  label: const Text('標準投入'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericField({
    required final Key key,
    required final TextEditingController controller,
    required final String label,
  }) {
    return SizedBox(
      width: 152,
      child: TextField(
        key: key,
        controller: controller,
        onChanged: (_) => onInputChanged(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSavedScenariosCard(
    final BuildContext context,
    final ColorScheme colors,
  ) {
    if (state.scenarios.isEmpty) {
      return Container(
        key: const ValueKey<String>('alt_supply_empty_state'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: const Text(
          '保存済みシナリオがありません。「標準シナリオ投入」または新規作成してください。',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '保存済みシナリオ (${state.scenarios.length}件)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            for (final scenario in state.scenarios)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  key: ValueKey<String>(
                    'alt_supply_scenario_card_${scenario.id}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    backgroundColor: state.selectedId == scenario.id
                        ? colors.primaryContainer.withValues(alpha: 0.4)
                        : null,
                  ),
                  onPressed: () => onSelectScenario(scenario),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              scenario.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                            Text(
                              '国内調達: ${scenario.domesticProcurement10kT.toStringAsFixed(1)}万t / '
                              '不足: ${scenario.metrics.stockpileShortfall10kT.toStringAsFixed(1)}万t / '
                              '輸入転用確率: ${scenario.metrics.importEscalationProbability}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        scenario.metrics.riskLevel.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: scenario.metrics.belowProcurementThreshold
                              ? _alertTextColor(context)
                              : _okTextColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
