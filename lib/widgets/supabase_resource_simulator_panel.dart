import 'package:flutter/material.dart';

import '../services/supabase_resource_simulator_service.dart';

class _SimulatorPalette {
  const _SimulatorPalette({
    required this.cardSurface,
    required this.subSurface,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
    required this.infoBg,
    required this.infoFg,
    required this.normalBg,
    required this.normalFg,
    required this.warningBg,
    required this.warningFg,
    required this.overageBg,
    required this.overageFg,
    required this.barTrack,
  });

  factory _SimulatorPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _SimulatorPalette(
        cardSurface: Color(0xFF0F172A),
        subSurface: Color(0xFF1E293B),
        textPrimary: Color(0xFFF8FAFC),
        textMuted: Color(0xFFCBD5E1),
        border: Color(0xFF64748B),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF0F172A),
        infoBg: Color(0xFF172554),
        infoFg: Color(0xFFBFDBFE),
        normalBg: Color(0xFF052E16),
        normalFg: Color(0xFFBBF7D0),
        warningBg: Color(0xFF422006),
        warningFg: Color(0xFFFEF08A),
        overageBg: Color(0xFF450A0A),
        overageFg: Color(0xFFFECACA),
        barTrack: Color(0xFF334155),
      );
    }
    return const _SimulatorPalette(
      cardSurface: Color(0xFFFFFFFF),
      subSurface: Color(0xFFF8FAFC),
      textPrimary: Color(0xFF0F172A),
      textMuted: Color(0xFF334155),
      border: Color(0xFF94A3B8),
      primaryBtnBg: Color(0xFF1E40AF),
      primaryBtnFg: Color(0xFFFFFFFF),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      normalBg: Color(0xFFDCFCE7),
      normalFg: Color(0xFF14532D),
      warningBg: Color(0xFFFEF9C3),
      warningFg: Color(0xFF713F12),
      overageBg: Color(0xFFFEE2E2),
      overageFg: Color(0xFF7F1D1D),
      barTrack: Color(0xFFE2E8F0),
    );
  }

  final Color cardSurface;
  final Color subSurface;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color primaryBtnBg;
  final Color primaryBtnFg;
  final Color infoBg;
  final Color infoFg;
  final Color normalBg;
  final Color normalFg;
  final Color warningBg;
  final Color warningFg;
  final Color overageBg;
  final Color overageFg;
  final Color barTrack;

  _MetricColorPair colorsForThreshold(QuotaThresholdLevel level) {
    return switch (level) {
      QuotaThresholdLevel.normal => _MetricColorPair(normalBg, normalFg),
      QuotaThresholdLevel.warning => _MetricColorPair(warningBg, warningFg),
      QuotaThresholdLevel.overage => _MetricColorPair(overageBg, overageFg),
    };
  }
}

class _MetricColorPair {
  const _MetricColorPair(this.bg, this.fg);

  final Color bg;
  final Color fg;
}

/// Supabase クォータ・リソース消費量のインタラクティブシミュレーター (#2624)。
class SupabaseResourceSimulatorPanel extends StatefulWidget {
  const SupabaseResourceSimulatorPanel({
    super.key,
    this.controller,
  });

  final SupabaseResourceSimulatorController? controller;

  @override
  State<SupabaseResourceSimulatorPanel> createState() =>
      _SupabaseResourceSimulatorPanelState();
}

