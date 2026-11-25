import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/unified_media_library_controller.dart';
import 'data/supabase_unified_media_library_repository.dart';
import 'domain/unified_media_library_models.dart';
import 'presentation/unified_media_library_view.dart';

/// 統合メディアライブラリ＆アセット再利用機能の DI コンテナ (#2714)。
class UnifiedMediaLibraryContainer extends StatefulWidget {
  const UnifiedMediaLibraryContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final UnifiedMediaLibraryController? controller;
  final UnifiedMediaLibraryRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<UnifiedMediaLibraryContainer> createState() =>
      _UnifiedMediaLibraryContainerState();
}

class _UnifiedMediaLibraryContainerState
    extends State<UnifiedMediaLibraryContainer> {
  UnifiedMediaLibraryController? _ownedController;

  UnifiedMediaLibraryController get _activeController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    _ensureController();
    if (widget.autoLoad) {
      _activeController.loadAssets();
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedMediaLibraryContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.repository != widget.repository ||
        oldWidget.clientResolver != widget.clientResolver) {
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      } else {
        _ownedController?.dispose();
        _ownedController = null;
        _ensureController();
        if (widget.autoLoad) {
          _activeController.loadAssets();
        }
      }
    }
  }

  void _ensureController() {
    if (widget.controller == null && _ownedController == null) {
      final UnifiedMediaLibraryRepository repo = widget.repository ??
          SupabaseUnifiedMediaLibraryRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = UnifiedMediaLibraryController(repository: repo);
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UnifiedMediaLibraryView(controller: _activeController);
  }
}
