import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// テーブルデータビュー — Notion Database 相当
///
/// ユーザーが自由にカラムを定義して表形式でデータを管理できる。
/// - テーブル（データベース）の作成・削除
/// - カラムの追加・削除（text / number / date / checkbox / select）
/// - 行の追加・編集・削除
/// - データは Supabase の user_tables / user_table_rows テーブルに保存
class TableDataPage extends StatefulWidget {
  const TableDataPage({super.key});

  @override
  State<TableDataPage> createState() => _TableDataPageState();
}

// ---------- モデル ----------

class _ColDef {
  String id;
  String name;
  String type; // text | number | date | checkbox | select
  List<String> options; // select 用

  _ColDef({
    required this.id,
    required this.name,
    this.type = 'text',
    List<String>? options,
  }) : options = options ?? [];

  factory _ColDef.fromJson(Map<String, dynamic> j) => _ColDef(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String? ?? 'text',
        options:
            (j['options'] as List?)?.map((e) => e as String).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'options': options,
      };
}

class _TableMeta {
  final String id;
  String title;
  String icon;
  List<_ColDef> columns;

  _TableMeta({
    required this.id,
    required this.title,
    this.icon = '📊',
    List<_ColDef>? columns,
  }) : columns = columns ?? [];

  factory _TableMeta.fromJson(Map<String, dynamic> j) => _TableMeta(
        id: j['id'] as String,
        title: j['title'] as String,
        icon: j['icon'] as String? ?? '📊',
        columns: (j['columns'] as List?)
                ?.map((c) => _ColDef.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ---------- ページ ----------

class _TableDataPageState extends State<TableDataPage> {
  final _db = Supabase.instance.client;

  bool _loadingTables = true;
  List<_TableMeta> _tables = [];
  _TableMeta? _selected; // 現在表示中のテーブル

  bool _loadingRows = false;
  List<Map<String, dynamic>> _rows = []; // row_data + id

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  // ---- データ取得 ----

  Future<void> _loadTables() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loadingTables = false);
      return;
    }
    try {
      final data = await _db
          .from('user_tables')
          .select('id, title, icon, columns')
          .eq('user_id', uid)
          .order('created_at');
      if (mounted) {
        setState(() {
          _tables = (data as List)
              .map((e) => _TableMeta.fromJson(e as Map<String, dynamic>))
              .toList();
          _loadingTables = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTables = false);
    }
  }

  Future<void> _loadRows(String tableId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _loadingRows = true);
    try {
      final data = await _db
          .from('user_table_rows')
          .select('id, row_data, sort_order')
          .eq('table_id', tableId)
          .eq('user_id', uid)
          .order('sort_order')
          .order('created_at');
      if (mounted) {
        setState(() {
          _rows = (data as List).map((e) {
            final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
            final rd = Map<String, dynamic>.from(
              m['row_data'] as Map<String, dynamic>? ?? {},
            );
            return {'_id': m['id'], ...rd};
          }).toList();
          _loadingRows = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRows = false);
    }
  }

  // ---- テーブル操作 ----

  Future<void> _createTable() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final titleCtrl = TextEditingController(text: '新しいデータベース');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しいデータベース'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(labelText: 'データベース名'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await _db.from('user_tables').insert({
        'user_id': uid,
        'title':
            titleCtrl.text.trim().isEmpty ? '新しいデータベース' : titleCtrl.text.trim(),
        'icon': '📊',
        'columns': [
          {'id': 'col_title', 'name': 'タイトル', 'type': 'text', 'options': []},
        ],
      }).select('id, title, icon, columns');
      final meta = _TableMeta.fromJson(
        (result as List).first as Map<String, dynamic>,
      );
      if (mounted) {
        setState(() {
          _tables.add(meta);
          _selected = meta;
          _rows = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成失敗: $e')),
        );
      }
    }
  }

