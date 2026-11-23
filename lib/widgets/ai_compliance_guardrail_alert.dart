import 'package:flutter/material.dart';

import '../services/ai_hub_chat_service.dart';

/// コンプライアンス・ガードレールによるブロック理由と再開アクションを表示するバナー (#2736)。
class AiComplianceGuardrailAlert extends StatelessWidget {
  const AiComplianceGuardrailAlert({
    super.key,
    required this.exception,
    this.onEditPrompt,
    this.onDismiss,
  });

  final AiComplianceGuardrailException exception;
  final VoidCallback? onEditPrompt;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labels = exception.categoryLabels;
    final stageLabel =
        exception.stage == 'output' ? 'AI出力チェックで検出' : '入力プロンプトチェックで検出';

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey<String>('ai_compliance_guardrail_alert'),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.error.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.gpp_maybe_outlined,
                  color: scheme.onErrorContainer,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'コンプライアンスガードレールによりブロックされました',
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stageLabel,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              exception.userMessage,
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (labels.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final label in labels)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (exception.traceId != null &&
                exception.traceId!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '監査トレースID: ${exception.traceId}',
                style: TextStyle(
                  color: scheme.onErrorContainer,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ],
            if (onEditPrompt != null || onDismiss != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (onEditPrompt != null)
                    OutlinedButton.icon(
                      key: const ValueKey<String>(
                        'ai_compliance_edit_prompt_button',
                      ),
                      onPressed: onEditPrompt,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('入力を修正する'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onErrorContainer,
                        side: BorderSide(color: scheme.onErrorContainer),
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  if (onDismiss != null)
                    TextButton(
                      key: const ValueKey<String>(
                        'ai_compliance_dismiss_button',
                      ),
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onErrorContainer,
                        minimumSize: const Size(48, 48),
                      ),
                      child: const Text('閉じる'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
