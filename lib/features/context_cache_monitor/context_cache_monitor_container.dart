import 'package:flutter/material.dart';

import 'application/context_cache_monitor_controller.dart';
import 'data/supabase_context_cache_monitor_repository.dart';
import 'domain/context_cache_monitor_models.dart';
import 'presentation/context_cache_monitor_view.dart';

/// ContextCacheMonitorController と View・入力コントローラを接続する Container (#2656).
class ContextCacheMonitorContainer extends StatefulWidget {
  const ContextCacheMonitorContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final ContextCacheMonitorRepository? repository;
  final ContextCacheMonitorController? controller;

  @override
  State<ContextCacheMonitorContainer> createState() =>
      _ContextCacheMonitorContainerState();
}

class _ContextCacheMonitorContainerState
    extends State<ContextCacheMonitorContainer> {
  late ContextCacheMonitorController _controller;
  late bool _ownsController;
  final TextEditingController _userFilterController = TextEditingController();
  final TextEditingController _workflowInputController =
      TextEditingController(text: 'multi-turn-code-review');

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
        ContextCacheMonitorController(
          repository:
              widget.repository ?? SupabaseContextCacheMonitorRepository(),
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    await _controller.loadMetrics();
  }

  @override
  void didUpdateWidget(covariant ContextCacheMonitorContainer oldWidget) {
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
    _userFilterController.dispose();
    _workflowInputController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleRecordSimulatedRequest() {
    _controller.recordSimulatedRequest(
      workflowKey: _workflowInputController.text,
    );
  }

  void _handleToggleHit(bool value) {
    _controller.toggleSimulateCacheHit(value: value);
  }

  void _handleEvaluateRecache() {
    _controller.evaluateLongTaskRecache(
      workflowKey: _workflowInputController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return ContextCacheMonitorView(
          state: _controller.state,
          userFilterController: _userFilterController,
          workflowInputController: _workflowInputController,
          onUserFilterChanged: _controller.setUserFilter,
          onWorkflowFilterSelected: _controller.setWorkflowFilter,
          onModelSelected: _controller.selectModel,
          onToggleSimulateCacheHit: _handleToggleHit,
          onSelectCacheTtl: _controller.selectCacheTtl,
          onEvaluateRecache: _handleEvaluateRecache,
          onRecordSimulatedRequest: _handleRecordSimulatedRequest,
          onRetryLoad: _loadInitial,
        );
      },
    );
  }
}
