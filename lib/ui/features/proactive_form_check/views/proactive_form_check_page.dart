import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/proactive_form_check_models.dart';
import '../view_models/proactive_form_check_view_model.dart';

class ProactiveFormCheckPage extends StatefulWidget {
  const ProactiveFormCheckPage({super.key});

  @override
  State<ProactiveFormCheckPage> createState() => _ProactiveFormCheckPageState();
}

class _ProactiveFormCheckPageState extends State<ProactiveFormCheckPage> {
  static const _wideBreakpoint = 820.0;

  final Map<ProactiveFormField, TextEditingController> _controllers =
      <ProactiveFormField, TextEditingController>{
    for (final field in ProactiveFormField.values)
      field: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ProactiveFormCheckViewModel>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('入力チェックアシスタント')),
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                colors.primaryContainer.withValues(alpha: 0.28),
                colors.surface,
                colors.tertiaryContainer.withValues(alpha: 0.20),
              ],
            ),
          ),
          child: ListenableBuilder(
            listenable: viewModel,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= _wideBreakpoint;
                  final form = _FormPanel(
                    controllers: _controllers,
                    viewModel: viewModel,
                    onSubmit: () => _submit(viewModel),
                  );
                  final results = _ValidationPanel(
                    viewModel: viewModel,
                    onApply: (finding) => _applySuggestion(viewModel, finding),
                  );
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 16,
                      vertical: 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _PageIntro(),
                            const SizedBox(height: 24),
                            if (isWide)
                              Row(
                                key: const Key('proactive-form-check-wide'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Expanded(flex: 6, child: form),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 5, child: results),
                                ],
                              )
                            else
                              Column(
                                key: const Key('proactive-form-check-narrow'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  form,
                                  const SizedBox(height: 20),
                                  results,
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _applySuggestion(
    ProactiveFormCheckViewModel viewModel,
    ProactiveValidationFinding finding,
  ) async {
    final suggestion = finding.suggestedValue;
    if (suggestion == null) return;
    final controller = _controllers[finding.field]!;
    controller.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    await viewModel.applySuggestion(finding);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${finding.field.label}へ修正案を反映しました。')),
    );
  }

  Future<void> _submit(ProactiveFormCheckViewModel viewModel) async {
    FocusScope.of(context).unfocus();
    final submitted = await viewModel.submit();
    if (!mounted || !submitted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('入力内容を安全に送信できました。')));
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '送信する前に、つまずきを解決',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '入力しながら、エラーと直し方がわかる。',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '入力は端末内で非同期に検証されます。作業を止めずに問題を見つけ、修正案をそのまま反映できます。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.controllers,
    required this.viewModel,
    required this.onSubmit,
  });

  final Map<ProactiveFormField, TextEditingController> controllers;
  final ProactiveFormCheckViewModel viewModel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '配信設定',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'すべて必須です。入力を止めると自動でチェックします。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _field(
              field: ProactiveFormField.title,
              label: 'タイトル',
              hint: '例: 夏の新商品キャンペーン',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _field(
              field: ProactiveFormField.email,
              label: '通知先メールアドレス',
              hint: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _field(
              field: ProactiveFormField.destinationUrl,
              label: '遷移先URL',
              hint: 'https://example.com/campaign',
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            _field(
              field: ProactiveFormField.dailyBudget,
              label: '1日の予算（円）',
              hint: '3000',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,，円¥￥\s-]')),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const Key('proactive-form-submit'),
              onPressed: viewModel.canSubmit ? onSubmit : null,
              icon: viewModel.isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(viewModel.isSubmitting ? '送信中…' : '内容を送信'),
            ),
            if (viewModel.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                viewModel.errorMessage!,
                key: const Key('proactive-form-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (viewModel.wasSubmitted) ...<Widget>[
              const SizedBox(height: 12),
              const _SuccessMessage(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field({
    required ProactiveFormField field,
    required String label,
    required String hint,
    required TextInputAction textInputAction,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      key: Key('proactive-${field.name}-field'),
      controller: controllers[field],
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autofillHints: field == ProactiveFormField.email
          ? const <String>[AutofillHints.email]
          : null,
      onChanged: (value) => viewModel.updateField(field, value),
      onSubmitted: field == ProactiveFormField.dailyBudget
          ? (_) {
              if (viewModel.canSubmit) onSubmit();
            }
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.viewModel, required this.onApply});

  final ProactiveFormCheckViewModel viewModel;
  final Future<void> Function(ProactiveValidationFinding finding) onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final findings = viewModel.visibleFindings;
    final blockingCount =
        findings.where((finding) => finding.blocksSubmission).length;
    final warningCount = findings.length - blockingCount;
    final announcement = switch (viewModel.status) {
      ProactiveValidationStatus.idle => '入力チェックは待機中です。',
      ProactiveValidationStatus.waiting ||
      ProactiveValidationStatus.validating =>
        '入力内容を確認しています。',
      ProactiveValidationStatus.failure => '入力内容を確認できませんでした。',
      ProactiveValidationStatus.ready =>
        '入力チェック完了。送信を妨げるエラー$blockingCount件、改善の提案$warningCount件です。',
    };
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Semantics(
          container: true,
          label: '入力内容の検証結果',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                liveRegion: true,
                label: announcement,
                child: const SizedBox.shrink(),
              ),
              Row(
                children: <Widget>[
                  Icon(Icons.fact_check_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'リアルタイムチェック',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusChip(status: viewModel.status),
                ],
              ),
              const SizedBox(height: 16),
              if (viewModel.status == ProactiveValidationStatus.idle)
                const _EmptyState(
                  icon: Icons.edit_note_outlined,
                  message: '入力を始めると、ここに問題と解決策を表示します。',
                )
              else if (viewModel.status == ProactiveValidationStatus.waiting ||
                  viewModel.status == ProactiveValidationStatus.validating)
                const _EmptyState(
                  icon: Icons.manage_search,
                  message: '入力をバックグラウンドで確認しています…',
                )
              else if (viewModel.status == ProactiveValidationStatus.failure)
                _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: viewModel.errorMessage ?? '検証できませんでした。',
                )
              else if (findings.isEmpty)
                const _EmptyState(
                  key: Key('proactive-validation-clear'),
                  icon: Icons.check_circle_outline,
                  message: '現在の入力に問題は見つかりませんでした。',
                  positive: true,
                )
              else
                ...findings.map(
                  (finding) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FindingCard(
                      finding: finding,
                      onApply: finding.suggestedValue == null
                          ? null
                          : () => onApply(finding),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                viewModel.hasBlockingFinding
                    ? '赤い項目を解決すると送信できます。'
                    : viewModel.canSubmit
                        ? '送信の準備ができました。'
                        : 'すべての必須項目を入力してください。',
                key: const Key('proactive-submit-guidance'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding, required this.onApply});

  final ProactiveValidationFinding finding;
  final Future<void> Function()? onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final blocking = finding.blocksSubmission;
    final background =
        blocking ? colors.errorContainer : colors.secondaryContainer;
    final foreground =
        blocking ? colors.onErrorContainer : colors.onSecondaryContainer;
    final severityLabel = blocking ? '送信を妨げるエラー' : '改善の提案';
    return Semantics(
      container: true,
      label: severityLabel,
      child: Container(
        key: Key('proactive-finding-${finding.id}'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  blocking ? Icons.error_outline : Icons.lightbulb_outline,
                  color: foreground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '$severityLabel・${finding.field.label}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        finding.message,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '解決策: ${finding.solution}',
              style: TextStyle(color: foreground),
            ),
            if (onApply != null) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: Key('apply-${finding.id}'),
                onPressed: onApply,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('修正案を反映'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ProactiveValidationStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (status) {
      ProactiveValidationStatus.idle => ('待機中', Icons.pause_circle_outline),
      ProactiveValidationStatus.waiting => ('入力待ち', Icons.more_time),
      ProactiveValidationStatus.validating => ('確認中', Icons.sync),
      ProactiveValidationStatus.ready => ('確認済み', Icons.check_circle),
      ProactiveValidationStatus.failure => ('再試行', Icons.sync_problem),
    };
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.positive = false,
  });

  final IconData icon;
  final String message;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            positive ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: positive ? colors.primary : colors.outline),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _SuccessMessage extends StatelessWidget {
  const _SuccessMessage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('proactive-form-success'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.check_circle_outline),
          SizedBox(width: 8),
          Expanded(child: Text('エラーのない内容として送信しました。')),
        ],
      ),
    );
  }
}
