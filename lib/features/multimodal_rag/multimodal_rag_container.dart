import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/multimodal_rag_controller.dart';
import 'data/supabase_multimodal_rag_repository.dart';
import 'domain/multimodal_rag_models.dart';
import 'presentation/multimodal_rag_view.dart';

/// マルチモーダル RAG (Gemini Embedding 2 + pgvector + Storage) の DI コンテナ (#2687)。
class MultimodalRagContainer extends StatefulWidget {
  const MultimodalRagContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final MultimodalRagController? controller;
  final MultimodalRagRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<MultimodalRagContainer> createState() => _MultimodalRagContainerState();
}

class _MultimodalRagContainerState extends State<MultimodalRagContainer> {
  MultimodalRagController? _ownedController;

  MultimodalRagController get _activeController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      final MultimodalRagRepository repo = widget.repository ??
          SupabaseMultimodalRagRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = MultimodalRagController(repository: repo);
    }
    if (widget.autoLoad) {
      _activeController.loadDashboard();
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultimodalRagView(controller: _activeController);
  }
}
