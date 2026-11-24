import 'package:flutter/material.dart';

import '../application/ai_action_budget_controller.dart';
import '../domain/ai_action_budget_models.dart';

@immutable
class _AiBudgetPalette {
  const _AiBudgetPalette({
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
    required this.successBg,
    required this.successInk,
  });

  factory _AiBudgetPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _AiBudgetPalette(
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
        successBg: Color(0xFF064E3B),
        successInk: Color(0xFFECFDF5),
      );
    }
    return const _AiBudgetPalette(
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
      successBg: Color(0xFFE6F4EA),
      successInk: Color(0xFF0D4A22),
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
  final Color successBg;
  final Color successInk;
}

/// アクション別 AI 予算・自動停止ガード 純粋 Presentation View (#2609).
class AiActionBudgetView extends StatelessWidget {
  const AiActionBudgetView({
    super.key,
    required this.state,
    required this.capController,
    required this.actionController,
    required this.onRetryLoad,
    required this.onUpdateCap,
    required this.onResumeBudget,
    required this.onRecordUsage,
  });

  final AiActionBudgetState state;
  final TextEditingController capController;
  final TextEditingController actionController;
  final VoidCallback onRetryLoad;
  final VoidCallback onUpdateCap;
  final VoidCallback onResumeBudget;
  final VoidCallback onRecordUsage;

  @override
  Widget build(BuildContext context) {
    final palette = _AiBudgetPalette.fromBrightness(
      Theme.of(context).brightness,
    );

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
              'AI アクション別予算・自動停止ガード',
              style: TextStyle(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '対象月 ${state.billingMonth} のアクション単位 USD 集計・80% 警告・100% 自動一時停止',
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            _buildStatusBanner(palette),
            const SizedBox(height: 12),
            _buildUsageProgressCard(palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorCard(palette, state.errorMessage!),
            ],
            const SizedBox(height: 14),
            _buildControlsSection(palette),
            const SizedBox(height: 14),
            _buildLedgerSection(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(_AiBudgetPalette palette) {
    final tier = state.tierStatus;
    final bool isNormal = tier == BudgetTierStatus.normal;
    final Color bg = isNormal ? palette.successBg : palette.warnBg;
    final Color fg = isNormal ? palette.successInk : palette.warnInk;
    final Color border = isNormal ? palette.successInk : palette.warnBorder;

    return DecoratedBox(
      key: const ValueKey<String>('budget_status_banner'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '予算ガード状態: ${tier.label}',
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              state.isEffectivePaused
                  ? '100% 上限到達または一時停止中のため、新規 AI アクションを自動ブロックしています。'
                  : '80% で事前警告を発報し、100% 到達で自動停止を発動します。',
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageProgressCard(_AiBudgetPalette palette) {
    final double ratio = (state.usagePct / 100.0).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '当月累計: USD ${state.totalSpentUsd.toStringAsFixed(4)} / USD ${state.config.monthlyUsdCap.toStringAsFixed(2)} (${state.usagePct.toStringAsFixed(1)}%)',
              style: TextStyle(
                color: palette.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                key: const ValueKey<String>('budget_usage_progress_bar'),
                minHeight: 12,
                value: ratio,
                backgroundColor: palette.surface,
                color: state.isEffectivePaused
                    ? palette.warnBorder
                    : palette.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(_AiBudgetPalette palette, String message) {
    return DecoratedBox(
      key: const ValueKey<String>('budget_error_banner'),
      decoration: BoxDecoration(
        color: palette.warnBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.warnBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message,
              style: TextStyle(
                color: palette.warnInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                key: const ValueKey<String>('budget_retry_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.warnInk,
                  side: BorderSide(color: palette.warnBorder),
                ),
                onPressed: onRetryLoad,
                child: const Text('再読込'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection(_AiBudgetPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('budget_cap_input'),
              controller: capController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: palette.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.surface,
                labelText: '月次上限 (USD)',
                hintText: '例: 50.0',
                labelStyle: TextStyle(color: palette.inkSecondary),
                hintStyle: TextStyle(color: palette.inkSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('budget_action_input'),
              controller: actionController,
              style: TextStyle(color: palette.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.surface,
                labelText: 'AI アクション名',
                hintText: '例: weekly_summary',
                labelStyle: TextStyle(color: palette.inkSecondary),
                hintStyle: TextStyle(color: palette.inkSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: FilledButton(
                    key: const ValueKey<String>('budget_record_action_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.accent,
                      foregroundColor: palette.onAccent,
                    ),
                    onPressed: state.isSubmitting ? null : onRecordUsage,
                    child: Text(state.isSubmitting ? '処理中...' : '記録追加'),
                  ),
                ),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: OutlinedButton(
                    key: const ValueKey<String>('budget_update_cap_button'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: palette.surface,
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: state.isSubmitting ? null : onUpdateCap,
                    child: const Text('上限更新'),
                  ),
                ),
                if (state.config.isPaused && state.callerIsAdmin)
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: OutlinedButton(
                      key: const ValueKey<String>('budget_resume_button'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: palette.surface,
                        foregroundColor: palette.ink,
                        side: BorderSide(color: palette.border),
                      ),
                      onPressed: state.isSubmitting ? null : onResumeBudget,
                      child: const Text('停止解除'),
                    ),
                  ),
              ],
            ),
            if (state.config.isPaused && !state.callerIsAdmin) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                key: const ValueKey<String>('budget_admin_review_notice'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.warnBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.warnBorder),
                ),
                child: Text(
                  '自動停止中のため、一時停止解除および月次上限の変更には管理者 (is_admin) の承認が必要です。',
                  style: TextStyle(
                    color: palette.warnInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerSection(_AiBudgetPalette palette) {
    if (state.isLoading && state.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(color: palette.accent),
        ),
      );
    }
    if (state.entries.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            '当月のアクション消費台帳はまだありません。',
            style: TextStyle(color: palette.inkSecondary),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'アクション別コスト台帳',
          style: TextStyle(
            color: palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in state.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DecoratedBox(
              key: ValueKey<String>('ledger_entry_${entry.id}'),
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${entry.actionName} (${entry.modelId})',
                      style: TextStyle(
                        color: palette.accentSoftInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'USD ${entry.estimatedUsd.toStringAsFixed(4)} / IN ${entry.promptCount} / OUT ${entry.completionCount}',
                      style: TextStyle(color: palette.ink, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
