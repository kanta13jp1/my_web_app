import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/realtime_lock_controller.dart';
import 'data/supabase_realtime_lock_repository.dart';
import 'domain/realtime_lock_models.dart';
import 'presentation/realtime_lock_view.dart';

/// Realtime 同時編集ロック＆競合検知機能の DI コンテナ (#2744)。
class RealtimeLockContainer extends StatefulWidget {
  const RealtimeLockContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final RealtimeLockController? controller;
  final RealtimeLockRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<RealtimeLockContainer> createState() => _RealtimeLockContainerState();
}

class _RealtimeLockContainerState extends State<RealtimeLockContainer> {
  RealtimeLockController? _ownedController;

  RealtimeLockController get _activeController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    _ensureController();
    if (widget.autoLoad) {
      _activeController.loadDocuments();
    }
  }

  @override
  void didUpdateWidget(covariant RealtimeLockContainer oldWidget) {
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
          _activeController.loadDocuments();
        }
      }
    }
  }

  void _ensureController() {
    if (widget.controller == null && _ownedController == null) {
      final RealtimeLockRepository repo = widget.repository ??
          SupabaseRealtimeLockRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = RealtimeLockController(repository: repo);
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RealtimeLockView(controller: _activeController);
  }
}
