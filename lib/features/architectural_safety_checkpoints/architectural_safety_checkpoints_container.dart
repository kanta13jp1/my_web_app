import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/architectural_safety_checkpoint_controller.dart';
import 'data/supabase_architectural_safety_checkpoint_repository.dart';
import 'domain/architectural_safety_checkpoint_models.dart';
import 'presentation/architectural_safety_checkpoint_view.dart';

/// Architectural Safety Checkpoints 機能の DI コンテナ (#2712)。
class ArchitecturalSafetyCheckpointsContainer extends StatefulWidget {
  const ArchitecturalSafetyCheckpointsContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final ArchitecturalSafetyCheckpointController? controller;
  final ArchitecturalSafetyCheckpointRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<ArchitecturalSafetyCheckpointsContainer> createState() =>
      _ArchitecturalSafetyCheckpointsContainerState();
}

class _ArchitecturalSafetyCheckpointsContainerState
    extends State<ArchitecturalSafetyCheckpointsContainer> {
  ArchitecturalSafetyCheckpointController? _ownedController;

  ArchitecturalSafetyCheckpointController get _activeController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      final ArchitecturalSafetyCheckpointRepository repo = widget.repository ??
          SupabaseArchitecturalSafetyCheckpointRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = ArchitecturalSafetyCheckpointController(
        repository: repo,
      );
    }
    if (widget.autoLoad) {
      _activeController.loadCheckpoints();
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArchitecturalSafetyCheckpointView(controller: _activeController);
  }
}
