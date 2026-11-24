import 'package:flutter/material.dart';

import '../application/external_ai_webhook_controller.dart';
import '../domain/external_ai_webhook_models.dart';

/// 外部 AI ツール連携 Webhook 受信・Realtime 監視 UI (#2663).
class ExternalAiWebhookView extends StatelessWidget {
  const ExternalAiWebhookView({
    super.key,
    required this.state,
    required this.selectedTestSource,
    required this.keyLabelController,
    required this.eventTypeController,
    required this.sampleNoteController,
    required this.onRetryLoad,
    required this.onSelectSourceFilter,
    required this.onSelectTestSource,
    required this.onCreateKey,
    required this.onRevokeKey,
    required this.onDismissPlaintextKey,
    required this.onSendDryRun,
    required this.onSendLiveTest,
  });

  final ExternalAiWebhookState state;
  final ExternalWebhookSourceTool selectedTestSource;
  final TextEditingController keyLabelController;
  final TextEditingController eventTypeController;
  final TextEditingController sampleNoteController;
  final VoidCallback onRetryLoad;
  final ValueChanged<ExternalWebhookSourceTool?> onSelectSourceFilter;
  final ValueChanged<ExternalWebhookSourceTool> onSelectTestSource;
  final VoidCallback onCreateKey;
  final ValueChanged<String> onRevokeKey;
  final VoidCallback onDismissPlaintextKey;
  final VoidCallback onSendDryRun;
  final VoidCallback onSendLiveTest;

  @override
  Widget build(final BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _WebhookPalette(isDark: isDark);
    final filteredEvents = state.filteredEvents;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderSummaryCard(
            state: state,
            palette: palette,
            onRefresh: onRetryLoad,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _NoticeBanner(
              key: const ValueKey<String>('webhook_error_banner'),
              message: state.errorMessage!,
              backgroundColor: palette.errorBg,
              borderColor: palette.errorBorder,
              textColor: palette.errorText,
              actionLabel: '再試行',
              actionKey: const ValueKey<String>('webhook_retry_button'),
              onAction: onRetryLoad,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _NoticeBanner(
              key: const ValueKey<String>('webhook_status_notice'),
              message: state.statusNotice!,
              backgroundColor: palette.noticeBg,
              borderColor: palette.noticeBorder,
              textColor: palette.noticeText,
            ),
            const SizedBox(height: 12),
          ],
          if (state.latestCreatedPlaintextKey != null) ...<Widget>[
            _PlaintextKeyRevealCard(
              plaintextKey: state.latestCreatedPlaintextKey!,
              palette: palette,
              onDismiss: onDismissPlaintextKey,
            ),
            const SizedBox(height: 12),
          ],
          _ApiKeysCard(
            state: state,
            palette: palette,
            keyLabelController: keyLabelController,
            onCreateKey: onCreateKey,
            onRevokeKey: onRevokeKey,
          ),
          const SizedBox(height: 12),
          _WebhookTesterCard(
            state: state,
            palette: palette,
            selectedTestSource: selectedTestSource,
            eventTypeController: eventTypeController,
            sampleNoteController: sampleNoteController,
            onSelectTestSource: onSelectTestSource,
            onSendDryRun: onSendDryRun,
            onSendLiveTest: onSendLiveTest,
          ),
          const SizedBox(height: 12),
          _RealtimeEventsSection(
            events: filteredEvents,
            selectedSourceFilter: state.selectedSourceFilter,
            isLoading: state.isLoading,
            palette: palette,
            onSelectSourceFilter: onSelectSourceFilter,
          ),
        ],
      ),
    );
  }
}

class _WebhookPalette {
  const _WebhookPalette({required this.isDark});

  final bool isDark;

  Color get cardBg =>
      isDark ? const Color(0xFF161D26) : const Color(0xFFFFFFFF);
  Color get cardBorder =>
      isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  Color get surfaceSubtle =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  Color get titleText =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get mutedText =>
      isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
  Color get accentBg =>
      isDark ? const Color(0xFF2563EB) : const Color(0xFF1D4ED8);
  Color get accentFg => const Color(0xFFFFFFFF);
  Color get chipSelectedBg =>
      isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
  Color get chipSelectedFg =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E3A8A);
  Color get chipBg =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get chipFg =>
      isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get liveBadgeBg =>
      isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
  Color get liveBadgeFg =>
      isDark ? const Color(0xFFDCFCE7) : const Color(0xFF14532D);
  Color get errorBg =>
      isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
  Color get errorBorder =>
      isDark ? const Color(0xFFEF4444) : const Color(0xFFB91C1C);
  Color get errorText =>
      isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D);
  Color get noticeBg =>
      isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE);
  Color get noticeBorder =>
      isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1);
  Color get noticeText =>
      isDark ? const Color(0xFFE0F2FE) : const Color(0xFF0C4A6E);
}

