import 'package:flutter/material.dart';

import '../application/realtime_lock_controller.dart';
import '../domain/realtime_lock_models.dart';

/// Supabase Realtime Presence・即時競合アラート・楽観的ロック編集画面 (#2744)。
class RealtimeLockView extends StatefulWidget {
  const RealtimeLockView({
    super.key,
    required this.controller,
  });

  final RealtimeLockController controller;

  @override
  State<RealtimeLockView> createState() => _RealtimeLockViewState();
}

class _RealtimeLockViewState extends State<RealtimeLockView> {
  final TextEditingController _newTitleController = TextEditingController();
  final TextEditingController _newContentController = TextEditingController();
  final TextEditingController _draftTitleController = TextEditingController();
  final TextEditingController _draftContentController = TextEditingController();

  String? _syncedDocId;
  int _syncedRevision = -1;

  @override
  void initState() {
    super.initState();
    _syncControllersFromController();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant RealtimeLockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _syncControllersFromController(force: true);
    }
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }
    _syncControllersFromController();
  }

  void _syncControllersFromController({bool force = false}) {
    final RealtimeLockController ctrl = widget.controller;
    final String? docId = ctrl.selectedRecordId;
    if (force ||
        docId != _syncedDocId ||
        ctrl.baseRevision != _syncedRevision) {
      _syncedDocId = docId;
      _syncedRevision = ctrl.baseRevision;
      if (_draftTitleController.text != ctrl.draftTitle) {
        _draftTitleController.text = ctrl.draftTitle;
      }
      if (_draftContentController.text != ctrl.draftContent) {
        _draftContentController.text = ctrl.draftContent;
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _newTitleController.dispose();
    _newContentController.dispose();
    _draftTitleController.dispose();
    _draftContentController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final bool ok = await widget.controller.createDocument(
      title: _newTitleController.text,
      content: _newContentController.text,
    );
    if (ok && mounted) {
      _newTitleController.clear();
      _newContentController.clear();
    }
  }

  Future<void> _handleSave({bool forceUseServerRevision = false}) async {
    widget.controller.updateDraftTitle(_draftTitleController.text);
    widget.controller.updateDraftContent(_draftContentController.text);
    await widget.controller.saveDraft(
      forceUseServerRevision: forceUseServerRevision,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final RealtimeLockController ctrl = widget.controller;
        final LockedDocumentRecord? selected = ctrl.selectedDocument;
        final RevisionAlertEvent? conflict = ctrl.liveConflictAlert;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Realtime 同時編集ロック＆競合検知',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Presence による同時編集ユーザーの可視化、バッチ／他者更新の即時競合アラート、'
                'リビジョン一致チェック付き楽観的ロック保存を行います。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (ctrl.isBusy) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (conflict != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildConflictBanner(ctrl, conflict, colors),
              ],
              if (ctrl.errorMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey<String>('realtime_lock_error_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ctrl.errorMessage,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ],
              if (ctrl.statusMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey<String>('realtime_lock_status_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ctrl.statusMessage,
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildPresenceCard(ctrl, colors),
              const SizedBox(height: 16),
              _buildDocumentSelectorCard(ctrl, selected, colors),
              const SizedBox(height: 16),
              _buildEditorCard(ctrl, selected, colors),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConflictBanner(
    RealtimeLockController ctrl,
    RevisionAlertEvent conflict,
    ColorScheme colors,
  ) {
    final String latestPreview = conflict.serverRecord?.content ?? '';
    return Container(
      key: const ValueKey<String>('realtime_lock_conflict_banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '競合アラート検知: ${conflict.updatedBy} (${conflict.sourceActor}) が '
                  'r${ctrl.baseRevision} -> r${conflict.newRevision} へ更新しました',
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (latestPreview.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'サーバー最新内容: $latestPreview',
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                key: const ValueKey<String>('realtime_lock_reload_server_btn'),
                onPressed: ctrl.acceptServerVersion,
                icon: const Icon(Icons.refresh),
                label: const Text('サーバー最新で再読込'),
              ),
              FilledButton.icon(
                key: const ValueKey<String>('realtime_lock_rebase_save_btn'),
                onPressed: () => _handleSave(forceUseServerRevision: true),
                icon: const Icon(Icons.merge_type),
                label: Text(
                  '最新リビジョン r${conflict.newRevision} 基準で保存',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceCard(
    RealtimeLockController ctrl,
    ColorScheme colors,
  ) {
    return Card(
      key: const ValueKey<String>('realtime_lock_presence_panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Realtime Presence (同時編集中: ${ctrl.activeEditors.length} 名)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (ctrl.activeEditors.isEmpty)
              Text(
                '接続中の編集ユーザーは待機中です。',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ctrl.activeEditors
                    .map(
                      (PresenceEditor editor) => Chip(
                        key: ValueKey<String>(
                          'realtime_lock_editor_${editor.sessionId}',
                        ),
                        avatar: Icon(
                          editor.isSelf ? Icons.person : Icons.group,
                          size: 18,
                        ),
                        backgroundColor: editor.isSelf
                            ? colors.primaryContainer
                            : colors.tertiaryContainer,
                        label: Text(
                          '${editor.displayName} (${editor.userId})',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSelectorCard(
    RealtimeLockController ctrl,
    LockedDocumentRecord? selected,
    ColorScheme colors,
  ) {
    return Card(
      key: const ValueKey<String>('realtime_lock_selector_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '1. 編集対象ドキュメント選択・新規作成',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (ctrl.documents.isNotEmpty) ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ctrl.documents
                    .map(
                      (LockedDocumentRecord doc) => ChoiceChip(
                        key: ValueKey<String>('realtime_lock_doc_${doc.id}'),
                        label: Text('${doc.title} (r${doc.revision})'),
                        selected: selected?.id == doc.id,
                        onSelected: (bool picked) {
                          if (picked) {
                            ctrl.selectDocument(doc.id);
                          }
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey<String>('realtime_lock_new_title_field'),
              controller: _newTitleController,
              decoration: const InputDecoration(
                labelText: '新規ドキュメントタイトル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('realtime_lock_new_content_field'),
              controller: _newContentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '初期本文',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('realtime_lock_create_btn'),
                  onPressed: _handleCreate,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('新規ドキュメント作成'),
                ),
                if (selected != null)
                  FilledButton.tonalIcon(
                    key: const ValueKey<String>(
                      'realtime_lock_simulate_batch_btn',
                    ),
                    onPressed: ctrl.simulateExternalBatchUpdate,
                    icon: const Icon(Icons.sync_problem_outlined),
                    label: const Text('外部バッチ更新シミュレート'),
                  ),
              ],
            ),
            if (selected == null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'ドキュメントを作成すると Presence と楽観的ロックが有効になります。',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditorCard(
    RealtimeLockController ctrl,
    LockedDocumentRecord? selected,
    ColorScheme colors,
  ) {
    return Card(
      key: const ValueKey<String>('realtime_lock_editor_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '2. 楽観的ロック付きエディタ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  key: const ValueKey<String>('realtime_lock_revision_chip'),
                  backgroundColor: colors.secondaryContainer,
                  label: Text('取得リビジョン: r${ctrl.baseRevision}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (selected == null)
              Text(
                '編集対象が未選択です。',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else ...<Widget>[
              TextField(
                key: const ValueKey<String>('realtime_lock_draft_title_field'),
                controller: _draftTitleController,
                onChanged: ctrl.updateDraftTitle,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey<String>(
                  'realtime_lock_draft_content_field',
                ),
                controller: _draftContentController,
                onChanged: ctrl.updateDraftContent,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: '本文 (expected_revision=r${ctrl.baseRevision} で保存)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey<String>('realtime_lock_save_btn'),
                onPressed: () => _handleSave(),
                icon: const Icon(Icons.lock_outline),
                label: const Text('楽観的ロックで保存'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
