import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/note_tag_hierarchy_service.dart';
import 'note_list_page.dart';

class NoteTagsPage extends StatefulWidget {
  const NoteTagsPage({super.key, this.dataSource, this.supabaseClient});
  final NoteTagHierarchyDataSource? dataSource;
  final SupabaseClient? supabaseClient;
  @override
  State<NoteTagsPage> createState() => _NoteTagsPageState();
}

class _NoteTagsPageState extends State<NoteTagsPage> {
  late final NoteTagHierarchyDataSource _dataSource;
  NoteTagHierarchySnapshot? _snapshot;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ??
        SupabaseNoteTagHierarchyDataSource(
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
      final value = await _dataSource.load();
      if (!mounted) return;
      setState(() {
        _snapshot = value;
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
    String message,
  ) async {
    setState(() => _saving = true);
    try {
      await operation();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('タグ操作に失敗しました: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      key: const Key('note_tags_page'),
      appBar: AppBar(
        title: const Text('階層タグ'),
        actions: [
          IconButton(
            key: const Key('note_tags_refresh'),
            onPressed: _saving ? null : _reload,
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: snapshot == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('note_tags_add_root'),
              onPressed: _saving ? null : () => _editName(),
              icon: const Icon(Icons.add),
              label: const Text('ルートタグ'),
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
                  ? const Center(child: Text('タグ情報がありません'))
                  : LayoutBuilder(
                      builder: (context, size) {
                        final tree = _tree(snapshot);
                        if (size.maxWidth < 820) return tree;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 300, child: _summary(snapshot)),
                            const VerticalDivider(width: 1),
                            Expanded(child: tree),
                          ],
                        );
                      },
                    ),
    );
  }

  Widget _summary(NoteTagHierarchySnapshot snapshot) {
    final imported = snapshot.tags.where((tag) => tag.isImported).length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('タグ移行', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('合計: ${snapshot.tags.length}'),
                Text('Evernote原本: $imported'),
                Text('本サイト作成: ${snapshot.tags.length - imported}'),
                const SizedBox(height: 12),
                Text(
                  snapshot.evernoteSourceDeleted
                      ? '原本削除確認済み'
                      : '移行済み原本は証跡保護中',
                ),
                const SizedBox(height: 12),
                const Text(
                  '「このタグのみ」は子タグを除外し、'
                  '「子タグも含む」は全子孫のノートも表示します。',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tree(NoteTagHierarchySnapshot snapshot) {
    final entries = _flatten(snapshot);
    return ListView(
      key: const Key('note_tags_tree'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (entries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('タグはまだありません。'),
            ),
          ),
        for (final entry in entries)
          _tagCard(snapshot, entry.tag, entry.depth),
      ],
    );
  }

  Widget _tagCard(
    NoteTagHierarchySnapshot snapshot,
    NoteTagRecord tag,
    int depth,
  ) {
    final locked = snapshot.isLocked(tag);
    return Padding(
      padding: EdgeInsets.only(left: (depth * 20).clamp(0, 120).toDouble()),
      child: Card(
        key: ValueKey<String>('note_tag_${tag.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    depth == 0
                        ? Icons.sell_outlined
                        : Icons.subdirectory_arrow_right,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tag.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Chip(
                    label: Text('${tag.noteCount}件'),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (locked)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Tooltip(
                        message: 'Evernote原本削除確認まで編集不可',
                        child: Icon(Icons.lock_outline, size: 18),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    key: ValueKey<String>(
                      'note_tag_exact_${tag.id}',
                    ),
                    onPressed: () => _open(tag, false),
                    child: const Text('このタグのみ'),
                  ),
                  OutlinedButton(
                    key: ValueKey<String>(
                      'note_tag_nested_${tag.id}',
                    ),
                    onPressed: () => _open(tag, true),
                    child: const Text('子タグも含む'),
                  ),
                  TextButton(
                    onPressed:
                        _saving ? null : () => _editName(parentId: tag.id),
                    child: const Text('子タグ'),
                  ),
                  TextButton(
                    onPressed:
                        _saving || locked ? null : () => _editName(tag: tag),
                    child: const Text('名前'),
                  ),
                  TextButton(
                    onPressed: _saving || locked
                        ? null
                        : () => _move(snapshot, tag),
                    child: const Text('移動'),
                  ),
                  TextButton(
                    onPressed: _saving || locked
                        ? null
                        : () => _delete(snapshot, tag),
                    child: const Text('削除'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_TagDepth> _flatten(NoteTagHierarchySnapshot snapshot) {
    final result = <_TagDepth>[];
    final visited = <int>{};
    final byParent = snapshot.tagsByParent;
    void add(NoteTagRecord tag, int depth) {
      if (!visited.add(tag.id)) return;
      result.add(_TagDepth(tag, depth));
      for (final child in byParent[tag.id] ?? const <NoteTagRecord>[]) {
        add(child, depth + 1);
      }
    }
    for (final root in byParent[null] ?? const <NoteTagRecord>[]) {
      add(root, 0);
    }
    for (final tag in snapshot.tags) {
      if (!visited.contains(tag.id)) add(tag, 0);
    }
    return result;
  }

  Future<void> _open(NoteTagRecord tag, bool nested) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteListPage(
          initialTag: tag.name,
          initialTagId: tag.id,
          includeNestedTags: nested,
        ),
      ),
    );
  }

  Future<void> _editName({NoteTagRecord? tag, int? parentId}) async {
    final controller = TextEditingController(text: tag?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tag == null ? 'タグを追加' : 'タグ名を変更'),
        content: TextField(
          key: const Key('note_tag_name_field'),
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'タグ名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('note_tag_name_save'),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await _mutate(
      tag == null
          ? () => _dataSource.createTag(name: name, parentId: parentId)
          : () => _dataSource.renameTag(id: tag.id, name: name),
      tag == null ? 'タグを追加しました。' : 'タグ名を変更しました。',
    );
  }

  Future<void> _move(
    NoteTagHierarchySnapshot snapshot,
    NoteTagRecord tag,
  ) async {
    final blocked = snapshot.descendantIds(tag.id);
    final candidates =
        snapshot.tags.where((item) => !blocked.contains(item.id)).toList();
    var selected = tag.parentId ?? 0;
    final target = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('「${tag.name}」を移動'),
          content: DropdownButtonFormField<int>(
            key: const Key('note_tag_parent_field'),
            initialValue: selected,
            items: [
              const DropdownMenuItem(value: 0, child: Text('ルート')),
              for (final candidate in candidates)
                DropdownMenuItem(
                  value: candidate.id,
                  child: Text(candidate.name),
                ),
            ],
            onChanged: (value) {
              if (value != null) update(() => selected = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              key: const Key('note_tag_move_save'),
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('移動'),
            ),
          ],
        ),
      ),
    );
    if (target == null) return;
    await _mutate(
      () => _dataSource.moveTag(
        id: tag.id,
        parentId: target == 0 ? null : target,
      ),
      'タグ階層を更新しました。',
    );
  }

  Future<void> _delete(
    NoteTagHierarchySnapshot snapshot,
    NoteTagRecord tag,
  ) async {
    if (snapshot.tags.any((item) => item.parentId == tag.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('子タグを先に移動または削除してください。')),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('「${tag.name}」を削除しますか？'),
        content: const Text('タグ割り当ては削除されますが、ノート本文は残ります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            key: const Key('note_tag_delete_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _mutate(() => _dataSource.deleteTag(tag.id), 'タグを削除しました。');
  }
}

class _TagDepth {
  const _TagDepth(this.tag, this.depth);
  final NoteTagRecord tag;
  final int depth;
}
