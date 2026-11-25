import 'package:flutter/material.dart';

import '../services/async_submission_guard.dart';

/// 非同期送信中に配下フォームの操作・誤戻る遷移を抑止し、完了/失敗フィードバックを表示するラッパー (#2726)。
class GuardedAsyncFormScope extends StatelessWidget {
  const GuardedAsyncFormScope({
    super.key,
    required this.guard,
    required this.child,
    this.blockBackNavigationWhileSubmitting = true,
    this.showStatusBanner = true,
  });

  final AsyncSubmissionGuard guard;
  final Widget child;
  final bool blockBackNavigationWhileSubmitting;
  final bool showStatusBanner;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: guard,
      builder: (context, _) {
        final submitting = guard.isSubmitting;
        final scheme = Theme.of(context).colorScheme;
        final bannerText = switch (guard.phase) {
          AsyncSubmissionPhase.failed => guard.errorMessage,
          AsyncSubmissionPhase.succeeded => guard.successMessage,
          _ => null,
        };
        final isErrorBanner = guard.phase == AsyncSubmissionPhase.failed;

        return PopScope(
          canPop: !blockBackNavigationWhileSubmitting || !submitting,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showStatusBanner &&
                  bannerText != null &&
                  bannerText.trim().isNotEmpty) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey<String>('async_submit_status_banner'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isErrorBanner
                          ? scheme.errorContainer
                          : scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      bannerText,
                      style: TextStyle(
                        color: isErrorBanner
                            ? scheme.onErrorContainer
                            : scheme.onPrimaryContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AbsorbPointer(
                absorbing: submitting,
                child: Opacity(
                  opacity: submitting ? 0.65 : 1.0,
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 送信中ロック・二重タップ防止・成功時遷移/失敗時エラーフィードバックを統合した実行ボタン (#2726)。
class GuardedAsyncActionButton extends StatelessWidget {
  const GuardedAsyncActionButton({
    super.key,
    required this.guard,
    required this.label,
    required this.onSubmit,
    this.submittingLabel = '送信中...',
    this.successMessage,
    this.errorFormatter,
    this.onSuccessNavigate,
    this.showSnackBar = true,
    this.buttonKey,
  });

  final AsyncSubmissionGuard guard;
  final String label;
  final String submittingLabel;
  final Future<void> Function() onSubmit;
  final String? successMessage;
  final String Function(Object error)? errorFormatter;
  final VoidCallback? onSuccessNavigate;
  final bool showSnackBar;
  final Key? buttonKey;

  Future<void> _handlePress(BuildContext context) async {
    final outcome = await guard.run<void>(
      action: onSubmit,
      successMessage: successMessage,
      errorFormatter: errorFormatter,
    );
    if (!context.mounted || outcome.isIgnored) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (outcome.isSucceeded) {
      final msg = outcome.message;
      if (showSnackBar &&
          messenger != null &&
          msg != null &&
          msg.trim().isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
      onSuccessNavigate?.call();
      return;
    }

    if (outcome.isFailed) {
      final msg = outcome.message;
      if (showSnackBar &&
          messenger != null &&
          msg != null &&
          msg.trim().isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: guard,
      builder: (context, _) {
        final submitting = guard.isSubmitting;
        return FilledButton(
          key: buttonKey,
          onPressed: submitting ? null : () => _handlePress(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
          ),
          child: submitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        submittingLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Text(label),
        );
      },
    );
  }
}