  Future<void> _deleteTable(_TableMeta table) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('データベースを削除'),
        content: Text('「${table.title}」とそのデータをすべて削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.from('user_tables').delete().eq('id', table.id).select();
      if (mounted) {
        setState(() {
          _tables.removeWhere((t) => t.id == table.id);
          if (_selected?.id == table.id) {
            _selected = null;
            _rows = [];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _renameTable(_TableMeta table) async {
    final ctrl = TextEditingController(text: table.title);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('名前を変更'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'データベース名'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      await _db
          .from('user_tables')
          .update({'title': ctrl.text.trim()}).eq('id', table.id);
      if (mounted) {
        setState(() {
          table.title = ctrl.text.trim();
          if (_selected?.id == table.id) _selected = table;
        });
      }
    } catch (_) {}
  }

  // ---- カラム操作 ----

  Future<void> _addColumn() async {
    if (_selected == null) return;
    final nameCtrl = TextEditingController();
    String colType = 'text';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('カラムを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'カラム名'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: colType,
                decoration: const InputDecoration(labelText: '型'),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('テキスト')),
                  DropdownMenuItem(value: 'number', child: Text('数値')),
                  DropdownMenuItem(value: 'date', child: Text('日付')),
                  DropdownMenuItem(value: 'checkbox', child: Text('チェックボックス')),
                  DropdownMenuItem(value: 'select', child: Text('セレクト')),
                ],
                onChanged: (v) => setSt(() => colType = v ?? 'text'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx2, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final newCol = _ColDef(
      id: 'col_${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim(),
      type: colType,
    );
    _selected!.columns.add(newCol);
    try {
      await _db.from('user_tables').update({
        'columns': _selected!.columns.map((c) => c.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _selected!.id);
      if (mounted) setState(() {});
    } catch (_) {
      _selected!.columns.removeLast();
    }
  }

  Future<void> _deleteColumn(_ColDef col) async {
    if (_selected == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カラムを削除'),
        content: Text('「${col.name}」カラムとその全データを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _selected!.columns.removeWhere((c) => c.id == col.id);
    try {
      await _db.from('user_tables').update({
        'columns': _selected!.columns.map((c) => c.toJson()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _selected!.id);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  // ---- 行操作 ----

  Future<void> _addRow() async {
    if (_selected == null) return;
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final emptyData = <String, dynamic>{};
    for (final col in _selected!.columns) {
      emptyData[col.id] = col.type == 'checkbox' ? 'false' : '';
    }
    try {
      final result = await _db.from('user_table_rows').insert({
        'table_id': _selected!.id,
        'user_id': uid,
        'row_data': emptyData,
        'sort_order': _rows.length,
      }).select('id, row_data');
      final newRow = Map<String, dynamic>.from(
        (result as List).first as Map<String, dynamic>,
      );
      final rd = Map<String, dynamic>.from(
        newRow['row_data'] as Map<String, dynamic>? ?? {},
      );
      if (mounted) {
        setState(() {
          _rows.add({'_id': newRow['id'], ...rd});
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('行の追加に失敗: $e')),
        );
      }
    }
  }

  Future<void> _deleteRow(int index) async {
    final row = _rows[index];
    try {
      await _db
          .from('user_table_rows')
          .delete()
          .eq('id', row['_id'] as String)
          .select();
      if (mounted) setState(() => _rows.removeAt(index));
    } catch (_) {}
  }

  Future<void> _editCell(int rowIndex, _ColDef col) async {
    final row = _rows[rowIndex];
    final currentVal = row[col.id]?.toString() ?? '';

    if (col.type == 'checkbox') {
      final newVal = currentVal != 'true';
      await _updateCell(rowIndex, col.id, newVal ? 'true' : 'false');
      return;
    }

    if (col.type == 'date') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _tryParseDate(currentVal) ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      await _updateCell(
        rowIndex,
        col.id,
        '${picked.year}-${_pad(picked.month)}-${_pad(picked.day)}',
      );
      return;
    }

    if (col.type == 'select' && col.options.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(col.name),
          children: col.options
              .map(
                (o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, o),
                  child: Text(o),
                ),
              )
              .toList(),
        ),
      );
      if (choice == null) return;
      await _updateCell(rowIndex, col.id, choice);
      return;
    }

    // text / number / select(no options)
    final ctrl = TextEditingController(text: currentVal);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(col.name),
        content: TextField(
          controller: ctrl,
          keyboardType:
              col.type == 'number' ? TextInputType.number : TextInputType.text,
          autofocus: true,
          decoration: InputDecoration(
            hintText: col.type == 'number' ? '0' : 'テキストを入力',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _updateCell(rowIndex, col.id, ctrl.text);
  }

  Future<void> _updateCell(int rowIndex, String colId, String value) async {
    final row = _rows[rowIndex];
    final rowId = row['_id'] as String;
    final newData = Map<String, dynamic>.from(row)
      ..remove('_id')
      ..[colId] = value;
    try {
      await _db
          .from('user_table_rows')
          .update({'row_data': newData}).eq('id', rowId);
      if (mounted) {
        setState(() {
          _rows[rowIndex] = {'_id': rowId, ...newData};
        });
      }
    } catch (_) {}
  }

  // ---- ユーティリティ ----

  DateTime? _tryParseDate(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  IconData _colIcon(String type) {
    switch (type) {
      case 'number':
        return Icons.tag;
      case 'date':
        return Icons.calendar_today;
      case 'checkbox':
        return Icons.check_box_outline_blank;
      case 'select':
        return Icons.arrow_drop_down_circle_outlined;
      default:
        return Icons.text_fields;
    }
  }

  // ---- UI ----

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: _selected == null
            ? const Text('データベース')
            : Row(
                children: [
                  Text(_selected!.icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selected!.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
        leading: _selected != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selected = null;
                  _rows = [];
                }),
              )
            : null,
        actions: _selected != null
            ? [
                IconButton(
                  icon: const Icon(Icons.add_box_outlined),
                  tooltip: 'カラムを追加',
                  onPressed: _addColumn,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '行を追加',
                  onPressed: _addRow,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '新しいデータベース',
                  onPressed: _createTable,
                ),
              ],
      ),
      body:
          _selected == null ? _buildTableList(isDark) : _buildTableView(isDark),
      floatingActionButton: _selected == null
          ? FloatingActionButton.extended(
              onPressed: _createTable,
              icon: const Icon(Icons.add),
              label: const Text('新しいデータベース'),
            )
          : FloatingActionButton(
              onPressed: _addRow,
              tooltip: '行を追加',
              child: const Icon(Icons.add),
            ),
    );
  }

  // ---- テーブル一覧 ----

  Widget _buildTableList(bool isDark) {
    if (_loadingTables) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.table_chart_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'データベースがありません',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Notionのような表形式でデータを管理できます',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createTable,
              icon: const Icon(Icons.add),
              label: const Text('最初のデータベースを作成'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTables,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tables.length,
        itemBuilder: (context, i) {
          final t = _tables[i];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
            ),
            child: ListTile(
              leading: Text(t.icon, style: const TextStyle(fontSize: 28)),
              title: Text(
                t.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${t.columns.length} カラム',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') _renameTable(t);
                  if (v == 'delete') _deleteTable(t);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('名前を変更')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('削除', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  _selected = t;
                  _rows = [];
                });
                _loadRows(t.id);
              },
            ),
          );
        },
      ),
    );
  }

  // ---- テーブルビュー ----

  Widget _buildTableView(bool isDark) {
    if (_loadingRows) {
      return const Center(child: CircularProgressIndicator());
    }
    final cols = _selected!.columns;
    if (cols.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('カラムがありません'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addColumn,
              icon: const Icon(Icons.add),
              label: const Text('最初のカラムを追加'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ヘッダー情報
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.table_rows_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${_rows.length} 件',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${cols.length} カラム',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // テーブル本体
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                  columnSpacing: 12,
                  columns: [
                    // 行番号
                    DataColumn(
                      label: Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    // カラムヘッダー
                    ...cols.map(
                      (col) => DataColumn(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_colIcon(col.type), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              col.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _deleteColumn(col),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 削除列
                    const DataColumn(label: SizedBox(width: 32)),
                  ],
                  rows: List.generate(_rows.length, (i) {
                    final row = _rows[i];
                    return DataRow(
                      cells: [
                        // 行番号
                        DataCell(
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ),
                        ),
                        // データセル
                        ...cols.map((col) {
                          final val = row[col.id]?.toString() ?? '';
                          return DataCell(
                            _buildCell(val, col),
                            onTap: () => _editCell(i, col),
                          );
                        }),
                        // 削除ボタン
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.red.shade300,
                            onPressed: () => _deleteRow(i),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        // 行追加フッター
        InkWell(
          onTap: _addRow,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  size: 18,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '行を追加',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(String value, _ColDef col) {
    switch (col.type) {
      case 'checkbox':
        return Checkbox(
          value: value == 'true',
          onChanged: null, // tap は DataCell.onTap で処理
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      case 'date':
        return Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            color: value.isEmpty
                ? Theme.of(context).colorScheme.outlineVariant
                : null,
            fontSize: 13,
          ),
        );
      case 'number':
        return Text(
          value.isEmpty ? '—' : value,
          style: TextStyle(
            color: value.isEmpty
                ? Theme.of(context).colorScheme.outlineVariant
                : null,
            fontSize: 13,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      default:
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              color: value.isEmpty
                  ? Theme.of(context).colorScheme.outlineVariant
                  : null,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
    }
  }
}
