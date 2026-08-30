import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/note_navigation_service.dart';
import 'note_editor_page.dart';
import 'note_list_page.dart';

class NoteNavigationPage extends StatefulWidget {
  const NoteNavigationPage({
    super.key,
    this.repository,
  });

  final NoteNavigationRepository? repository;

  @override
  State<NoteNavigationPage> createState() => _NoteNavigationPageState();
}

class _NoteNavigationPageState extends State<NoteNavigationPage> {
  late final NoteNavigationRepository _repository;
  NoteNavigationSnapshot? _snapshot;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        SupabaseNoteNavigationRepository(Supabase.instance.client);
    _reload();
  }

  Future<void> _reload() async {
    try {
      final snapshot = await _repository.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _runMutation(
    Future<void> Function() mutation, {
    required String successMessage,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await mutation();
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      key: const Key('note_navigation_page'),
      appBar: AppBar(
        title: const Text('保存済み検索・ショートカット'),
        actions: [
          IconButton(
            key: const Key('note_navigation_refresh'),
            onPressed: _saving ? null : _reload,
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _reload)
              : snapshot == null
                  ? const SizedBox.shrink()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final migration = _MigrationCard(
                          state: snapshot.migrationState,
                          busy: _saving,
                          onImport: _showInventoryImportDialog,
                          onVerify: _showVerificationDialog,
                        );
                        if (!wide) {
                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              migration,
                              const SizedBox(height: 16),
                              _buildShortcutSection(snapshot),
                              const SizedBox(height: 16),
                              _buildSavedSearchSection(snapshot),
                            ],
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              migration,
                              const SizedBox(height: 16),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: SingleChildScrollView(
                                        child: _buildShortcutSection(snapshot),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 6,
                                      child: SingleChildScrollView(
                                        child:
                                            _buildSavedSearchSection(snapshot),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildSavedSearchSection(NoteNavigationSnapshot snapshot) {
    final sourceDeleted =
        snapshot.migrationState?.status == 'source_deleted';
    return Card(
      key: const Key('saved_search_section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '保存済み検索',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('add_saved_search_button'),
                  onPressed: _saving ? null : () => _showSavedSearchDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '検索条件の原文を保存します。Evernote検索演算子は失わず保持し、'
              '現在の検索画面では対応済みの文字列・タグ条件から実行します。',
            ),
            const SizedBox(height: 12),
            if (snapshot.savedSearches.isEmpty)
              const _EmptyMessage(
                key: Key('saved_search_empty'),
                message: '保存済み検索はまだありません。',
              )
            else
              ...snapshot.savedSearches.map((savedSearch) {
                final locked = savedSearch.isImported && !sourceDeleted;
                return Card(
                  key: Key('saved_search_${savedSearch.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      savedSearch.isImported
                          ? Icons.cloud_done_outlined
                          : Icons.search,
                    ),
                    title: Text(savedSearch.name),
                    subtitle: Text(
                      savedSearch.query,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _openSavedSearch(savedSearch),
                    trailing: Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: '開く',
                          onPressed: () => _openSavedSearch(savedSearch),
                          icon: const Icon(Icons.open_in_new),
                        ),
                        IconButton(
                          tooltip: 'ショートカットに追加',
                          onPressed: _saving
                              ? null
                              : () => _addSavedSearchShortcut(savedSearch),
                          icon: const Icon(Icons.bookmark_add_outlined),
                        ),
                        IconButton(
                          tooltip: locked ? '原本削除確認まで編集不可' : '編集',
                          onPressed: _saving || locked
                              ? null
                              : () => _showSavedSearchDialog(
                                    savedSearch: savedSearch,
                                  ),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: locked ? '原本削除確認まで削除不可' : '削除',
                          onPressed: _saving || locked
                              ? null
                              : () => _deleteSavedSearch(savedSearch),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutSection(NoteNavigationSnapshot snapshot) {
    final sourceDeleted =
        snapshot.migrationState?.status == 'source_deleted';
    return Card(
      key: const Key('shortcut_section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ショートカット',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('add_shortcut_button'),
                  onPressed:
                      _saving ? null : () => _showShortcutDialog(snapshot),
                  icon: const Icon(Icons.add),
                  label: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ノート、ノートブック、スタック、タグ、保存済み検索を並べます。'
              '1〜9番はEvernoteのキーボード位置も保持します。',
            ),
            const SizedBox(height: 12),
            if (snapshot.shortcuts.isEmpty)
              const _EmptyMessage(
                key: Key('shortcut_empty'),
                message: 'ショートカットはまだありません。',
              )
            else
              ...snapshot.shortcuts.map((shortcut) {
                final locked = shortcut.isImported && !sourceDeleted;
                return Card(
                  key: Key('shortcut_${shortcut.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(shortcut.position.toString()),
                    ),
                    title: Text(shortcut.label),
                    subtitle: Text(
                      '${shortcut.targetType.label}'
                      '${shortcut.isResolved ? '' : '・対応先未解決'}',
                    ),
                    onTap: shortcut.isResolved
                        ? () => _openShortcut(shortcut, snapshot)
                        : null,
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: '上へ',
                          onPressed: _saving ||
                                  locked ||
                                  shortcut.position <= 1
                              ? null
                              : () => _runMutation(
                                    () => _repository.moveShortcut(
                                      shortcut: shortcut,
                                      position: shortcut.position - 1,
                                    ),
                                    successMessage: '順序を更新しました。',
                                  ),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: '下へ',
                          onPressed: _saving ||
                                  locked ||
                                  shortcut.position >=
                                      snapshot.shortcuts.length
                              ? null
                              : () => _runMutation(
                                    () => _repository.moveShortcut(
                                      shortcut: shortcut,
                                      position: shortcut.position + 1,
                                    ),
                                    successMessage: '順序を更新しました。',
                                  ),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: locked ? '原本削除確認まで削除不可' : '削除',
                          onPressed: _saving || locked
                              ? null
                              : () => _deleteShortcut(shortcut),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _openSavedSearch(NoteSavedSearch savedSearch) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteListPage(
          initialSearchQuery: savedSearch.query,
        ),
      ),
    );
  }

  Future<void> _openShortcut(
    NoteShortcut shortcut,
    NoteNavigationSnapshot snapshot,
  ) async {
    Widget? target;
    switch (shortcut.targetType) {
      case NoteShortcutTargetType.note:
        target = NoteEditorPage(noteId: shortcut.targetNoteId.toString());
        break;
      case NoteShortcutTargetType.notebook:
      case NoteShortcutTargetType.stack:
        target = NoteListPage(
          initialCollectionId: shortcut.targetCollectionId,
        );
        break;
      case NoteShortcutTargetType.tag:
        target = NoteListPage(initialTag: shortcut.targetTag);
        break;
      case NoteShortcutTargetType.savedSearch:
        NoteSavedSearch? search;
        for (final candidate in snapshot.savedSearches) {
          if (candidate.id == shortcut.targetSavedSearchId) {
            search = candidate;
            break;
          }
        }
        if (search != null) {
          target = NoteListPage(initialSearchQuery: search.query);
        }
        break;
    }
    final destination = target;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ショートカットの対応先を解決してください。')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => destination),
    );
  }

  Future<void> _showSavedSearchDialog({
    NoteSavedSearch? savedSearch,
  }) async {
    final nameController =
        TextEditingController(text: savedSearch?.name ?? '');
    final queryController =
        TextEditingController(text: savedSearch?.query ?? '');
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(savedSearch == null ? '保存済み検索を追加' : '保存済み検索を編集'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('saved_search_name_field'),
                controller: nameController,
                decoration: const InputDecoration(labelText: '名前'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('saved_search_query_field'),
                controller: queryController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '検索条件',
                  hintText: '例: tag:project intitle:計画',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('save_saved_search_button'),
            onPressed: () => Navigator.pop(
              context,
              (nameController.text, queryController.text),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameController.dispose();
    queryController.dispose();
    if (result == null) return;
    await _runMutation(
      () => savedSearch == null
          ? _repository.createSavedSearch(
              name: result.$1,
              query: result.$2,
            )
          : _repository.updateSavedSearch(
              savedSearch: savedSearch,
              name: result.$1,
              query: result.$2,
            ),
      successMessage: '保存済み検索を保存しました。',
    );
  }

  Future<void> _addSavedSearchShortcut(NoteSavedSearch savedSearch) {
    return _runMutation(
      () => _repository.createShortcut(
        NoteShortcutDraft(
          targetType: NoteShortcutTargetType.savedSearch,
          label: savedSearch.name,
          targetSavedSearchId: savedSearch.id,
        ),
      ),
      successMessage: 'ショートカットに追加しました。',
    );
  }

  Future<void> _showShortcutDialog(
    NoteNavigationSnapshot snapshot,
  ) async {
    var targetType = NoteShortcutTargetType.tag;
    String? savedSearchId =
        snapshot.savedSearches.isEmpty ? null : snapshot.savedSearches.first.id;
    final labelController = TextEditingController();
    final targetController = TextEditingController();
    final draft = await showDialog<NoteShortcutDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final usesSavedSearch =
              targetType == NoteShortcutTargetType.savedSearch;
          return AlertDialog(
            title: const Text('ショートカットを追加'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<NoteShortcutTargetType>(
                    key: const Key('shortcut_target_type_field'),
                    initialValue: targetType,
                    decoration: const InputDecoration(labelText: '対象種別'),
                    items: NoteShortcutTargetType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => targetType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('shortcut_label_field'),
                    controller: labelController,
                    decoration: const InputDecoration(labelText: '表示名'),
                  ),
                  const SizedBox(height: 12),
                  if (usesSavedSearch)
                    DropdownButtonFormField<String>(
                      key: const Key('shortcut_saved_search_field'),
                      initialValue: savedSearchId,
                      decoration:
                          const InputDecoration(labelText: '保存済み検索'),
                      items: snapshot.savedSearches
                          .map(
                            (search) => DropdownMenuItem(
                              value: search.id,
                              child: Text(search.name),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) =>
                          setDialogState(() => savedSearchId = value),
                    )
                  else
                    TextField(
                      key: const Key('shortcut_target_value_field'),
                      controller: targetController,
                      decoration: InputDecoration(
                        labelText: switch (targetType) {
                          NoteShortcutTargetType.note => '本サイトのノートID',
                          NoteShortcutTargetType.notebook ||
                          NoteShortcutTargetType.stack =>
                            '本サイトのコレクションID',
                          NoteShortcutTargetType.tag => 'タグ',
                          NoteShortcutTargetType.savedSearch => '',
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                key: const Key('save_shortcut_button'),
                onPressed: usesSavedSearch && savedSearchId == null
                    ? null
                    : () {
                        final numericTarget =
                            int.tryParse(targetController.text.trim());
                        Navigator.pop(
                          context,
                          NoteShortcutDraft(
                            targetType: targetType,
                            label: labelController.text,
                            targetNoteId:
                                targetType == NoteShortcutTargetType.note
                                    ? numericTarget
                                    : null,
                            targetCollectionId: targetType ==
                                        NoteShortcutTargetType.notebook ||
                                    targetType == NoteShortcutTargetType.stack
                                ? numericTarget
                                : null,
                            targetTag:
                                targetType == NoteShortcutTargetType.tag
                                    ? targetController.text
                                    : null,
                            targetSavedSearchId:
                                usesSavedSearch ? savedSearchId : null,
                          ),
                        );
                      },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
    labelController.dispose();
    targetController.dispose();
    if (draft == null) return;
    await _runMutation(
      () => _repository.createShortcut(draft),
      successMessage: 'ショートカットを追加しました。',
    );
  }

  Future<void> _showInventoryImportDialog() async {
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(
        const <String, dynamic>{
          'saved_searches': <dynamic>[],
          'shortcuts': <dynamic>[],
        },
      ),
    );
    final manifest = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evernoteアカウント棚卸し'),
        content: SizedBox(
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ENEXに含まれない保存済み検索とショートカットをJSONで記録します。'
                'ゼロ件の場合も空配列を保存してください。',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('navigation_inventory_json_field'),
                controller: controller,
                minLines: 10,
                maxLines: 16,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('import_navigation_inventory_button'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('クラウドに固定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (manifest == null) return;
    await _runMutation(
      () async {
        await _repository.importEvernoteInventory(manifest);
      },
      successMessage: 'Evernoteアカウント棚卸しを固定しました。',
    );
  }

  Future<void> _showVerificationDialog() async {
    final checks = List<bool>.filled(5, false);
    final labels = <String>[
      '保存済み検索の件数が一致',
      '名称と検索条件原文が一致',
      'ショートカットの件数が一致',
      '並び順（1〜9を含む）が一致',
      'すべての対象を本サイトで開ける',
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('棚卸しを検証済みにする'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < labels.length; index++)
                  CheckboxListTile(
                    key: Key('navigation_verify_check_$index'),
                    value: checks[index],
                    title: Text(labels[index]),
                    onChanged: (value) => setDialogState(
                      () => checks[index] = value ?? false,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('verify_navigation_inventory_button'),
              onPressed: checks.every((value) => value)
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('検証済みにする'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _runMutation(
      () async {
        await _repository.verifyEvernoteInventory();
      },
      successMessage: '保存済み検索とショートカットを検証済みにしました。',
    );
  }

  Future<void> _deleteSavedSearch(NoteSavedSearch savedSearch) async {
    final confirmed = await _confirmDelete(savedSearch.name);
    if (!confirmed) return;
    await _runMutation(
      () => _repository.deleteSavedSearch(savedSearch),
      successMessage: '保存済み検索を削除しました。',
    );
  }

  Future<void> _deleteShortcut(NoteShortcut shortcut) async {
    final confirmed = await _confirmDelete(shortcut.label);
    if (!confirmed) return;
    await _runMutation(
      () => _repository.deleteShortcut(shortcut),
      successMessage: 'ショートカットを削除しました。',
    );
  }

  Future<bool> _confirmDelete(String label) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('本サイトの項目を削除'),
            content: Text('「$label」を削除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('削除'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _MigrationCard extends StatelessWidget {
  const _MigrationCard({
    required this.state,
    required this.busy,
    required this.onImport,
    required this.onVerify,
  });

  final EvernoteNavigationMigrationState? state;
  final bool busy;
  final VoidCallback onImport;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final current = state;
    final status = current?.status ?? '未棚卸し';
    final verified = current?.isVerified ?? false;
    return Card(
      key: const Key('navigation_migration_card'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(
              verified ? Icons.verified_outlined : Icons.inventory_2_outlined,
              color: verified ? Colors.green : null,
            ),
            SizedBox(
              width: 430,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evernoteアカウント棚卸し: $status',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '保存済み検索 '
                    '${current?.verifiedSavedSearchCount ?? 0}/'
                    '${current?.savedSearchCount ?? 0}・'
                    'ショートカット '
                    '${current?.verifiedShortcutCount ?? 0}/'
                    '${current?.shortcutCount ?? 0}',
                  ),
                  const Text(
                    'ここが検証済みになるまで、DBはEvernote側削除状態への移行を拒否します。',
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const Key('open_navigation_inventory_button'),
              onPressed: busy || verified ? null : onImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('棚卸しJSON'),
            ),
            FilledButton.icon(
              key: const Key('open_navigation_verify_button'),
              onPressed: busy || current?.status != 'imported'
                  ? null
                  : onVerify,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('照合して検証'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(message)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}
