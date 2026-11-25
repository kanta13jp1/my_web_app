import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/agent_sandbox_controller.dart';
import 'data/supabase_agent_sandbox_repository.dart';
import 'domain/agent_sandbox_models.dart';
import 'presentation/agent_sandbox_monitor_view.dart';

/// エージェント隔離サンドボックス・セキュリティ監視 DI コンテナ (#2722)。
class AgentSandboxMonitorContainer extends StatefulWidget {
  const AgentSandboxMonitorContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final AgentSandboxController? controller;
  final AgentSandboxRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<AgentSandboxMonitorContainer> createState() =>
      _AgentSandboxMonitorContainerState();
}

class _AgentSandboxMonitorContainerState
    extends State<AgentSandboxMonitorContainer> {
  AgentSandboxController? _ownedController;

  AgentSandboxController get _activeController =>
      widget.controller ?? _ownedController!;

  void _initOwnedController() {
    if (widget.controller == null && _ownedController == null) {
      final AgentSandboxRepository repo = widget.repository ??
          SupabaseAgentSandboxRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = AgentSandboxController(repository: repo);
    }
  }

  void _releaseOwnedController() {
    _ownedController?.dispose();
    _ownedController = null;
  }

  @override
  void initState() {
    super.initState();
    _initOwnedController();
    if (widget.autoLoad) {
      _activeController.loadSnapshot();
    }
  }

  @override
  void didUpdateWidget(covariant AgentSandboxMonitorContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.repository != widget.repository ||
        oldWidget.clientResolver != widget.clientResolver) {
      _releaseOwnedController();
      _initOwnedController();
      if (widget.autoLoad) {
        _activeController.loadSnapshot();
      }
    }
  }

  @override
  void dispose() {
    _releaseOwnedController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AgentSandboxMonitorView(controller: _activeController);
  }
}
