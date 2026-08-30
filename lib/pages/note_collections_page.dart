import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/note_collection_service.dart';
import 'note_list_page.dart';

class NoteCollectionsPage extends StatefulWidget {
  const NoteCollectionsPage({
    super.key,
    this.dataSource,
    this.supabaseClient,
  });

  final NoteCollectionDataSource? dataSource;
  final SupabaseClient? supabaseClient;

  @override
  State<NoteCollectionsPage> createState() => _NoteCollectionsPageState();
}

class _NoteCollectionsPageState extends State<NoteCollectionsPage> {
  late final NoteCollectionDataSource _dataSource;
  NoteCollectionSnapshot? _snapshot;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ??
        SupabaseNoteCollectionDataSource(
          widget.supabaseClient ?? Supabase.instance.client,
        );
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _dataSource.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _mutate(
    Future<void> Function() operation,
    String successMessage,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await operation();
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('コレクション操作に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      key: const Key('note_collections_page'),
      appBar: AppBar(
        title: const Text('ノートブック・スタック・Space'),
        actions: [
          IconButton(
            key: const Key('note_collections_refresh'),
            onPressed: _saving ? null : _reload,
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: snapshot == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('note_collections_add_root'),
              onPressed: _saving ? null : () => _showCreateDialog(),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('新規作成'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: Text('再試行: $_error'),
                  ),
                )
              : snapshot == null
                  ? const Center(child: Text('コレクション情報がありません'))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final tree = _buildTree(snapshot);
                        if (constraints.maxWidth < 840) return tree;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 310,
                              child: _buildSummary(snapshot),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(child: tree),
                          ],
                        );
                      },
                    ),
    );
  }

  Widget _buildSummary(NoteCollectionSnapshot snapshot) {
    int count(NoteCollectionType type) =>
        snapshot.collections.where((item) => item.type == type).length;
    final imported =
        snapshot.collections.where((item) => item.isImported).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'コレクション移行',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text('Space: ${count(NoteCollectionType.space)}'),
                Text('スタック: ${count(NoteCollectionType.stack)}'),
                Text('ノートブック: ${count(NoteCollectionType.notebook)}'),
                Text('Evernote原本: $imported'),
                const SizedBox(height: 12),
                Text(
                  snapshot.evernoteSourceDeleted
                      ? 'Evernote原本削除確認済み'
                      : '移行済みの名称・所属は証跡保護中',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Spaceとスタックはルートに作成し、ノートブックを配下へ移動できます。'
                  '既定ノートブックは削除できません。',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTree(NoteCollectionSnapshot snapshot) {
    final entries = _flatten(snapshot);
    return ListView(
      key: const Key('note_collections_tree'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('コレクションはまだありません。'),
            ),
          ),
        for (final entry in entries)
          _collectionCard(snapshot, entry.collection, entry.depth),
      ],
    );
  }

  Widget _collectionCard(
    NoteCollectionSnapshot snapshot,
    NoteCollectionRecord collection,
    int depth,
  ) {
    final locked = snapshot.isLocked(collection);
    final isNotebook = collection.type == NoteCollectionType.notebook;
    return Padding(
      padding: EdgeInsets.only(left: (depth * 20).clamp(0, 100).toDouble()),
      child: Card(
        key: ValueKey<String>('note_collection_${collection.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(collection.type)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          collection.type.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (collection.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin, size: 18),
                    ),
                  if (collection.isDefault)
                    const Chip(
                      label: Text('既定'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (locked)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Tooltip(
                        message: 'Evernote原本削除確認まで名称・所属・削除を保護',
                        child: Icon(Icons.lock_outline, size: 18),
                      ),
                    ),
                ],
              ),
              if (collection.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(collection.description),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton.icon(
                    key: ValueKey<String>(
                      'note_collection_open_${collection.id}',
                    ),
                    onPressed: () => _openCollection(collection),
                    icon: const Icon(Icons.notes_outlined),
                    label: Text('${collection.noteCount}件を表示'),
                  ),
                  if (collection.type != NoteCollectionType.notebook)
                    OutlinedButton.icon(
                      key: ValueKey<String>(
                        'note_collection_add_notebook_${collection.id}',
                      ),
                      onPressed: _saving
                          ? null
                          : () => _showCreateDialog(parent: collection),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('ノートブック追加'),
                    ),
                  if (isNotebook && !collection.isDefault)
                    TextButton.icon(
                      key: ValueKey<String>(
                        'note_collection_default_${collection.id}',
                      ),
                      onPressed: _saving
                          ? null
                          : () => _mutate(
                                () => _dataSource
                                    .setDefaultNotebook(collection.id),
                                '既定ノートブックを更新しました。',
                              ),
                      icon: const Icon(Icons.star_outline),
                      label: const Text('既定にする'),
                    ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _mutate(
                              () => _dataSource.setPinned(
                                id: collection.id,
                                pinned: !collection.isPinned,
                              ),
                              collection.isPinned
                                  ? 'ピン留めを解除しました。'
                                  : 'ピン留めしました。',
                            ),
                    icon: Icon(
                      collection.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                    label: Text(collection.isPinned ? 'ピン解除' : 'ピン留め'),
                  ),
                  TextButton.icon(
                    onPressed: _saving || locked
                        ? null
                        : () => _showEditDialog(collection),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('編集'),
                  ),
                  if (isNotebook)
                    TextButton.icon(
                      onPressed: _saving || locked
                          ? null
                          : () => _showMoveDialog(snapshot, collection),
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: const Text('移動'),
                    ),
                  IconButton(
                    tooltip: '上へ',
                    onPressed: _saving
                        ? null
                        : () => _mutate(
                              () => _dataSource.setSortOrder(
                                id: collection.id,
                                sortOrder: collection.sortOrder > 0
                                    ? collection.sortOrder - 1
                                    : 0,
                              ),
                              '表示順を更新しました。',
                            ),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: '下へ',
                    onPressed: _saving
                        ? null
                        : () => _mutate(
                              () => _dataSource.setSortOrder(
                                id: collection.id,
                                sortOrder: collection.sortOrder + 1,
                              ),
                              '表示順を更新しました。',
                            ),
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  IconButton(
                    key: ValueKey<String>(
                      'note_collection_delete_${collection.id}',
                    ),
                    tooltip: locked
                        ? 'Evernote原本削除確認まで削除不可'
                        : collection.isDefault
                            ? '既定ノートブックは削除不可'
                            : '削除',
                    onPressed: _saving || locked || collection.isDefault
                        ? null
                        : () => _confirmDelete(collection),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCollection(NoteCollectionRecord collection) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteListPage(initialCollectionId: collection.id),
      ),
    );
  }

  Future<void> _showCreateDialog({NoteCollectionRecord? parent}) async {
    var type = NoteCollectionType.notebook;
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            parent == null
                ? 'コレクションを作成'
                : '${parent.name}にノートブックを作成',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (parent == null)
                  DropdownButtonFormField<NoteCollectionType>(
                    key: const Key('note_collection_type_field'),
                    initialValue: type,
                    decoration: const InputDecoration(labelText: '種類'),
                    items: NoteCollectionType.values
                        .map(
                          (value) => DropdownMenuItem<NoteCollectionType>(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => type = value);
                      }
                    },
                  ),
                TextField(
                  key: const Key('note_collection_name_field'),
                  controller: nameController,
                  autofocus: true,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: '名前'),
                ),
                TextField(
                  key: const Key('note_collection_description_field'),
                  controller: descriptionController,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: '説明（任意）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('note_collection_create_save'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('作成'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => _dataSource.createCollection(
        type: type,
        name: nameController.text,
        parentId: parent?.id,
        description: descriptionController.text,
      ),
      '${type.label}を作成しました。',
    );
  }

  Future<void> _showEditDialog(NoteCollectionRecord collection) async {
    final nameController = TextEditingController(text: collection.name);
    final descriptionController =
        TextEditingController(text: collection.description);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${collection.type.label}を編集'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('note_collection_edit_name_field'),
                controller: nameController,
                autofocus: true,
                maxLength: 200,
                decoration: const InputDecoration(labelText: '名前'),
              ),
              TextField(
                controller: descriptionController,
                maxLength: 2000,
                decoration: const InputDecoration(labelText: '説明（任意）'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('note_collection_edit_save'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => _dataSource.updateCollection(
        id: collection.id,
        name: nameController.text,
        description: descriptionController.text,
      ),
      '${collection.type.label}を更新しました。',
    );
  }

  Future<void> _showMoveDialog(
    NoteCollectionSnapshot snapshot,
    NoteCollectionRecord collection,
  ) async {
    final parents = snapshot.validParentsFor(collection);
    int? parentId = collection.parentId;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${collection.name}を移動'),
          content: DropdownButtonFormField<int?>(
            key: const Key('note_collection_parent_field'),
            initialValue: parentId,
            decoration: const InputDecoration(labelText: '移動先'),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('ルート'),
              ),
              for (final parent in parents)
                DropdownMenuItem<int?>(
                  value: parent.id,
                  child: Text('${parent.type.label}: ${parent.name}'),
                ),
            ],
            onChanged: (value) => setDialogState(() => parentId = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('note_collection_move_save'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('移動'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => _dataSource.moveCollection(
        id: collection.id,
        parentId: parentId,
      ),
      'ノートブックを移動しました。',
    );
  }

  Future<void> _confirmDelete(NoteCollectionRecord collection) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${collection.name}を削除しますか？'),
        content: Text(
          collection.type == NoteCollectionType.notebook
              ? '配下のノートはゴミ箱へ移動します。この操作はEvernote側には影響しません。'
              : '配下にコレクションがある場合は、先に移動してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('note_collection_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await _mutate(
      () => _dataSource.deleteCollection(collection.id),
      '${collection.type.label}を削除しました。',
    );
  }

  List<_CollectionEntry> _flatten(NoteCollectionSnapshot snapshot) {
    final byParent = snapshot.collectionsByParent;
    final result = <_CollectionEntry>[];
    final visited = <int>{};

    void visit(int? parentId, int depth) {
      for (final collection
          in byParent[parentId] ?? const <NoteCollectionRecord>[]) {
        if (!visited.add(collection.id)) continue;
        result.add(_CollectionEntry(collection, depth));
        visit(collection.id, depth + 1);
      }
    }

    visit(null, 0);
    for (final collection in snapshot.collections) {
      if (visited.add(collection.id)) {
        result.add(_CollectionEntry(collection, 0));
        visit(collection.id, 1);
      }
    }
    return result;
  }

  IconData _iconFor(NoteCollectionType type) => switch (type) {
        NoteCollectionType.space => Icons.workspaces_outline,
        NoteCollectionType.stack => Icons.layers_outlined,
        NoteCollectionType.notebook => Icons.menu_book_outlined,
      };
}

class _CollectionEntry {
  const _CollectionEntry(this.collection, this.depth);

  final NoteCollectionRecord collection;
  final int depth;
}
