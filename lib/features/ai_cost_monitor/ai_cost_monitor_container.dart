import 'package:flutter/material.dart';

import 'application/ai_cost_monitor_controller.dart';
import 'data/supabase_ai_cost_repository.dart';
import 'domain/ai_cost_monitor_models.dart';
import 'presentation/ai_cost_monitor_view.dart';

class AiCostMonitorContainer extends StatefulWidget {
  const AiCostMonitorContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final AiCostMonitorRepository? repository;
  final AiCostMonitorController? controller;

  @override
  State<AiCostMonitorContainer> createState() => _AiCostMonitorContainerState();
}

class _AiCostMonitorContainerState extends State<AiCostMonitorContainer> {
  late final AiCostMonitorController _controller;
  late final bool _ownsController;
  final TextEditingController _thresholdController =
      TextEditingController(text: '10.0');
  final TextEditingController _inputUnitsController =
      TextEditingController(text: '100000');
  final TextEditingController _outputUnitsController =
      TextEditingController(text: '25000');

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiCostMonitorController(
          repository: widget.repository ?? SupabaseAiCostRepository(),
        );
    _controller.addListener(_onControllerChanged);
    _controller.loadDashboard();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _thresholdController.dispose();
    _inputUnitsController.dispose();
    _outputUnitsController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleRecordUsage() {
    final inUnits = int.tryParse(_inputUnitsController.text.trim()) ?? -1;
    final outUnits = int.tryParse(_outputUnitsController.text.trim()) ?? -1;
    _controller.recordSampleUsage(
      model: _controller.state.draftModel,
      inputUnits: inUnits,
      outputUnits: outUnits,
    );
  }

  void _handleCheckBudget() {
    final threshold =
        double.tryParse(_thresholdController.text.trim()) ?? double.nan;
    _controller.checkBudgetThreshold(threshold);
  }

  @override
  Widget build(final BuildContext context) {
    return AiCostMonitorView(
      state: _controller.state,
      thresholdController: _thresholdController,
      inputUnitsController: _inputUnitsController,
      outputUnitsController: _outputUnitsController,
      onRefresh: () => _controller.loadDashboard(),
      onProviderFilterChanged: _controller.setProviderFilter,
      onDraftModelChanged: _controller.setDraftModel,
      onRecordUsage: _handleRecordUsage,
      onCheckBudget: _handleCheckBudget,
    );
  }
}
