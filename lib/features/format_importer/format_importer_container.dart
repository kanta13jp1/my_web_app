import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/format_importer_controller.dart';
import 'data/supabase_format_importer_repository.dart';
import 'domain/format_importer_models.dart';
import 'presentation/format_importer_view.dart';

/// 汎用フォーマットインポーター＆JSONB属性管理の DI コンテナ (#2741)。
class FormatImporterContainer extends StatefulWidget {
  const FormatImporterContainer({
    super.key,
    this.controller,
    this.repository,
    this.clientResolver,
    this.autoLoad = true,
  });

  final FormatImporterController? controller;
  final FormatImporterRepository? repository;
  final SupabaseClient Function()? clientResolver;
  final bool autoLoad;

  @override
  State<FormatImporterContainer> createState() =>
      _FormatImporterContainerState();
}

class _FormatImporterContainerState extends State<FormatImporterContainer> {
  FormatImporterController? _ownedController;

  FormatImporterController get _activeController =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    _ensureController();
    if (widget.autoLoad) {
      _activeController.loadWorkspace();
    }
  }

  @override
  void didUpdateWidget(covariant FormatImporterContainer oldWidget) {
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
          _activeController.loadWorkspace();
        }
      }
    }
  }

  void _ensureController() {
    if (widget.controller == null && _ownedController == null) {
      final FormatImporterRepository repo = widget.repository ??
          SupabaseFormatImporterRepository(
            clientResolver: widget.clientResolver,
          );
      _ownedController = FormatImporterController(repository: repo);
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormatImporterView(controller: _activeController);
  }
}
