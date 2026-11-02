import 'dart:async';

import 'package:flutter/material.dart';

/// Presents a deliberately gated confirmation for irreversible operations.
Future<bool> showCriticalActionDialog({
  required BuildContext context,
  required String title,
  required String impact,
  required String actionLabel,
  String cancelLabel = 'キャンセル',
  String? confirmationPhrase,
  Duration delay = const Duration(seconds: 3),
  Key? confirmButtonKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CriticalActionDialog(
      title: title,
      impact: impact,
      actionLabel: actionLabel,
      cancelLabel: cancelLabel,
      confirmationPhrase: confirmationPhrase,
      delay: delay,
      confirmButtonKey: confirmButtonKey,
    ),
  );
  return confirmed ?? false;
}

class CriticalActionDialog extends StatefulWidget {
  CriticalActionDialog({
    required this.title,
    required this.impact,
    required this.actionLabel,
    this.cancelLabel = 'キャンセル',
    this.confirmationPhrase,
    this.delay = const Duration(seconds: 3),
    this.confirmButtonKey,
    super.key,
  }) : assert(!delay.isNegative);

  final String title;
  final String impact;
  final String actionLabel;
  final String cancelLabel;
  final String? confirmationPhrase;
  final Duration delay;
  final Key? confirmButtonKey;

  @override
  State<CriticalActionDialog> createState() => _CriticalActionDialogState();
}

class _CriticalActionDialogState extends State<CriticalActionDialog> {
  final TextEditingController _confirmationController = TextEditingController();
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.delay.inSeconds;
    if (_remainingSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _remainingSeconds--);
        if (_remainingSeconds == 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _phraseMatches {
    final phrase = widget.confirmationPhrase;
    return phrase == null || _confirmationController.text.trim() == phrase;
  }

  bool get _canConfirm => _remainingSeconds == 0 && _phraseMatches;

  void _confirm() {
    if (_canConfirm) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final phrase = widget.confirmationPhrase;
    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: colors.error,
        size: 40,
        semanticLabel: '重要な操作',
      ),
      title: Semantics(
        header: true,
        child: Text(widget.title, textAlign: TextAlign.center),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.error),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.report_gmailerrorred, color: colors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.impact,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              if (phrase != null) ...[
                const SizedBox(height: 16),
                Text('確認のため「$phrase」と入力してください。'),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('critical_action_confirmation_input'),
                  controller: _confirmationController,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _confirm(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '確認文字列',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _remainingSeconds > 0
                      ? '内容を確認してください。実行まで残り$_remainingSeconds秒'
                      : _phraseMatches
                          ? '実行できます。'
                          : '確認文字列が一致すると実行できます。',
                  key: const Key('critical_action_gate_status'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('critical_action_cancel_button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.cancelLabel),
        ),
        FilledButton.icon(
          key: widget.confirmButtonKey ??
              const Key('critical_action_confirm_button'),
          style: FilledButton.styleFrom(backgroundColor: colors.error),
          onPressed: _canConfirm ? _confirm : null,
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
