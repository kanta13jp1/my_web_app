import 'package:flutter/material.dart';

import '../application/ai_output_validation_controller.dart';
import '../domain/ai_output_validation_models.dart';

@immutable
class _ValidationPalette {
  const _ValidationPalette({
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentSoftInk,
    required this.warnBg,
    required this.warnBorder,
    required this.warnInk,
    required this.dangerBg,
    required this.dangerBorder,
    required this.dangerInk,
    required this.okBg,
    required this.okBorder,
    required this.okInk,
  });

  factory _ValidationPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _ValidationPalette(
        surface: Color(0xFF111827),
        surfaceSubtle: Color(0xFF1F2937),
        border: Color(0xFF9CA3AF),
        ink: Color(0xFFF9FAFB),
        inkSecondary: Color(0xFFE5E7EB),
        accent: Color(0xFF93C5FD),
        onAccent: Color(0xFF0B2545),
        accentSoft: Color(0xFF1E3A5F),
        accentSoftInk: Color(0xFFE0F2FE),
        warnBg: Color(0xFF332100),
        warnBorder: Color(0xFFFBBF24),
        warnInk: Color(0xFFFEF3C7),
        dangerBg: Color(0xFF450A0A),
        dangerBorder: Color(0xFFFCA5A5),
        dangerInk: Color(0xFFFEE2E2),
        okBg: Color(0xFF022C22),
        okBorder: Color(0xFF6EE7B7),
        okInk: Color(0xFFD1FAE5),
      );
    }
    return const _ValidationPalette(
      surface: Color(0xFFFFFFFF),
      surfaceSubtle: Color(0xFFF3F5F8),
      border: Color(0xFF4B5563),
      ink: Color(0xFF111827),
      inkSecondary: Color(0xFF374151),
      accent: Color(0xFF0F4C81),
      onAccent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFE6EFF8),
      accentSoftInk: Color(0xFF0B355C),
      warnBg: Color(0xFFFFF4E5),
      warnBorder: Color(0xFF8A4B00),
      warnInk: Color(0xFF5A2E00),
      dangerBg: Color(0xFFFEF2F2),
      dangerBorder: Color(0xFF991B1B),
      dangerInk: Color(0xFF7F1D1D),
      okBg: Color(0xFFECFDF5),
      okBorder: Color(0xFF065F46),
      okInk: Color(0xFF064E3B),
    );
  }

  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentSoftInk;
  final Color warnBg;
  final Color warnBorder;
  final Color warnInk;
  final Color dangerBg;
  final Color dangerBorder;
  final Color dangerInk;
  final Color okBg;
  final Color okBorder;
  final Color okInk;
}

/// 創発的 AI 出力の決定論的検証・監査ログパネル 純粋 Presentation View (#2657).
class AiOutputValidationView extends StatelessWidget {
  const AiOutputValidationView({
    super.key,
    required this.state,
    required this.promptController,
    required this.outputController,
    required this.requiredFieldsController,
    required this.searchController,
    required this.onRetryLoad,
    required this.onSelectContract,
    required this.onSelectDecisionFilter,
    required this.onSearchChanged,
    required this.onSubmitSimulation,
  });

  final AiOutputValidationState state;
  final TextEditingController promptController;
  final TextEditingController outputController;
  final TextEditingController requiredFieldsController;
  final TextEditingController searchController;
  final VoidCallback onRetryLoad;
  final ValueChanged<OutputFormatContract> onSelectContract;
  final ValueChanged<ValidationDecision?> onSelectDecisionFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSubmitSimulation;