class _SupabaseResourceSimulatorPanelState
    extends State<SupabaseResourceSimulatorPanel> {
  SupabaseResourceSimulatorController? _ownedController;

  SupabaseResourceSimulatorController get _activeController {
    return widget.controller ??
        (_ownedController ??= SupabaseResourceSimulatorController());
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _activeController;
    final palette = _SimulatorPalette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final result = controller.result;
        return Material(
          color: palette.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: palette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildHeader(palette, controller),
                const SizedBox(height: 12),
                _buildPlanSelector(palette, controller, result),
                const SizedBox(height: 12),
                _buildCostSummary(palette, result),
                const SizedBox(height: 12),
                _buildAlertsSection(palette, result),
                const SizedBox(height: 16),
                _buildQuotaBars(palette, result),
                const SizedBox(height: 16),
                _buildSliders(palette, controller),
                const SizedBox(height: 12),
                _buildSourceDisclaimer(palette),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    _SimulatorPalette palette,
    SupabaseResourceSimulatorController controller,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            'Supabase リソース制約シミュレーター',
            softWrap: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton.icon(
              key: const ValueKey<String>('sim_reset_button'),
              onPressed: controller.resetDefaults,
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.cardSurface,
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.border),
              ),
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('初期値へ戻す'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector(
    _SimulatorPalette palette,
    SupabaseResourceSimulatorController controller,
    SupabaseSimulationResult result,
  ) {
    final currentTier = result.inputs.planTier;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildTierButton(
          palette: palette,
          key: const ValueKey<String>('sim_plan_free_button'),
          label: 'Free (USD 0/月)',
          selected: currentTier == SupabasePlanTier.free,
          onPressed: () => controller.setPlanTier(SupabasePlanTier.free),
        ),
        _buildTierButton(
          palette: palette,
          key: const ValueKey<String>('sim_plan_pro_button'),
          label: 'Pro (USD 25/月〜)',
          selected: currentTier == SupabasePlanTier.pro,
          onPressed: () => controller.setPlanTier(SupabasePlanTier.pro),
        ),
      ],
    );
  }

  Widget _buildTierButton({
    required _SimulatorPalette palette,
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: OutlinedButton(
        key: key,
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor:
              selected ? palette.primaryBtnBg : palette.cardSurface,
          foregroundColor:
              selected ? palette.primaryBtnFg : palette.textPrimary,
          side: BorderSide(color: palette.border, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildCostSummary(
    _SimulatorPalette palette,
    SupabaseSimulationResult result,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '推定月額合計: USD ${result.estimatedTotalUsd.toStringAsFixed(2)} / 月',
            softWrap: true,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          _SimulatorBadge(
            label:
                '基本 USD ${result.spec.baseMonthlyUsd.toStringAsFixed(2)} + 超過 USD ${result.estimatedOverageUsd.toStringAsFixed(2)}',
            bg: palette.infoBg,
            fg: palette.infoFg,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(
    _SimulatorPalette palette,
    SupabaseSimulationResult result,
  ) {
    final Color bg;
    final Color fg;
    final String headline;
    if (result.hasOverage) {
      bg = palette.overageBg;
      fg = palette.overageFg;
      headline = '警告: 設定されたプランクォータを超過しています';
    } else if (result.hasWarning) {
      bg = palette.warningBg;
      fg = palette.warningFg;
      headline = '注意: クォータ消費率が 80% 以上に到達しています';
    } else {
      bg = palette.normalBg;
      fg = palette.normalFg;
      headline = '全リソース項目が 80% 未満の安全圏内です';
    }

    return Container(
      key: const ValueKey<String>('sim_alert_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  headline,
                  softWrap: true,
                  style: TextStyle(fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ],
          ),
          for (final alert in result.alerts) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    '・$alert',
                    softWrap: true,
                    style: TextStyle(fontSize: 13, color: fg),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuotaBars(
    _SimulatorPalette palette,
    SupabaseSimulationResult result,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                'クォータ消費率予測（リアルタイムグラフ）',
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final metric in result.metrics) _buildMetricBar(palette, metric),
      ],
    );
  }

  Widget _buildMetricBar(
    _SimulatorPalette palette,
    ResourceUtilizationMetric metric,
  ) {
    final pair = palette.colorsForThreshold(metric.thresholdLevel);
    final fillFraction = (metric.utilizationPercent / 100.0).clamp(0.0, 1.0);
    final projectedStr = metric.id == 'auth_mau'
        ? metric.projectedValue.round().toString()
        : metric.projectedValue.toStringAsFixed(2);
    final quotaStr = metric.id == 'auth_mau'
        ? metric.includedQuota.round().toString()
        : metric.includedQuota.toStringAsFixed(0);

    return Container(
      key: ValueKey<String>('sim_metric_${metric.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '${metric.labelJa}: $projectedStr / $quotaStr ${metric.unit}',
                softWrap: true,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              _SimulatorBadge(
                label:
                    '${metric.utilizationPercent.toStringAsFixed(1)}% · ${metric.thresholdLevel.labelJa}',
                bg: pair.bg,
                fg: pair.fg,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.barTrack,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fillFraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: pair.fg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliders(
    _SimulatorPalette palette,
    SupabaseResourceSimulatorController controller,
  ) {
    final inputs = controller.inputs;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  'トラフィック・データ量パラメータ調整',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSliderRow(
            palette: palette,
            sliderKey: const ValueKey<String>('sim_mau_slider'),
            label: '月間アクティブユーザー数 (MAU): ${inputs.mau}',
            value: inputs.mau.toDouble().clamp(0.0, 200000.0),
            min: 0.0,
            max: 200000.0,
            divisions: 40,
            onChanged: (double v) => controller.setMau(v.round()),
          ),
          _buildSliderRow(
            palette: palette,
            sliderKey: const ValueKey<String>('sim_db_slider'),
            label:
                '1ユーザーあたりDB使用量: ${inputs.avgDbMbPerUser.toStringAsFixed(3)} MB',
            value: inputs.avgDbMbPerUser.clamp(0.005, 0.25),
            min: 0.005,
            max: 0.25,
            divisions: 49,
            onChanged: controller.setAvgDbMbPerUser,
          ),
          _buildSliderRow(
            palette: palette,
            sliderKey: const ValueKey<String>('sim_egress_slider'),
            label:
                '1ユーザーあたり月間Egress: ${inputs.avgEgressMbPerUser.toStringAsFixed(2)} MB',
            value: inputs.avgEgressMbPerUser.clamp(0.05, 5.0),
            min: 0.05,
            max: 5.0,
            divisions: 99,
            onChanged: controller.setAvgEgressMbPerUser,
          ),
          _buildSliderRow(
            palette: palette,
            sliderKey: const ValueKey<String>('sim_storage_slider'),
            label: 'ファイルストレージ合計: ${inputs.storageGb.toStringAsFixed(2)} GB',
            value: inputs.storageGb.clamp(0.0, 150.0),
            min: 0.0,
            max: 150.0,
            divisions: 150,
            onChanged: controller.setStorageGb,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required _SimulatorPalette palette,
    required Key sliderKey,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                softWrap: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        Semantics(
          label: label,
          child: Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: palette.primaryBtnBg,
            inactiveColor: palette.barTrack,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSourceDisclaimer(_SimulatorPalette palette) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            '参照元: ${SupabasePlanQuotaSpec.pricingSourceUrl}（${SupabasePlanQuotaSpec.pricingVerifiedDate} 確認時点・従量単価と上限は変更される可能性があるため定期再確認が必要）',
            softWrap: true,
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SimulatorBadge extends StatelessWidget {
  const _SimulatorBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        softWrap: true,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
