import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/rls_ai_search_controller.dart';
import 'data/supabase_rls_ai_search_repository.dart';
import 'domain/rls_ai_search_models.dart';
import 'presentation/rls_ai_search_view.dart';

/// RLS 連動 AI 検索機能の DI コンテナ (#2603 / #2655)。
class RlsAiSearchContainer extends StatefulWidget {
  const RlsAiSearchContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final RlsAiSearchController? controller;
  final RlsAiSearchRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<RlsAiSearchContainer> createState() => _RlsAiSearchContainerState();
}

class _RlsAiSearchContainerState extends State<RlsAiSearchContainer> {
  RlsAiSearchController? _ownedController;

  RlsAiSearchController get _activeController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      final RlsAiSearchRepository repo = widget.repository ??
          SupabaseRlsAiSearchRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = RlsAiSearchController(repository: repo);
    }
    if (widget.autoLoad) {
      _activeController.runAuthorizedSearch();
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RlsAiSearchView(controller: _activeController);
  }
}
