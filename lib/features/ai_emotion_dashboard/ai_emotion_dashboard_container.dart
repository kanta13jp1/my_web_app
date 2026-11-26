import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/ai_emotion_controller.dart';
import 'data/supabase_ai_emotion_repository.dart';
import 'domain/ai_emotion_models.dart';
import 'presentation/ai_emotion_dashboard_view.dart';

/// Dependency-injection container for AI functional emotion dashboard (#2764).
class AiEmotionDashboardContainer extends StatefulWidget {
  const AiEmotionDashboardContainer({
    super.key,
    this.repository,
    this.controller,
    this.supabaseClient,
    this.autoLoad = true,
  });

  final AiEmotionRepository? repository;
  final AiEmotionController? controller;
  final SupabaseClient? supabaseClient;
  final bool autoLoad;

  @override
  State<AiEmotionDashboardContainer> createState() =>
      _AiEmotionDashboardContainerState();
}

class _AiEmotionDashboardContainerState
    extends State<AiEmotionDashboardContainer> {
  late final AiEmotionController _controller;
  late final bool _ownsController;
  final TextEditingController _responseTextController = TextEditingController();
  final TextEditingController _modelController = TextEditingController(
    text: 'gemini-2.5-flash',
  );
  final TextEditingController _thresholdController = TextEditingController(
    text: '0.70',
  );

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiEmotionController(
          repository: widget.repository ??
              SupabaseAiEmotionRepository(client: widget.supabaseClient),
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
    _responseTextController.dispose();
    _modelController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _handleClassifyAndLog() {
    _controller.classifyAndLog(
      responseText: _responseTextController.text,
      model: _modelController.text,
      thresholdText: _thresholdController.text,
    );
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return AiEmotionDashboardView(
          state: _controller.state,
          responseTextController: _responseTextController,
          modelController: _modelController,
          thresholdController: _thresholdController,
          onRefresh: _controller.loadDashboard,
          onSeedDefaults: _controller.seedDefaults,
          onSelectTone: _controller.selectToneFilter,
          onClassifyAndLog: _handleClassifyAndLog,
        );
      },
    );
  }
}
