import 'package:flutter/material.dart';

import 'application/llm_healthcheck_controller.dart';
import 'data/supabase_llm_healthcheck_repository.dart';
import 'domain/llm_healthcheck_models.dart';
import 'presentation/llm_healthcheck_view.dart';

class LlmHealthcheckContainer extends StatefulWidget {
  const LlmHealthcheckContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final LlmHealthcheckRepository? repository;
  final LlmHealthcheckController? controller;

  @override
  State<LlmHealthcheckContainer> createState() =>
      _LlmHealthcheckContainerState();
}

class _LlmHealthcheckContainerState extends State<LlmHealthcheckContainer> {
  late final LlmHealthcheckController _controller;
  late final bool _ownsController;
  final TextEditingController _providerNameController = TextEditingController();
  final TextEditingController _endpointUrlController = TextEditingController();
  final TextEditingController _timeoutMsController =
      TextEditingController(text: '5000');
  final TextEditingController _alertChannelController =
      TextEditingController(text: 'ops-alerts');

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        LlmHealthcheckController(
          repository: widget.repository ?? SupabaseLlmHealthcheckRepository(),
        );
    _controller.addListener(_onChanged);
    _controller.loadDashboard();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _providerNameController.dispose();
    _endpointUrlController.dispose();
    _timeoutMsController.dispose();
    _alertChannelController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleSave() {
    final timeoutMs = int.tryParse(_timeoutMsController.text.trim()) ?? 5000;
    _controller.saveEndpoint(
      providerName: _providerNameController.text,
      endpointUrl: _endpointUrlController.text,
      timeoutMs: timeoutMs,
      alertChannel: _alertChannelController.text,
    );
  }

  @override
  Widget build(final BuildContext context) {
    return LlmHealthcheckView(
      state: _controller.state,
      providerNameController: _providerNameController,
      endpointUrlController: _endpointUrlController,
      timeoutMsController: _timeoutMsController,
      alertChannelController: _alertChannelController,
      onRefresh: () => _controller.loadDashboard(),
      onSeedDefaults: () => _controller.seedDefaults(),
      onDraftMethodChanged: _controller.setDraftMethod,
      onSaveEndpoint: _handleSave,
      onDeleteEndpoint: _controller.deleteEndpoint,
      onRunProbeAll: () => _controller.runProbe(),
      onRunProbeSingle: (final id) => _controller.runProbe(endpointId: id),
    );
  }
}
