import 'package:flutter/material.dart';

import 'application/long_form_summary_controller.dart';
import 'domain/long_form_summary_models.dart';
import 'presentation/long_form_summary_view.dart';

/// LongFormSummaryController と TextEditingController のライフサイクルを管理し
/// 純粋 Presentational な LongFormSummaryView へ接続する Container (#2642)。
class LongFormSummaryContainer extends StatefulWidget {
  const LongFormSummaryContainer({
    super.key,
    this.controller,
  });

  final LongFormSummaryController? controller;

  @override
  State<LongFormSummaryContainer> createState() =>
      _LongFormSummaryContainerState();
}

class _LongFormSummaryContainerState extends State<LongFormSummaryContainer> {
  late LongFormSummaryController _controller;
  late bool _ownsController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final LongFormSummaryController? provided = widget.controller;
    _ownsController = provided == null;
    _controller = provided ?? LongFormSummaryController();
  }

  @override
  void didUpdateWidget(covariant LongFormSummaryContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      final LongFormSummaryController? provided = widget.controller;
      _ownsController = provided == null;
      _controller = provided ?? LongFormSummaryController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final bool ok = await _controller.submitDocument(
      title: _titleController.text,
      bodyText: _bodyController.text,
    );
    if (ok && mounted) {
      _titleController.clear();
      _bodyController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        final Set<String> expandedIds = _controller.items
            .map((LongFormDocumentWithSummary item) => item.documentId)
            .where(_controller.isExpanded)
            .toSet();

        return LongFormSummaryView(
          items: _controller.items,
          expandedDocumentIds: expandedIds,
          isLoading: _controller.isLoading,
          isSaving: _controller.isSaving,
          statusMessage: _controller.statusMessage,
          errorMessage: _controller.errorMessage,
          titleController: _titleController,
          bodyController: _bodyController,
          onSubmit: _handleSubmit,
          onToggleExpand: _controller.toggleExpanded,
          onRefreshSummary: _controller.refreshDocumentSummary,
        );
      },
    );
  }
}
