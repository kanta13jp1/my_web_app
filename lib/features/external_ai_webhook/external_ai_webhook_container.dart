import 'package:flutter/material.dart';

import 'application/external_ai_webhook_controller.dart';
import 'data/supabase_external_ai_webhook_repository.dart';
import 'domain/external_ai_webhook_models.dart';
import 'presentation/external_ai_webhook_view.dart';

/// 外部 AI Webhook レシーバー Feature の公開 Container (#2663).
class ExternalAiWebhookContainer extends StatefulWidget {
  const ExternalAiWebhookContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final ExternalAiWebhookRepository? repository;
  final ExternalAiWebhookController? controller;
  final bool autoLoad;

  @override
  State<ExternalAiWebhookContainer> createState() =>
      _ExternalAiWebhookContainerState();
}

class _ExternalAiWebhookContainerState
    extends State<ExternalAiWebhookContainer> {
  late final ExternalAiWebhookController _controller;
  late final bool _ownsController;
  ExternalWebhookSourceTool _selectedTestSource = ExternalWebhookSourceTool.n8n;
  final TextEditingController _keyLabelController = TextEditingController();
  final TextEditingController _eventTypeController = TextEditingController(
    text: 'youtube.metrics.synced',
  );
  final TextEditingController _sampleNoteController = TextEditingController(
    text: 'automation-sync',
  );

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ExternalAiWebhookController(
          repository:
              widget.repository ?? SupabaseExternalAiWebhookRepository(),
        );
    if (widget.autoLoad) {
      _controller.loadDashboard();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _keyLabelController.dispose();
    _eventTypeController.dispose();
    _sampleNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return ExternalAiWebhookView(
          state: _controller.state,
          selectedTestSource: _selectedTestSource,
          keyLabelController: _keyLabelController,
          eventTypeController: _eventTypeController,
          sampleNoteController: _sampleNoteController,
          onRetryLoad: () {
            _controller.loadDashboard();
          },
          onSelectSourceFilter: (final ExternalWebhookSourceTool? source) {
            _controller.selectSourceFilter(source);
          },
          onSelectTestSource: (final ExternalWebhookSourceTool source) {
            setState(() {
              _selectedTestSource = source;
            });
          },
          onCreateKey: () {
            _controller.createWebhookKey(label: _keyLabelController.text);
            _keyLabelController.clear();
          },
          onRevokeKey: (final String keyId) {
            _controller.revokeWebhookKey(keyId);
          },
          onDismissPlaintextKey: () {
            _controller.dismissCreatedPlaintextKey();
          },
          onSendDryRun: () {
            _controller.sendWebhookTest(
              sourceTool: _selectedTestSource,
              eventType: _eventTypeController.text,
              sampleNote: _sampleNoteController.text,
              dryRun: true,
            );
          },
          onSendLiveTest: () {
            _controller.sendWebhookTest(
              sourceTool: _selectedTestSource,
              eventType: _eventTypeController.text,
              sampleNote: _sampleNoteController.text,
              dryRun: false,
            );
          },
        );
      },
    );
  }
}