class _HeaderSummaryCard extends StatelessWidget {
  const _HeaderSummaryCard({
    required this.state,
    required this.palette,
    required this.onRefresh,
  });

  final ExternalAiWebhookState state;
  final _WebhookPalette palette;
  final VoidCallback onRefresh;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '外部 AI Webhook レシーバー',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.titleText,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                key: const ValueKey<String>('webhook_realtime_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: state.realtimeActive
                      ? palette.liveBadgeBg
                      : palette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  state.realtimeActive ? 'Realtime 購読中' : '待機中',
                  style: TextStyle(
                    color: state.realtimeActive
                        ? palette.liveBadgeFg
                        : palette.mutedText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'n8n / Zapier / アナリティクスからの外部 Webhook を API キーまたは JWT で認証し、受信ペイロードを即時反映します。',
            style: TextStyle(color: palette.mutedText, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _MetricBadge(
                label: '受信イベント',
                value: '${state.events.length}件',
                palette: palette,
              ),
              _MetricBadge(
                label: '有効 API キー',
                value: '${state.activeKeyCount}件',
                palette: palette,
              ),
              OutlinedButton.icon(
                key: const ValueKey<String>('webhook_refresh_button'),
                onPressed: state.isLoading ? null : onRefresh,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: palette.titleText,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('最新読込'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final _WebhookPalette palette;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(color: palette.mutedText, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: palette.titleText,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(width: 8),
            TextButton(
              key: actionKey,
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: textColor,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaintextKeyRevealCard extends StatelessWidget {
  const _PlaintextKeyRevealCard({
    required this.plaintextKey,
    required this.palette,
    required this.onDismiss,
  });

  final String plaintextKey;
  final _WebhookPalette palette;
  final VoidCallback onDismiss;

  @override
  Widget build(final BuildContext context) {
    return Container(
      key: const ValueKey<String>('webhook_created_key_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.noticeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.noticeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '新しい X-Webhook-Api-Key（一度のみ表示）',
            style: TextStyle(
              color: palette.noticeText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            plaintextKey,
            key: const ValueKey<String>('webhook_created_plaintext_key'),
            style: TextStyle(
              color: palette.noticeText,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('webhook_dismiss_key_button'),
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: palette.noticeText,
              ),
              child: const Text('閉じる'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeysCard extends StatelessWidget {
  const _ApiKeysCard({
    required this.state,
    required this.palette,
    required this.keyLabelController,
    required this.onCreateKey,
    required this.onRevokeKey,
  });

  final ExternalAiWebhookState state;
  final _WebhookPalette palette;
  final TextEditingController keyLabelController;
  final VoidCallback onCreateKey;
  final ValueChanged<String> onRevokeKey;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Webhook API キー管理 (SHA-256 ハッシュ検証)',
            style: TextStyle(
              color: palette.titleText,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('webhook_key_label_field'),
            controller: keyLabelController,
            decoration: const InputDecoration(
              labelText: 'APIキー表示名 (例: n8n YouTube Flow)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey<String>('webhook_create_key_button'),
            onPressed: state.isSubmitting ? null : onCreateKey,
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: palette.accentBg,
              foregroundColor: palette.accentFg,
            ),
            icon: const Icon(Icons.vpn_key),
            label: const Text('APIキーを発行'),
          ),
          if (state.keys.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final keyItem in state.keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  key: ValueKey<String>('webhook_key_${keyItem.id}'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              keyItem.label,
                              style: TextStyle(
                                color: palette.titleText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${keyItem.keyPrefix}... • ${keyItem.isActive ? '有効' : '無効化済み'}',
                              style: TextStyle(
                                color: palette.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (keyItem.isActive)
                        OutlinedButton(
                          key: ValueKey<String>('webhook_revoke_${keyItem.id}'),
                          onPressed: state.isSubmitting
                              ? null
                              : () => onRevokeKey(keyItem.id),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: palette.titleText,
                          ),
                          child: const Text('無効化'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _WebhookTesterCard extends StatelessWidget {
  const _WebhookTesterCard({
    required this.state,
    required this.palette,
    required this.selectedTestSource,
    required this.eventTypeController,
    required this.sampleNoteController,
    required this.onSelectTestSource,
    required this.onSendDryRun,
    required this.onSendLiveTest,
  });

  final ExternalAiWebhookState state;
  final _WebhookPalette palette;
  final ExternalWebhookSourceTool selectedTestSource;
  final TextEditingController eventTypeController;
  final TextEditingController sampleNoteController;
  final ValueChanged<ExternalWebhookSourceTool> onSelectTestSource;
  final VoidCallback onSendDryRun;
  final VoidCallback onSendLiveTest;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Webhook エンドポイント疎通テスト',
            style: TextStyle(
              color: palette.titleText,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tool in ExternalWebhookSourceTool.values)
                ChoiceChip(
                  key:
                      ValueKey<String>('webhook_test_source_${tool.wireValue}'),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selected: selectedTestSource == tool,
                  backgroundColor: palette.chipBg,
                  selectedColor: palette.chipSelectedBg,
                  labelStyle: TextStyle(
                    color: selectedTestSource == tool
                        ? palette.chipSelectedFg
                        : palette.chipFg,
                  ),
                  onSelected: (final bool _) => onSelectTestSource(tool),
                  label: Text(tool.displayLabel),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('webhook_event_type_field'),
            controller: eventTypeController,
            decoration: const InputDecoration(
              labelText: 'イベント種別 (例: youtube.metrics.synced)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('webhook_sample_note_field'),
            controller: sampleNoteController,
            decoration: const InputDecoration(
              labelText: 'テストペイロードメモ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                key: const ValueKey<String>('webhook_dry_run_button'),
                onPressed: state.isSubmitting ? null : onSendDryRun,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: palette.titleText,
                ),
                child: const Text('ドライラン検証'),
              ),
              FilledButton(
                key: const ValueKey<String>('webhook_live_send_button'),
                onPressed: state.isSubmitting ? null : onSendLiveTest,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: palette.accentBg,
                  foregroundColor: palette.accentFg,
                ),
                child: const Text('Webhook 送信'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RealtimeEventsSection extends StatelessWidget {
  const _RealtimeEventsSection({
    required this.events,
    required this.selectedSourceFilter,
    required this.isLoading,
    required this.palette,
    required this.onSelectSourceFilter,
  });

  final List<ExternalAiWebhookEvent> events;
  final ExternalWebhookSourceTool? selectedSourceFilter;
  final bool isLoading;
  final _WebhookPalette palette;
  final ValueChanged<ExternalWebhookSourceTool?> onSelectSourceFilter;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'リアルタイム受信イベント履歴',
            style: TextStyle(
              color: palette.titleText,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const ValueKey<String>('webhook_filter_all'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                selected: selectedSourceFilter == null,
                backgroundColor: palette.chipBg,
                selectedColor: palette.chipSelectedBg,
                labelStyle: TextStyle(
                  color: selectedSourceFilter == null
                      ? palette.chipSelectedFg
                      : palette.chipFg,
                ),
                onSelected: (final bool _) => onSelectSourceFilter(null),
                label: const Text('すべて'),
              ),
              for (final tool in ExternalWebhookSourceTool.values)
                ChoiceChip(
                  key: ValueKey<String>('webhook_filter_${tool.wireValue}'),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  selected: selectedSourceFilter == tool,
                  backgroundColor: palette.chipBg,
                  selectedColor: palette.chipSelectedBg,
                  labelStyle: TextStyle(
                    color: selectedSourceFilter == tool
                        ? palette.chipSelectedFg
                        : palette.chipFg,
                  ),
                  onSelected: (final bool _) => onSelectSourceFilter(tool),
                  label: Text(tool.displayLabel),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading && events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '対象ソースの Webhook 受信履歴はまだありません。',
                key: const ValueKey<String>('webhook_empty_state'),
                style: TextStyle(color: palette.mutedText, fontSize: 13),
              ),
            )
          else
            for (final item in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  key: ValueKey<String>('webhook_event_${item.id}'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${item.sourceTool.displayLabel} • ${item.eventType}',
                        style: TextStyle(
                          color: palette.titleText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '認証: ${item.authMethod.displayLabel} / 状態: ${item.processingStatus.displayLabel}',
                        style: TextStyle(
                          color: palette.mutedText,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.payloadSummary,
                        style: TextStyle(
                          color: palette.mutedText,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
