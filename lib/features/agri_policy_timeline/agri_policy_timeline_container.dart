import 'package:flutter/material.dart';

import 'application/agri_policy_controller.dart';
import 'data/supabase_agri_policy_repository.dart';
import 'domain/agri_policy_models.dart';
import 'presentation/agri_policy_timeline_view.dart';

/// Stateful container for agricultural policy timeline & KG management (#2755).
class AgriPolicyTimelineContainer extends StatefulWidget {
  const AgriPolicyTimelineContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final AgriPolicyRepository? repository;
  final AgriPolicyController? controller;
  final bool autoLoad;

  @override
  State<AgriPolicyTimelineContainer> createState() =>
      _AgriPolicyTimelineContainerState();
}

class _AgriPolicyTimelineContainerState
    extends State<AgriPolicyTimelineContainer> {
  late final AgriPolicyController _controller;
  late final bool _ownsController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateController =
      TextEditingController(text: '2026-06-01');
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _nodesController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  FactCheckStatus _selectedNewFactStatus = FactCheckStatus.unverified;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        AgriPolicyController(
          repository: widget.repository ?? SupabaseAgriPolicyRepository(),
        );
    if (widget.autoLoad) {
      _controller.loadTimeline();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    _searchController.dispose();
    _dateController.dispose();
    _titleController.dispose();
    _summaryController.dispose();
    _tagsController.dispose();
    _nodesController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _retryLoad() {
    _controller.loadTimeline();
  }

  void _runSearch() {
    _controller.loadTimeline(query: _searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.loadTimeline(
      query: '',
      tag: null,
      updateTag: true,
      phase: null,
      updatePhase: true,
    );
  }

  void _selectTag(final String? tag) {
    _controller.loadTimeline(tag: tag, updateTag: true);
  }

  void _selectPhase(final AgriPolicyPhase? phase) {
    _controller.loadTimeline(phase: phase, updatePhase: true);
  }

  void _selectNewFactStatus(final FactCheckStatus status) {
    setState(() {
      _selectedNewFactStatus = status;
    });
  }

  Future<void> _createEvent() async {
    final ok = await _controller.createEvent(
      eventDate: _dateController.text,
      title: _titleController.text,
      summary: _summaryController.text,
      rawTags: _tagsController.text,
      rawRelatedNodes: _nodesController.text,
      factCheckStatus: _selectedNewFactStatus,
      sourceCitation: _sourceController.text,
      policyImpactNotes: _notesController.text,
    );
    if (!mounted || !ok) return;
    _titleController.clear();
    _summaryController.clear();
    _tagsController.clear();
    _nodesController.clear();
    _sourceController.clear();
    _notesController.clear();
  }

  Future<void> _openFactCheckDialog(final AgriPolicyEvent event) async {
    final updated = await showDialog<_FactCheckDraft>(
      context: context,
      builder: (final BuildContext _) => _FactCheckEditDialog(event: event),
    );
    if (!mounted || updated == null) return;
    await _controller.updateFactCheck(
      id: event.id,
      factCheckStatus: updated.status,
      sourceCitation: updated.sourceCitation,
      policyImpactNotes: updated.impactNotes,
    );
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return AgriPolicyTimelineView(
          state: _controller.state,
          searchController: _searchController,
          dateController: _dateController,
          titleController: _titleController,
          summaryController: _summaryController,
          tagsController: _tagsController,
          nodesController: _nodesController,
          sourceController: _sourceController,
          notesController: _notesController,
          selectedNewFactStatus: _selectedNewFactStatus,
          onRetryLoad: _retryLoad,
          onSearch: _runSearch,
          onClearSearch: _clearSearch,
          onSelectTag: _selectTag,
          onSelectPhase: _selectPhase,
          onSelectNewFactStatus: _selectNewFactStatus,
          onCreateEvent: _createEvent,
          onEditFactCheck: _openFactCheckDialog,
        );
      },
    );
  }
}

class _FactCheckDraft {
  const _FactCheckDraft({
    required this.status,
    required this.sourceCitation,
    required this.impactNotes,
  });

  final FactCheckStatus status;
  final String sourceCitation;
  final String impactNotes;
}

class _FactCheckEditDialog extends StatefulWidget {
  const _FactCheckEditDialog({required this.event});

  final AgriPolicyEvent event;

  @override
  State<_FactCheckEditDialog> createState() => _FactCheckEditDialogState();
}

class _FactCheckEditDialogState extends State<_FactCheckEditDialog> {
  late final TextEditingController _sourceController;
  late final TextEditingController _notesController;
  late FactCheckStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.event.factCheckStatus;
    _sourceController = TextEditingController(
      text: widget.event.sourceCitation,
    );
    _notesController = TextEditingController(
      text: widget.event.policyImpactNotes,
    );
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      key: const ValueKey<String>('agri_policy_fact_dialog'),
      title: const Text('事実確認メタデータの更新'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.event.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FactCheckStatus.values
                  .map(
                    (final FactCheckStatus status) => OutlinedButton(
                      key: ValueKey<String>(
                        'agri_policy_dialog_status_${status.wireValue}',
                      ),
                      onPressed: () {
                        setState(() {
                          _status = status;
                        });
                      },
                      style: _status == status
                          ? OutlinedButton.styleFrom(
                              backgroundColor: colors.tertiaryContainer,
                              foregroundColor: colors.onTertiaryContainer,
                            )
                          : null,
                      child: Text(status.labelJa),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('agri_policy_dialog_source_input'),
              controller: _sourceController,
              decoration: const InputDecoration(
                labelText: '一次出典・公式資料',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('agri_policy_dialog_notes_input'),
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '影響評価・検証ノート',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('agri_policy_dialog_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          key: const ValueKey<String>('agri_policy_dialog_save'),
          onPressed: () => Navigator.of(context).pop(
            _FactCheckDraft(
              status: _status,
              sourceCitation: _sourceController.text,
              impactNotes: _notesController.text,
            ),
          ),
          child: const Text('更新を保存'),
        ),
      ],
    );
  }
}
