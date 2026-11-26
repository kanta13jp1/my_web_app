import 'package:flutter/material.dart';

import '../application/ai_cost_monitor_controller.dart';
import '../domain/ai_cost_monitor_models.dart';

@immutable
class _AiCostPalette {
  const _AiCostPalette({
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.onAccent,
    required this.okBg,
    required this.okBorder,
    required this.okInk,
    required this.warnBg,
    required this.warnBorder,
    required this.warnInk,
    required this.dangerBg,
    required this.dangerBorder,
    required this.dangerInk,
  });

  factory _AiCostPalette.fromBrightness(final Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _AiCostPalette(
        surface: Color(0xFF111827),
        surfaceSubtle: Color(0xFF1F2937),
        border: Color(0xFF9CA3AF),
        ink: Color(0xFFF9FAFB),
        inkSecondary: Color(0xFFE5E7EB),
        accent: Color(0xFF5EEAD4),
        onAccent: Color(0xFF042F2E),
        okBg: Color(0xFF022C22),
        okBorder: Color(0xFF5EEAD4),
        okInk: Color(0xFFCCFBF1),
        warnBg: Color(0xFF332100),
        warnBorder: Color(0xFFFBBF24),
        warnInk: Color(0xFFFEF3C7),
        dangerBg: Color(0xFF450A0A),
        dangerBorder: Color(0xFFFCA5A5),
        dangerInk: Color(0xFFFEE2E2),
      );
    }
    return const _AiCostPalette(
      surface: Color(0xFFFFFFFF),
      surfaceSubtle: Color(0xFFF3F5F8),
      border: Color(0xFF4B5563),
      ink: Color(0xFF111827),
      inkSecondary: Color(0xFF374151),
      accent: Color(0xFF115E59),
      onAccent: Color(0xFFFFFFFF),
      okBg: Color(0xFFECFDF5),
      okBorder: Color(0xFF115E59),
      okInk: Color(0xFF064E3B),
      warnBg: Color(0xFFFFF4E5),
      warnBorder: Color(0xFF8A4B00),
      warnInk: Color(0xFF5A2E00),
      dangerBg: Color(0xFFFEF2F2),
      dangerBorder: Color(0xFFB91C1C),
      dangerInk: Color(0xFF7F1D1D),
    );
  }

  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final Color onAccent;
  final Color okBg;
  final Color okBorder;
  final Color okInk;
  final Color warnBg;
  final Color warnBorder;
  final Color warnInk;
  final Color dangerBg;
  final Color dangerBorder;
  final Color dangerInk;
}

class AiCostMonitorView extends StatelessWidget {
  const AiCostMonitorView({
    super.key,
    required this.state,
    required this.thresholdController,
    required this.inputUnitsController,
    required this.outputUnitsController,
    required this.onRefresh,
    required this.onProviderFilterChanged,
    required this.onDraftModelChanged,
    required this.onRecordUsage,
    required this.onCheckBudget,
  });

  final AiCostMonitorState state;
  final TextEditingController thresholdController;
  final TextEditingController inputUnitsController;
  final TextEditingController outputUnitsController;
  final VoidCallback onRefresh;
  final ValueChanged<String> onProviderFilterChanged;
  final ValueChanged<String> onDraftModelChanged;
  final VoidCallback onRecordUsage;
  final VoidCallback onCheckBudget;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final palette = _AiCostPalette.fromBrightness(theme.brightness);
    final snapshot = state.snapshot;
    final outcome = state.lastBudgetOutcome;

