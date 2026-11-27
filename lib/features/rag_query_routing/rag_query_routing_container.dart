import 'package:flutter/material.dart';

import 'application/rag_query_routing_controller.dart';
import 'data/supabase_rag_query_routing_repository.dart';
import 'domain/rag_query_routing_models.dart';
import 'presentation/rag_query_routing_view.dart';

/// Stateful container wiring `memory.query_route` and clarification dialog (#2754).
class RagQueryRoutingContainer extends StatefulWidget {
  const RagQueryRoutingContainer({
    super.key,
    this.repository,
    this.controller,
  });

  final RagQueryRoutingRepository? repository;
  final RagQueryRoutingController? controller;

  @override
  State<RagQueryRoutingContainer> createState() =>
      _RagQueryRoutingContainerState();
}

class _RagQueryRoutingContainerState extends State<RagQueryRoutingContainer> {
  late final RagQueryRoutingController _controller;
  late final bool _ownsController;
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _queryReportController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        RagQueryRoutingController(
          repository: widget.repository ?? SupabaseRagQueryRoutingRepository(),
        );
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _queryController.dispose();
    _queryReportController.dispose();
    super.dispose();
  }

  Future<void> _submitCurrent({
    final String? overrideQuery,
    final String? overrideReport,
  }) async {
    final query = overrideQuery ?? _queryController.text;
    final report = overrideReport ?? _queryReportController.text;
    final completed = await _controller.submitQuery(
      query: query,
      queryReport: report,
    );
    if (!mounted || completed) {
      return;
    }
    final pending = _controller.state.pendingClarification;
    if (pending != null) {
      await _openClarificationDialog(pending);
    }
  }

  Future<void> _openClarificationDialog(
    final QueryRouteDecision decision,
  ) async {
    final revisedQuery = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (final BuildContext dialogContext) =>
          _ClarifyQueryDialog(decision: decision),
    );
    if (!mounted) {
      return;
    }
    if (revisedQuery == null || revisedQuery.trim().isEmpty) {
      _controller.dismissClarification();
      return;
    }

    final cleanQuery = revisedQuery.trim();
    _queryController.text = cleanQuery;
    // Clear an unclear report snippet before retrying so the revised query runs cleanly.
    final currentReport = _queryReportController.text.trim();
    final shouldClearReport =
        currentReport.isNotEmpty && decision.requiresClarification;
    if (shouldClearReport) {
      _queryReportController.clear();
    }
    await _submitCurrent(
      overrideQuery: cleanQuery,
      overrideReport: shouldClearReport ? '' : currentReport,
    );
  }

  void _submitFromView() {
    _submitCurrent();
  }

  void _applyPreset(final QueryReportTokenPreset preset) {
    _queryController.text = preset.sampleQuery;
    _queryReportController.text = preset.sampleReport;
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return RagQueryRoutingView(
          state: _controller.state,
          queryController: _queryController,
          queryReportController: _queryReportController,
          onToggleAutoReport: (final bool nextVal) {
            _controller.setAutoReport(enabled: nextVal);
          },
          onApplyPreset: _applyPreset,
          onSubmit: _submitFromView,
          onOpenClarifyDialog: _openClarificationDialog,
        );
      },
    );
  }
}

class _ClarifyQueryDialog extends StatefulWidget {
  const _ClarifyQueryDialog({required this.decision});

  final QueryRouteDecision decision;

  @override
  State<_ClarifyQueryDialog> createState() => _ClarifyQueryDialogState();
}

class _ClarifyQueryDialogState extends State<_ClarifyQueryDialog> {
  late final TextEditingController _revisedController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _revisedController = TextEditingController(
      text: widget.decision.originalQuery,
    );
  }

  @override
  void dispose() {
    _revisedController.dispose();
    super.dispose();
  }

  void _confirmRevisedQuery() {
    final trimmed = _revisedController.text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _validationError = '具体的な検索クエリを入力してください。';
      });
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final feedback =
        widget.decision.feedback ?? '質問の意図が不明瞭なため推論を中断しました。対象や条件を追加してください。';

    return AlertDialog(
      key: const ValueKey<String>('rag_routing_clarify_dialog'),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Icon(Icons.help_outline, color: colors.error),
          const Text('質問の明確化が必要です'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '推論プロセスを中断しました:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              feedback,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '元のクエリ: ${widget.decision.originalQuery}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('rag_routing_clarify_input'),
              controller: _revisedController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: '修正した検索クエリ',
                hintText: '例: Pleias Open Data Layers enterprise RAG',
                errorText: _validationError,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (final String _) => _confirmRevisedQuery(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('rag_routing_clarify_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          key: const ValueKey<String>('rag_routing_clarify_submit'),
          onPressed: _confirmRevisedQuery,
          child: const Text('修正クエリで再検索'),
        ),
      ],
    );
  }
}
