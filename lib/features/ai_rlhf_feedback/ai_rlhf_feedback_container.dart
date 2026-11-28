import 'package:flutter/material.dart';

import 'application/ai_rlhf_feedback_controller.dart';
import 'data/supabase_ai_rlhf_feedback_repository.dart';
import 'domain/ai_rlhf_feedback_models.dart';
import 'presentation/ai_rlhf_feedback_view.dart';

/// AiRlhfFeedbackController と View・フォームコントローラを接続する Container (#2659).
class AiRlhfFeedbackContainer extends StatefulWidget {
  const AiRlhfFeedbackContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final AiRlhfFeedbackRepository? repository;
  final AiRlhfFeedbackController? controller;

  @override
  State<AiRlhfFeedbackContainer> createState() =>
      _AiRlhfFeedbackContainerState();
}

class _AiRlhfFeedbackContainerState extends State<AiRlhfFeedbackContainer> {
  late AiRlhfFeedbackController _controller;
  late bool _ownsController;
  final TextEditingController _actionController =
      TextEditingController(text: 'ai_assistant');
  final TextEditingController _modelController =
      TextEditingController(text: 'gemini-2.5-flash');
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initController();
    Future<void>.microtask(_loadInitial);
  }

  void _initController() {
    final provided = widget.controller;
    _ownsController = provided == null;
    _controller = provided ??
        AiRlhfFeedbackController(
          repository: widget.repository ?? SupabaseAiRlhfFeedbackRepository(),
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    await _controller.loadFeedback();
  }

  @override
  void didUpdateWidget(covariant AiRlhfFeedbackContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.repository != oldWidget.repository) {
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      Future<void>.microtask(_loadInitial);
    }
  }

  @override
  void dispose() {
    _actionController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    _outputController.dispose();
    _commentController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSubmit() {
    _controller.submitFeedback(
      actionName: _actionController.text,
      modelId: _modelController.text,
      promptText: _promptController.text,
      aiOutput: _outputController.text,
      userComment: _commentController.text,
    );
  }

  void _handleDispatch(String feedbackId) {
    _controller.dispatchPendingIssue(feedbackId: feedbackId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return AiRlhfFeedbackView(
          state: _controller.state,
          actionController: _actionController,
          modelController: _modelController,
          promptController: _promptController,
          outputController: _outputController,
          commentController: _commentController,
          onSelectRating: _controller.selectRating,
          onRetryLoad: _loadInitial,
          onSubmitFeedback: _handleSubmit,
          onDispatchIssue: _handleDispatch,
        );
      },
    );
  }
}