    return Container(
      color: palette.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context, theme, palette, snapshot),
            const SizedBox(height: 12),
            if (state.errorMessage != null) ...<Widget>[
              _buildBanner(
                key: const ValueKey<String>('ai_cost_error_banner'),
                icon: Icons.error_outline,
                bg: palette.dangerBg,
                border: palette.dangerBorder,
                fg: palette.dangerInk,
                title: 'エラーが発生しました',
                body: state.errorMessage!,
                theme: theme,
              ),
              const SizedBox(height: 12),
            ],
            if (state.noticeMessage != null) ...<Widget>[
              _buildBanner(
                key: const ValueKey<String>('ai_cost_notice_banner'),
                icon: Icons.info_outline,
                bg: palette.okBg,
                border: palette.okBorder,
                fg: palette.okInk,
                title: '実行結果',
                body: state.noticeMessage!,
                theme: theme,
              ),
              const SizedBox(height: 12),
            ],
            if (outcome != null && outcome.thresholdExceeded) ...<Widget>[
              _buildBanner(
                key: const ValueKey<String>('ai_cost_budget_alert_banner'),
                icon: Icons.warning_amber_rounded,
                bg: palette.dangerBg,
                border: palette.dangerBorder,
                fg: palette.dangerInk,
                title: '日次予算閾値を超過しました (${outcome.targetDate})',
                body: '実測概算 \$${outcome.dailyCostUsd.toStringAsFixed(4)} / '
                    '閾値 \$${outcome.budgetThresholdUsd.toStringAsFixed(2)} '
                    '(超過 \$${outcome.exceededByUsd.toStringAsFixed(4)})・'
                    'GitHub Issue状態: ${outcome.githubStatus}'
                    '${outcome.issueTitle.isNotEmpty ? '・${outcome.issueTitle}' : ''}',
                theme: theme,
              ),
              const SizedBox(height: 12),
            ],
            _buildSummaryCards(theme, palette, snapshot),
            const SizedBox(height: 16),
            _buildDisclaimerCard(theme, palette, snapshot.pricingDisclaimer),
            const SizedBox(height: 16),
            _buildBudgetThresholdCard(theme, palette),
            const SizedBox(height: 16),
            _buildProviderBreakdownCard(theme, palette, snapshot),
            const SizedBox(height: 16),
            _buildManualRecordCard(theme, palette),
            const SizedBox(height: 16),
            _buildLogsCard(theme, palette),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    final BuildContext context,
    final ThemeData theme,
    final _AiCostPalette palette,
    final AiCostDashboardSnapshot snapshot,
  ) {
    final dateText = snapshot.targetDate.isEmpty ? '本日' : snapshot.targetDate;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'サードパーティ AI API コスト監視',
              style: theme.textTheme.titleLarge?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gemini / OpenAI / Anthropic / DeepSeek 日次利用額 ($dateText)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            ),
          ],
        ),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('ai_cost_refresh_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accent,
              side: BorderSide(color: palette.accent),
              minimumSize: const Size(48, 48),
            ),
            onPressed: state.isLoading ? null : onRefresh,
            icon: state.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.accent,
                    ),
                  )
                : const Icon(Icons.refresh),
            label: const Text('再集計'),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner({
    required final Key key,
    required final IconData icon,
    required final Color bg,
    required final Color border,
    required final Color fg,
    required final String title,
    required final String body,
    required final ThemeData theme,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(
    final ThemeData theme,
    final _AiCostPalette palette,
    final AiCostDashboardSnapshot snapshot,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        _buildKpiTile(
          theme: theme,
          palette: palette,
          key: const ValueKey<String>('ai_cost_daily_total_card'),
          label: '本日の既知概算コスト',
          value: '\$${snapshot.totalCostUsd.toStringAsFixed(4)}',
          subtext: '${snapshot.knownCostCalls} 件の単価確定呼び出し',
        ),
        _buildKpiTile(
          theme: theme,
          palette: palette,
          key: const ValueKey<String>('ai_cost_total_calls_card'),
          label: '本日総リクエスト / 消費量',
          value: '${snapshot.totalCalls} 回',
          subtext: '${snapshot.totalUnits} 単位 '
              '(入力 ${snapshot.totalInputUnits} / 出力 ${snapshot.totalOutputUnits})',
        ),
        _buildKpiTile(
          theme: theme,
          palette: palette,
          key: const ValueKey<String>('ai_cost_unpriced_card'),
          label: '単価未設定呼び出し',
          value: '${snapshot.unpricedCallCount} 件',
          subtext: snapshot.unpricedCallCount > 0
              ? '概算合計に含めず別計上 (0 USD 丸めなし)'
              : 'すべて参考単価適用済み',
        ),
      ],
    );
  }

  Widget _buildKpiTile({
    required final ThemeData theme,
    required final _AiCostPalette palette,
    required final Key key,
    required final String label,
    required final String value,
    required final String subtext,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
      child: Container(
        key: key,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard(
    final ThemeData theme,
    final _AiCostPalette palette,
    final String disclaimer,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.warnBg,
        border: Border.all(color: palette.warnBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: palette.warnInk, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              disclaimer,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: palette.warnInk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetThresholdCard(
    final ThemeData theme,
    final _AiCostPalette palette,
  ) {
    final alerts = state.snapshot.recentAlerts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '日次予算閾値 & 自動 GitHub Issue アラート',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: TextField(
                  key: const ValueKey<String>('budget_threshold_field'),
                  controller: thresholdController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: palette.ink),
                  decoration: InputDecoration(
                    labelText: '日次予算閾値 (USD)',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const ValueKey<String>('check_budget_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: state.isSaving ? null : onCheckBudget,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('予算超過チェックを実行'),
                ),
              ),
            ],
          ),
          if (alerts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              '最近のアラート履歴 (${alerts.length}件)',
              style: theme.textTheme.labelLarge?.copyWith(
                color: palette.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            for (final alert in alerts.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '・[${alert.usageDate}] \$${alert.dailyCostUsd.toStringAsFixed(4)} > '
                  '\$${alert.budgetThresholdUsd.toStringAsFixed(2)} '
                  '(${alert.githubStatus})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.inkSecondary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderBreakdownCard(
    final ThemeData theme,
    final _AiCostPalette palette,
    final AiCostDashboardSnapshot snapshot,
  ) {
    final maxCost = snapshot.byProvider.isEmpty
        ? 1.0
        : snapshot.byProvider
            .map((final item) => item.estimatedCostUsd)
            .reduce((final a, final b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'プロバイダー別コスト内訳',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (snapshot.byProvider.isEmpty)
            Text(
              '本日の利用ログはまだありません。',
              key: const ValueKey<String>('ai_cost_empty_state'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            )
          else
            for (final item in snapshot.byProvider) ...<Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${item.provider} (${item.callCount}回'
                      '${item.unpricedCallCount > 0 ? ', 未設定${item.unpricedCallCount}' : ''})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '\$${item.estimatedCostUsd.toStringAsFixed(4)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: maxCost > 0
                    ? (item.estimatedCostUsd / maxCost).clamp(0.0, 1.0)
                    : 0.0,
                backgroundColor: palette.surface,
                color: palette.accent,
                minHeight: 8,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildManualRecordCard(
    final ThemeData theme,
    final _AiCostPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '利用ログの手動記録・コスト試算',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: DropdownButtonFormField<String>(
                  key: const ValueKey<String>('ai_cost_model_dropdown'),
                  isExpanded: true,
                  initialValue: state.draftModel,
                  decoration: InputDecoration(
                    labelText: '対象モデル',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                  items: AiCostMonitorController.availableSampleModels
                      .map(
                        (final model) => DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            model,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (final value) {
                    if (value != null) onDraftModelChanged(value);
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: TextField(
                  key: const ValueKey<String>('ai_cost_input_units_field'),
                  controller: inputUnitsController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: palette.ink),
                  decoration: InputDecoration(
                    labelText: '入力消費単位',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: TextField(
                  key: const ValueKey<String>('ai_cost_output_units_field'),
                  controller: outputUnitsController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: palette.ink),
                  decoration: InputDecoration(
                    labelText: '出力消費単位',
                    labelStyle: TextStyle(color: palette.inkSecondary),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: palette.surface,
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const ValueKey<String>('ai_cost_record_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: state.isSaving ? null : onRecordUsage,
                  icon: const Icon(Icons.add_chart_outlined),
                  label: const Text('消費ログを記録'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsCard(
    final ThemeData theme,
    final _AiCostPalette palette,
  ) {
    final logs = state.filteredLogs;
    const filters = <String>[
      'all',
      'gemini',
      'openai',
      'anthropic',
      'deepseek',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '最新の API 利用ログ',
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final provider in filters)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ChoiceChip(
                    key: ValueKey<String>('ai_cost_filter_$provider'),
                    label: Text(
                      provider == 'all' ? 'すべて' : provider,
                      style: TextStyle(
                        color: state.selectedProviderFilter == provider
                            ? palette.onAccent
                            : palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: state.selectedProviderFilter == provider,
                    selectedColor: palette.accent,
                    backgroundColor: palette.surface,
                    side: BorderSide(color: palette.border),
                    onSelected: (_) => onProviderFilterChanged(provider),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            Text(
              '条件に一致する利用ログはありません。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
              ),
            )
          else
            for (final log in logs.take(20)) ...<Widget>[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${log.provider} / ${log.model}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: palette.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'action=${log.actionName} ・ '
                            '入力 ${log.inputUnits} / 出力 ${log.outputUnits}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: log.knownPricing && log.estimatedCostUsd != null
                            ? palette.okBg
                            : palette.warnBg,
                        border: Border.all(
                          color:
                              log.knownPricing && log.estimatedCostUsd != null
                                  ? palette.okBorder
                                  : palette.warnBorder,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        log.knownPricing && log.estimatedCostUsd != null
                            ? '\$${log.estimatedCostUsd!.toStringAsFixed(6)}'
                            : '単価未登録',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              log.knownPricing && log.estimatedCostUsd != null
                                  ? palette.okInk
                                  : palette.warnInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
