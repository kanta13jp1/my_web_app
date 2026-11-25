import 'package:flutter/material.dart';

import 'application/ai_output_validation_controller.dart';
import 'data/supabase_ai_output_validation_repository.dart';
import 'domain/ai_output_validation_models.dart';
import 'presentation/ai_output_validation_view.dart';

/// 決定的 AI 出力検証 Feature の公開 Container ウィジェット (#2657).
class AiOutputValidationContainer extends StatefulWidget {
  const AiOutputValidationContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final AiOutputValidationRepository? repository;
  final AiOutputValidationController? controller;
  final bool autoLoad;

  @override
  State<AiOutputValidationContainer> createState() =>
      _AiOutputValidationContainerState();
}

class _AiOutputValidationContainerState
    extends State<AiOutputValidationContainer> {
  late final AiOutputValidationController _controller;
  late final bool _ownsController;
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final TextEditingController _requiredFieldsController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AiOutputValidationController(
          repository:
              widget.repository ?? SupabaseAiOutputValidationRepository(),
        );
    if (widget.autoLoad) {
      _controller.loadLogs();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _promptController.dispose();
    _outputController.dispose();
    _requiredFieldsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return AiOutputValidationView(
          state: _controller.state,
          promptController: _promptController,
          outputController: _outputController,
          requiredFieldsController: _requiredFieldsController,
          searchController: _searchController,
          onRetryLoad: () {
            _controller.loadLogs();
          },
          onSelectContract: _controller.setContract,
          onSelectDecisionFilter: _controller.setDecisionFilter,
          onSearchChanged: _controller.setSearchQuery,
          onSubmitSimulation: () {
            _controller.simulateAndRecord(
              prompt: _promptController.text,
              candidateOutput: _outputController.text,
              requiredFieldsCsv: _requiredFieldsController.text,
            );
          },
        );
      },
    );
  }
}
