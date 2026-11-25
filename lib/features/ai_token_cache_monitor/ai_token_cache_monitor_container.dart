import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/ai_token_cache_monitor_controller.dart';
import 'data/supabase_ai_token_cache_monitor_repository.dart';
import 'domain/ai_token_cache_monitor_models.dart';
import 'presentation/ai_token_cache_monitor_view.dart';

class AiTokenCacheMonitorContainer extends StatefulWidget {
  const AiTokenCacheMonitorContainer({
    super.key,
    this.repository,
    this.analyzer = const LocalPrefixStabilityAnalyzer(),
  });

  final AiTokenCacheMonitorRepository? repository;
  final LocalPrefixStabilityAnalyzer analyzer;

  @override
  State<AiTokenCacheMonitorContainer> createState() =>
      _AiTokenCacheMonitorContainerState();
}

class _AiTokenCacheMonitorContainerState
    extends State<AiTokenCacheMonitorContainer> {
  late final AiTokenCacheMonitorController _ctrl;

  @override
  void initState() {
    super.initState();
    final repo = widget.repository ??
        SupabaseAiTokenCacheMonitorRepository(Supabase.instance.client);
    _ctrl = AiTokenCacheMonitorController(
      repository: repo,
      analyzer: widget.analyzer,
    );
    unawaited(_ctrl.loadSummary());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AiTokenCacheMonitorView(controller: _ctrl);
  }
}