  @override
  Widget build(BuildContext context) {
    final palette = _ValidationPalette.fromBrightness(
      Theme.of(context).brightness,
    );
    final filteredLogs = state.filteredLogs;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '創発 AI 出力 決定的検証パイプライン',
              style: TextStyle(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Edge 応答の禁止表現・構造契約ルール検証、修正・ブロック監査記録、ベースライン揺らぎ監視',
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildMetricsSummary(palette),
            const SizedBox(height: 16),
            _buildSimulatorCard(palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorBanner(palette, state.errorMessage!),
            ],
            const SizedBox(height: 16),
            _buildFilterControls(palette),
            const SizedBox(height: 12),
            if (state.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Semantics(
                    label: '検証ログを読み込み中',
                    child: CircularProgressIndicator(color: palette.accent),
                  ),
                ),
              )
            else if (filteredLogs.isEmpty)
              _buildEmptyCard(palette)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: filteredLogs
                    .map(
                      (AiOutputValidationLog log) =>
                          _buildLogCard(palette, log),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSummary(_ValidationPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildMetricTile(palette, '総監査ログ', '${state.logs.length}件'),
        _buildMetricTile(palette, '通過', '${state.passedCount}件'),
        _buildMetricTile(palette, '自動修正', '${state.remediatedCount}件'),
        _buildMetricTile(palette, 'ブロック', '${state.blockedCount}件'),
        _buildMetricTile(
          palette,
          '平均ドリフト',
          state.averageDriftScore.toStringAsFixed(3),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    _ValidationPalette palette,
    String label,
    String value,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: palette.inkSecondary, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: palette.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    _ValidationPalette palette, {
    required String labelText,
    required String hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(color: palette.inkSecondary),
      hintStyle: TextStyle(color: palette.inkSecondary),
      filled: true,
      fillColor: palette.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: palette.accent, width: 2),
      ),
    );
  }

  Widget _buildContractSelector(_ValidationPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          OutputFormatContract.values.map((OutputFormatContract contract) {
        final selected = state.selectedContract == contract;
        return Semantics(
          selected: selected,
          button: true,
          label: '出力形式 ${contract.displayLabel}',
          child: OutlinedButton(
            key: ValueKey<String>(
              'ai-validation-contract-${contract.wireValue}',
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: selected ? palette.accentSoft : palette.surface,
              foregroundColor: selected ? palette.accentSoftInk : palette.ink,
              side: BorderSide(
                color: selected ? palette.accent : palette.border,
                width: selected ? 2 : 1,
              ),
            ),
            onPressed: () => onSelectContract(contract),
            child: Text(contract.displayLabel),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildSimulatorCard(_ValidationPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '決定的検証シミュレータ（記録テスト）',
              style: TextStyle(
                color: palette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildContractSelector(palette),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai-validation-prompt-field'),
              controller: promptController,
              style: TextStyle(color: palette.ink),
              decoration: _inputDecoration(
                palette,
                labelText: 'プロンプト抜粋',
                hintText: '例: 今月の予算達成率を要約してください',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('ai-validation-output-field'),
              controller: outputController,
              minLines: 2,
              maxLines: 4,
              style: TextStyle(color: palette.ink),
              decoration: _inputDecoration(
                palette,
                labelText: '検証対象の AI 候補出力',
                hintText: '例: ## 結論\\n達成率は92%です。\\n\\n## 根拠\\n実績集計値。',
              ),
            ),
            if (state.selectedContract ==
                OutputFormatContract.jsonObject) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey<String>('ai-validation-fields-field'),
                controller: requiredFieldsController,
                style: TextStyle(color: palette.ink),
                decoration: _inputDecoration(
                  palette,
                  labelText: '必須 JSON キー (カンマ区切り)',
                  hintText: '例: summary,confidence',
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              key: const ValueKey<String>('ai-validation-submit-button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: palette.accent,
                foregroundColor: palette.onAccent,
              ),
              onPressed: state.isSubmitting ? null : onSubmitSimulation,
              child: Text(
                state.isSubmitting ? '検証ログを記録中...' : '決定的検証を実行してログ記録',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(_ValidationPalette palette, String message) {
    return DecoratedBox(
      key: const ValueKey<String>('ai-validation-error-banner'),
      decoration: BoxDecoration(
        color: palette.dangerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.dangerBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              message,
              style: TextStyle(color: palette.dangerInk, fontSize: 13),
            ),
            OutlinedButton(
              key: const ValueKey<String>('ai-validation-retry-button'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: palette.surface,
                foregroundColor: palette.dangerInk,
                side: BorderSide(color: palette.dangerBorder),
              ),
              onPressed: onRetryLoad,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControls(_ValidationPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('ai-validation-search-field'),
          controller: searchController,
          onChanged: onSearchChanged,
          style: TextStyle(color: palette.ink),
          decoration: _inputDecoration(
            palette,
            labelText: '監査ログ検索',
            hintText: 'プロンプト・修正後出力・違反コードで検索',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildFilterButton(
              palette,
              keyValue: 'all',
              label: 'すべて',
              selected: state.selectedDecision == null,
              onPressed: () => onSelectDecisionFilter(null),
            ),
            ...ValidationDecision.values.map(
              (ValidationDecision d) => _buildFilterButton(
                palette,
                keyValue: d.wireValue,
                label: d.displayLabel,
                selected: state.selectedDecision == d,
                onPressed: () => onSelectDecisionFilter(d),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterButton(
    _ValidationPalette palette, {
    required String keyValue,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      selected: selected,
      button: true,
      label: '判定フィルタ $label',
      child: OutlinedButton(
        key: ValueKey<String>('ai-validation-filter-$keyValue'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: selected ? palette.accentSoft : palette.surface,
          foregroundColor: selected ? palette.accentSoftInk : palette.ink,
          side: BorderSide(
            color: selected ? palette.accent : palette.border,
            width: selected ? 2 : 1,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _buildEmptyCard(_ValidationPalette palette) {
    return DecoratedBox(
      key: const ValueKey<String>('ai-validation-empty-card'),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '条件に一致する検証監査ログはありません。',
          style: TextStyle(color: palette.inkSecondary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildLogCard(
    _ValidationPalette palette,
    AiOutputValidationLog log,
  ) {
    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeInk;
    switch (log.decision) {
      case ValidationDecision.passed:
        badgeBg = palette.okBg;
        badgeBorder = palette.okBorder;
        badgeInk = palette.okInk;
      case ValidationDecision.remediated:
        badgeBg = palette.warnBg;
        badgeBorder = palette.warnBorder;
        badgeInk = palette.warnInk;
      case ValidationDecision.blocked:
        badgeBg = palette.dangerBg;
        badgeBorder = palette.dangerBorder;
        badgeInk = palette.dangerInk;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        key: ValueKey<String>('ai-validation-log-${log.id}'),
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        log.decision.displayLabel,
                        style: TextStyle(
                          color: badgeInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${log.formatContract.displayLabel} | ドリフト ${log.driftScore.toStringAsFixed(2)} | ${log.ruleSetVersion}',
                    style: TextStyle(
                      color: palette.inkSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Prompt: ${log.promptExcerpt}',
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '出力結果: ${log.remediatedOutputExcerpt}',
                style: TextStyle(color: palette.inkSecondary, fontSize: 13),
              ),
              if (log.violations.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: log.violations
                      .map(
                        (ValidationViolation v) => DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              '${v.code} (${v.severity.displayLabel})',
                              style: TextStyle(
                                color: palette.inkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
