import 'package:flutter/material.dart';

import '../models/chat_message_origin.dart';

/// ユーザー入力と MCP `sampling/createMessage` 注入プロンプトを視覚的に明確区別するカード (#2682)。
class SamplingOriginMessageCard extends StatelessWidget {
  final ChatMessageOrigin origin;
  final String messageText;
  final VoidCallback? onInspectOrigin;

  const SamplingOriginMessageCard({
    super.key,
    required this.origin,
    required this.messageText,
    this.onInspectOrigin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (origin.isMcpSampling) {
      const accent = Color(0xFFD97706);
      final serverLabel = origin.sourceServer.trim().isEmpty
          ? '不明なMCPサーバー'
          : origin.sourceServer.trim();
      final methodLabel = (origin.rpcMethod?.trim().isNotEmpty ?? false)
          ? origin.rpcMethod!.trim()
          : 'sampling/createMessage';

      return Semantics(
        container: true,
        label: '${origin.displayBadgeLabel} 出所サーバー $serverLabel',
        child: Container(
          key: const Key('sampling_origin_card_mcp'),
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accent.withValues(alpha: 0.75),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    key: const Key('sampling_origin_badge_mcp'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          origin.displayBadgeLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _OriginMetaChip(label: '出所: $serverLabel', color: accent),
                  if (origin.toolName != null &&
                      origin.toolName!.trim().isNotEmpty)
                    _OriginMetaChip(
                      label: 'ツール: ${origin.toolName!.trim()}',
                      color: scheme.primary,
                    ),
                  _OriginMetaChip(
                    label: 'メソッド: $methodLabel',
                    color: scheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                messageText,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (onInspectOrigin != null) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: TextButton.icon(
                    key: const Key('sampling_origin_inspect_btn'),
                    onPressed: onInspectOrigin,
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('送信元詳細を確認'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final isUser = origin.type == ChatMessageOriginType.userInput;
    final accent = isUser ? scheme.primary : scheme.secondary;

    return Semantics(
      container: true,
      label: origin.displayBadgeLabel,
      child: Container(
        key: Key(
          isUser ? 'sampling_origin_card_user' : 'sampling_origin_card_other',
        ),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  origin.displayBadgeLabel,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              messageText,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginMetaChip extends StatelessWidget {
  final String label;
  final Color color;

  const _OriginMetaChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
