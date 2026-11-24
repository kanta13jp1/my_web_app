import 'package:flutter/material.dart';

import '../domain/did_mcp_proxy_models.dart';

/// D-ID MCP エージェント連携プロキシのプレゼンテーション View (#2662).
class DidMcpProxyView extends StatelessWidget {
  const DidMcpProxyView({
    required this.state,
    required this.promptController,
    required this.targetIdController,
    required this.onRefresh,
    required this.onToolChanged,
    required this.onDryRunChanged,
    required this.onExecute,
    required this.onAcknowledgeAlert,
    super.key,
  });

  final DidMcpProxyState state;
  final TextEditingController promptController;
  final TextEditingController targetIdController;
  final Future<void> Function() onRefresh;
  final ValueChanged<DidMcpTool> onToolChanged;
  final ValueChanged<bool> onDryRunChanged;
  final Future<bool> Function() onExecute;
  final Future<bool> Function(String alertId) onAcknowledgeAlert;

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color borderInk =
        isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final Color primaryInk =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color secondaryInk =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final Color accentBg =
        isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
    final Color accentInk =
        isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A);
    final Color errorBg =
        isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
    final Color errorInk =
        isDark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'D-ID MCP エージェント連携プロキシ',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: primaryInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('did-mcp-refresh-button'),
                tooltip: '監査ログを再読込',
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                onPressed: state.isLoading ? null : () => onRefresh(),
                icon: Icon(Icons.refresh, color: primaryInk),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'テキスト指示を JSON-RPC 2.0 MCP ツール呼出へ変換し、サーバー側の D_ID_API_KEY とレート制限 (429) アラートを一元管理します。',
            style: theme.textTheme.bodyMedium?.copyWith(color: secondaryInk),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _ProxyStatTile(
                label: '記録イベント数',
                value: '${state.events.length} 件',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
              _ProxyStatTile(
                label: 'レート制限 (429)',
                value: '${state.rateLimitedCount} 件',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
              _ProxyStatTile(
                label: '未確認アラート',
                value: '${state.unacknowledgedAlertCount} 件',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (state.errorMessage != null &&
              state.errorMessage!.isNotEmpty) ...<Widget>[
            DecoratedBox(
              key: const ValueKey<String>('did-mcp-error-banner'),
              decoration: BoxDecoration(
                color: errorBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: errorInk),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: errorInk),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          DecoratedBox(
            key: const ValueKey<String>('did-mcp-endpoint-card'),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderInk),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '公式 Streamable HTTP MCP エンドポイント (秘密鍵非露出)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accentInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    didMcpDocsEndpointUrl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: accentInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    buildDidMcpClientConfigJson(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: accentInk,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderInk),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'プロンプト → MCP ツール実行',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: primaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<DidMcpTool>(
                    key: const ValueKey<String>('did-mcp-tool-dropdown'),
                    isExpanded: true,
                    initialValue: state.selectedTool,
                    decoration: const InputDecoration(
                      labelText: '対象 MCP ツール',
                      border: OutlineInputBorder(),
                    ),
                    items: DidMcpTool.values
                        .map(
                          (final DidMcpTool tool) =>
                              DropdownMenuItem<DidMcpTool>(
                            value: tool,
                            child: Text(
                              tool.labelJa,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (final DidMcpTool? selected) {
                      if (selected != null) {
                        onToolChanged(selected);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('did-mcp-prompt-input'),
                    controller: promptController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'エージェント指示 / スクリプト / クエリ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('did-mcp-target-id-input'),
                    controller: targetIdController,
                    decoration: const InputDecoration(
                      labelText: 'Agent ID / Knowledge ID (任意)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    key: const ValueKey<String>('did-mcp-dry-run-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Dry-Run モード (外部 API 課金・変更を実行しない)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: primaryInk,
                      ),
                    ),
                    value: state.dryRunOnly,
                    onChanged: onDryRunChanged,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton.icon(
                      key: const ValueKey<String>('did-mcp-execute-button'),
                      onPressed: state.isSubmitting ? null : () => onExecute(),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        state.isSubmitting
                            ? 'MCP 呼出中...'
                            : 'JSON-RPC tools/call を実行',
                      ),
                    ),
                  ),
                  if (state.lastResponsePreview != null &&
                      state.lastResponsePreview!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    DecoratedBox(
                      key: const ValueKey<String>('did-mcp-result-banner'),
                      decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderInk),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          state.lastResponsePreview!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accentInk,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'アラート監視 (レート制限 429 / 上流障害)',
            style: theme.textTheme.titleMedium?.copyWith(
              color: primaryInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (state.alerts.isEmpty)
            Text(
              '現在アラートはありません。',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondaryInk),
            )
          else
            for (final DidMcpAlert alert in state.alerts) ...<Widget>[
              DecoratedBox(
                key: ValueKey<String>('did-mcp-alert-card-${alert.id}'),
                decoration: BoxDecoration(
                  color: alert.acknowledged ? cardBg : errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: alert.acknowledged ? borderInk : errorInk,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        '[${alert.severity.toUpperCase()}] ${alert.alertType}: ${alert.message}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: alert.acknowledged ? primaryInk : errorInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!alert.acknowledged)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: OutlinedButton(
                            key: ValueKey<String>(
                              'did-mcp-ack-button-${alert.id}',
                            ),
                            onPressed: () => onAcknowledgeAlert(alert.id),
                            child: const Text('アラートを確認済みにする'),
                          ),
                        )
                      else
                        Text(
                          '確認済み',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondaryInk,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          Text(
            'MCP プロキシ監査ログ',
            style: theme.textTheme.titleMedium?.copyWith(
              color: primaryInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (state.events.isEmpty)
            Text(
              'まだプロキシ呼出イベントがありません。',
              style: theme.textTheme.bodyMedium?.copyWith(color: secondaryInk),
            )
          else
            for (final DidMcpProxyEvent ev in state.events) ...<Widget>[
              DecoratedBox(
                key: ValueKey<String>('did-mcp-event-card-${ev.id}'),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderInk),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${ev.toolName} (${ev.status.labelJa} / HTTP ${ev.httpStatus})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: primaryInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ev.promptSummary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ProxyStatTile extends StatelessWidget {
  const _ProxyStatTile({
    required this.label,
    required this.value,
    required this.cardBg,
    required this.borderInk,
    required this.primaryInk,
    required this.secondaryInk,
  });

  final String label;
  final String value;
  final Color cardBg;
  final Color borderInk;
  final Color primaryInk;
  final Color secondaryInk;

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderInk),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: secondaryInk),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: primaryInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
