import 'package:flutter/material.dart';

import 'application/did_mcp_proxy_controller.dart';
import 'data/supabase_did_mcp_proxy_repository.dart';
import 'presentation/did_mcp_proxy_view.dart';

/// D-ID MCP エージェント連携プロキシ Feature の公開 Container ウィジェット (#2662).
class DidMcpProxyContainer extends StatefulWidget {
  const DidMcpProxyContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final DidMcpProxyRepository? repository;
  final DidMcpProxyController? controller;
  final bool autoLoad;

  @override
  State<DidMcpProxyContainer> createState() => _DidMcpProxyContainerState();
}

class _DidMcpProxyContainerState extends State<DidMcpProxyContainer> {
  late final DidMcpProxyController _controller;
  late final bool _ownsController;
  final TextEditingController _promptController = TextEditingController(
    text: '自分株式会社の新規ユーザー向け挨拶アバター動画台本を 15 秒で作成する',
  );
  final TextEditingController _targetIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        DidMcpProxyController(
          repository: widget.repository ?? SupabaseDidMcpProxyRepository(),
        );
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((final Duration _) {
        if (mounted) {
          _controller.loadDashboard();
        }
      });
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _targetIdController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return DidMcpProxyView(
          state: _controller.state,
          promptController: _promptController,
          targetIdController: _targetIdController,
          onRefresh: _controller.loadDashboard,
          onToolChanged: _controller.selectTool,
          onDryRunChanged: _controller.setDryRunOnly,
          onExecute: () => _controller.runToolCall(
            prompt: _promptController.text,
            targetId: _targetIdController.text,
          ),
          onAcknowledgeAlert: _controller.acknowledgeAlert,
        );
      },
    );
  }
}
