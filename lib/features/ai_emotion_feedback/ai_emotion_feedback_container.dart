import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/ai_emotion_feedback_controller.dart';
import 'data/supabase_ai_emotion_feedback_repository.dart';
import 'domain/ai_emotion_feedback_models.dart';
import 'presentation/ai_emotion_feedback_view.dart';

/// DI container for AI functional emotion feedback & NotebookLM export (#2766).
class AiEmotionFeedbackContainer extends StatefulWidget {
  const AiEmotionFeedbackContainer({
    super.key,
    this.repository,
    this.controller,
    this.supabaseClient,
    this.autoLoad = true,
  });

  final AiEmotionFeedbackRepository? repository;
  final AiEmotionFeedbackController? controller;
  final SupabaseClient? supabaseClient;
  final bool autoLoad;

  @override
  State<AiEmotionFeedbackContainer> createState() =>
      _AiEmotionFeedbackContainerState();
}

class _AiEmotionFeedbackContainerState
    extends State<AiEmotionFeedbackContainer> {
  late final AiEmotionFeedbackRepository _repository;
  late final AiEmotionFeedbackController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        SupabaseAiEmotionFeedbackRepository(client: widget.supabaseClient);
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiEmotionFeedbackController(repository: _repository);
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((final Duration _) {
        if (mounted) {
          _controller.loadFeedbacks();
        }
      });
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext _, final Widget? __) {
        return AiEmotionFeedbackView(
          state: _controller.state,
          onRefresh: () => _controller.loadFeedbacks(),
          onSeedDefaults: () => _controller.seedDefaults(),
          onSubmitFeedback: ({
            required final EmotionFeedbackCategory category,
            required final EmotionFeedbackSeverity severity,
            required final String aiSnippet,
            required final String userComment,
            required final String modelRef,
            required final String sessionRef,
          }) {
            return _controller.submitFeedback(
              category: category,
              severity: severity,
              aiSnippet: aiSnippet,
              userComment: userComment,
              modelRef: modelRef,
              sessionRef: sessionRef,
            );
          },
          onSelectCategoryFilter: _controller.selectCategoryFilter,
          onExportIntake: () => _controller.exportNotebookLmIntake(),
          onCopyNotice: _controller.setStatusNotice,
        );
      },
    );
  }
}
