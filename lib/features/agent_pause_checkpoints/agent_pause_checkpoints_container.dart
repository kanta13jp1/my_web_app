import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/agent_pause_checkpoint_controller.dart';
import 'data/supabase_agent_pause_checkpoint_repository.dart';
import 'domain/agent_pause_checkpoint_models.dart';
import 'presentation/agent_pause_checkpoint_view.dart';

/// エージェントチェックポイント機能の DI コンテナ (#2603 / #2616)。
class AgentPauseCheckpointsContainer extends StatefulWidget {
  const AgentPauseCheckpointsContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final AgentPauseCheckpointController? controller;
  final AgentPauseCheckpointRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<AgentPauseCheckpointsContainer> createState() =>
      _AgentPauseCheckpointsContainerState();
}

class _AgentPauseCheckpointsContainerState
    extends State<AgentPauseCheckpointsContainer> {
  AgentPauseCheckpointController? _ownedController;

  AgentPauseCheckpointController get _activeController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      final AgentPauseCheckpointRepository repo = widget.repository ??
          SupabaseAgentPauseCheckpointRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = AgentPauseCheckpointController(repository: repo);
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
    return AgentPauseCheckpointView(controller: _activeController);
  }
}
