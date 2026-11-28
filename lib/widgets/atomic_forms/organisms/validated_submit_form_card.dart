import 'package:flutter/material.dart';

import '../../../services/async_submission_guard.dart';
import '../../async_submit_guard_widgets.dart';
import '../atoms/focus_blur_text_field.dart';

/// 複数フィールドの検証を一括実行し、クライアント検証通過時のみ送信を許可する Organism (#2730 / #2726)。
class ValidatedSubmitFormCard extends StatelessWidget {
  const ValidatedSubmitFormCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.fieldKeys,
    required this.children,
    required this.submitLabel,
    this.onValidSubmit,
    this.onValidSubmitAsync,
    this.submissionGuard,
    this.onSuccessNavigate,
    this.successMessage,
    this.errorFormatter,
    this.submittingLabel = '処理中...',
    this.submitButtonKey,
    this.secondaryAction,
    this.isSubmitting = false,
  }) : assert(onValidSubmit != null || onValidSubmitAsync != null);

  final String title;
  final String? subtitle;
  final List<GlobalKey<FocusBlurTextFieldState>> fieldKeys;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onValidSubmit;
  final Future<void> Function()? onValidSubmitAsync;
  final AsyncSubmissionGuard? submissionGuard;
  final VoidCallback? onSuccessNavigate;
  final String? successMessage;
  final String Function(Object error)? errorFormatter;
  final String submittingLabel;
  final Key? submitButtonKey;
  final Widget? secondaryAction;
  final bool isSubmitting;

  bool _validateFields() {
    var allValid = true;
    for (final key in fieldKeys) {
      final state = key.currentState;
      if (state != null && !state.validateNow()) {
        allValid = false;
      }
    }
    return allValid;
  }

  Future<void> _handleSubmit(BuildContext context) async {
    if (!_validateFields()) {
      return;
    }
    final guard = submissionGuard;
    final asyncSubmit = onValidSubmitAsync;
    if (guard != null && asyncSubmit != null) {
      final outcome = await guard.run<void>(
        action: asyncSubmit,
        successMessage: successMessage,
        errorFormatter: errorFormatter,
      );
      if (!context.mounted || outcome.isIgnored) {
        return;
      }
      final messenger = ScaffoldMessenger.maybeOf(context);
      final message = outcome.message;
      if (messenger != null && message != null && message.trim().isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      if (outcome.isSucceeded) {
        onSuccessNavigate?.call();
      }
      return;
    }
    onValidSubmit?.call();
  }

  Widget _buildBody(BuildContext context, {required bool submitting}) {
    final sub = subtitle;
    final secondary = secondaryAction;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sub != null && sub.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              if (secondary != null) secondary,
              FilledButton(
                key: submitButtonKey,
                onPressed: submitting ? null : () => _handleSubmit(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: Text(submitting ? submittingLabel : submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guard = submissionGuard;
    if (guard == null) {
      return _buildBody(context, submitting: isSubmitting);
    }
    return GuardedAsyncFormScope(
      guard: guard,
      child: ListenableBuilder(
        listenable: guard,
        builder: (context, _) => _buildBody(
          context,
          submitting: isSubmitting || guard.isSubmitting,
        ),
      ),
    );
  }
}
