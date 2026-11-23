import 'package:flutter/material.dart';

import '../atoms/focus_blur_text_field.dart';

/// 複数フィールドの検証を一括実行し、クライアント検証通過時のみ送信を許可する Organism (#2730)。
class ValidatedSubmitFormCard extends StatelessWidget {
  const ValidatedSubmitFormCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.fieldKeys,
    required this.children,
    required this.submitLabel,
    required this.onValidSubmit,
    this.submitButtonKey,
    this.secondaryAction,
    this.isSubmitting = false,
  });

  final String title;
  final String? subtitle;
  final List<GlobalKey<FocusBlurTextFieldState>> fieldKeys;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback onValidSubmit;
  final Key? submitButtonKey;
  final Widget? secondaryAction;
  final bool isSubmitting;

  void _handleSubmit() {
    var allValid = true;
    for (final key in fieldKeys) {
      final state = key.currentState;
      if (state != null && !state.validateNow()) {
        allValid = false;
      }
    }
    if (!allValid) {
      return;
    }
    onValidSubmit();
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: isSubmitting ? null : _handleSubmit,
                child: Text(isSubmitting ? '処理中...' : submitLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
