import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/structured_llm_routing_controller.dart';
import 'data/supabase_structured_llm_routing_repository.dart';
import 'domain/structured_llm_routing_models.dart';
import 'presentation/structured_llm_routing_view.dart';

class StructuredLlmRoutingContainer extends StatefulWidget {
  const StructuredLlmRoutingContainer({
    super.key,
    this.repository,
    this.initialTaskType = 'classification',
  });

  final StructuredLlmRoutingRepository? repository;
  final String initialTaskType;

  @override
  State<StructuredLlmRoutingContainer> createState() =>
      _StructuredLlmRoutingContainerState();
}

class _StructuredLlmRoutingContainerState
    extends State<StructuredLlmRoutingContainer> {
  late final StructuredLlmRoutingController _controller;

  @override
  void initState() {
    super.initState();
    final StructuredLlmRoutingRepository repo = widget.repository ??
        SupabaseStructuredLlmRoutingRepository(Supabase.instance.client);
    _controller = StructuredLlmRoutingController(repository: repo);
    _controller.previewRoute(taskType: widget.initialTaskType);
    _controller.loadPreferences();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StructuredLlmRoutingView(
      controller: _controller,
      initialTaskType: widget.initialTaskType,
    );
  }
}
