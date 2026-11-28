import 'package:flutter/material.dart';

import 'application/ai_compute_cost_monitor_controller.dart';
import 'data/supabase_ai_compute_cost_monitor_repository.dart';
import 'domain/ai_compute_cost_monitor_models.dart';
import 'presentation/ai_compute_cost_monitor_view.dart';

/// 計算規模・GPU コスト監視 Feature の公開 Container ウィジェット (#2658).
class AiComputeCostMonitorContainer extends StatefulWidget {
  const AiComputeCostMonitorContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final AiComputeCostMonitorRepository? repository;
  final AiComputeCostMonitorController? controller;
  final bool autoLoad;

  @override
  State<AiComputeCostMonitorContainer> createState() =>
      _AiComputeCostMonitorContainerState();
}

class _AiComputeCostMonitorContainerState
    extends State<AiComputeCostMonitorContainer> {
  late final AiComputeCostMonitorController _controller;
  late final bool _ownsController;
  GpuComputeProfile _selectedInputProfile = GpuComputeProfile.l4Inference;
  final TextEditingController _toolController =
      TextEditingController(text: 'ai-hub');
  final TextEditingController _modelController =
      TextEditingController(text: 'gemini-2.5-flash');
  final TextEditingController _inputTokensController =
      TextEditingController(text: '1200');
  final TextEditingController _outputTokensController =
      TextEditingController(text: '450');
  final TextEditingController _latencyMsController =
      TextEditingController(text: '640');
  final TextEditingController _dailyThresholdController =
      TextEditingController(text: '50.0');
  final TextEditingController _monthlyThresholdController =
      TextEditingController(text: '500.0');
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiComputeCostMonitorController(
          repository:
              widget.repository ?? SupabaseAiComputeCostMonitorRepository(),
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
    _toolController.dispose();
    _modelController.dispose();
    _inputTokensController.dispose();
    _outputTokensController.dispose();
    _latencyMsController.dispose();
    _dailyThresholdController.dispose();
    _monthlyThresholdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return AiComputeCostMonitorView(
          state: _controller.state,
          selectedInputProfile: _selectedInputProfile,
          toolController: _toolController,
          modelController: _modelController,
          inputTokensController: _inputTokensController,
          outputTokensController: _outputTokensController,
          latencyMsController: _latencyMsController,
          dailyThresholdController: _dailyThresholdController,
          monthlyThresholdController: _monthlyThresholdController,
          searchController: _searchController,
          onRetryLoad: () {
            _controller.loadDashboard();
          },
          onSelectPeriod: _controller.setPeriod,
          onSelectProfileFilter: _controller.setProfileFilter,
          onSelectInputProfile: (GpuComputeProfile profile) {
            setState(() {
              _selectedInputProfile = profile;
            });
          },
          onSearchChanged: _controller.setSearchQuery,
          onSubmitInvocation: () {
            final inTok = int.tryParse(_inputTokensController.text.trim()) ?? 0;
            final outTok =
                int.tryParse(_outputTokensController.text.trim()) ?? 0;
            final latMs = int.tryParse(_latencyMsController.text.trim()) ?? 0;
            _controller.recordInvocation(
              toolName: _toolController.text,
              gpuProfile: _selectedInputProfile,
              modelId: _modelController.text,
              inputTokens: inTok,
              outputTokens: outTok,
              apiRequestCount: 1,
              latencyMs: latMs,
            );
          },
          onUpdateThresholds: () {
            final daily =
                double.tryParse(_dailyThresholdController.text.trim()) ?? -1.0;
            final monthly =
                double.tryParse(_monthlyThresholdController.text.trim()) ??
                    -1.0;
            _controller.updateThresholds(
              dailyThresholdUsd: daily,
              monthlyThresholdUsd: monthly,
            );
          },
        );
      },
    );
  }
}
