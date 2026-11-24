import 'package:flutter/material.dart';

import 'application/ai_reasoning_depth_controller.dart';
import 'data/supabase_ai_reasoning_depth_repository.dart';
import 'domain/ai_reasoning_depth_models.dart';
import 'presentation/ai_reasoning_depth_view.dart';

/// Controller と View・入力コントローラを接続しライフサイクルを管理する Container (#2654).
class AiReasoningDepthContainer extends StatefulWidget {
  const AiReasoningDepthContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final AiReasoningDepthRepository? repository;
  final AiReasoningDepthController? controller;

  @override
  State<AiReasoningDepthContainer> createState() =>
      _AiReasoningDepthContainerState();
}

class _AiReasoningDepthContainerState extends State<AiReasoningDepthContainer> {
  late AiReasoningDepthController _controller;
  late bool _ownsController;
  final TextEditingController _promptController = TextEditingController();

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
        AiReasoningDepthController(
          repository: widget.repository ?? SupabaseAiReasoningDepthRepository(),
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    await _controller.loadJobs();
  }

  @override
  void didUpdateWidget(covariant AiReasoningDepthContainer oldWidget) {
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
    _promptController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSubmitJob() {
    _controller.submitJob(promptSummary: _promptController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return AiReasoningDepthView(
          state: _controller.state,
          promptController: _promptController,
          onSelectMode: _controller.selectMode,
          onSelectJob: _controller.selectJob,
          onRetryLoad: _loadInitial,
          onSubmitJob: _handleSubmitJob,
          onPollSelectedJob: _controller.pollSelectedJob,
          onCancelSelectedJob: _controller.cancelSelectedJob,
        );
      },
    );
  }
}
