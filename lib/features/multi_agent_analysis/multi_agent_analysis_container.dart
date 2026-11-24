import 'package:flutter/material.dart';

import 'application/multi_agent_analysis_controller.dart';
import 'data/supabase_multi_agent_analysis_repository.dart';
import 'domain/multi_agent_analysis_models.dart';
import 'presentation/multi_agent_analysis_view.dart';

/// Controller と View・入力コントローラを接続しライフサイクルを管理する Container (#2641).
class MultiAgentAnalysisContainer extends StatefulWidget {
  const MultiAgentAnalysisContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final MultiAgentAnalysisRepository? repository;
  final MultiAgentAnalysisController? controller;

  @override
  State<MultiAgentAnalysisContainer> createState() =>
      _MultiAgentAnalysisContainerState();
}

class _MultiAgentAnalysisContainerState
    extends State<MultiAgentAnalysisContainer> {
  late MultiAgentAnalysisController _controller;
  late bool _ownsController;
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _reviewNoteController = TextEditingController();

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
        MultiAgentAnalysisController(
          repository:
              widget.repository ?? SupabaseMultiAgentAnalysisRepository(),
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    await _controller.loadRuns();
  }

  @override
  void didUpdateWidget(covariant MultiAgentAnalysisContainer oldWidget) {
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
    _topicController.dispose();
    _reviewNoteController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleRunAnalysis() {
    _controller.runNewAnalysis(topic: _topicController.text);
  }

  void _handleSubmitReview(HumanReviewStatus status) {
    _controller.submitReview(
      status: status,
      note: _reviewNoteController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return MultiAgentAnalysisView(
          state: _controller.state,
          topicController: _topicController,
          reviewNoteController: _reviewNoteController,
          onRetryLoad: _loadInitial,
          onRunAnalysis: _handleRunAnalysis,
          onSelectRun: _controller.selectRun,
          onSelectStageFilter: _controller.selectStageFilter,
          onSubmitReview: _handleSubmitReview,
        );
      },
    );
  }
}
