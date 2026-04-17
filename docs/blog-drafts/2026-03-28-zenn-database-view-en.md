---
title: "Notion-Like Dynamic Database in Flutter: JSONB Schema + DataTable Inline Edit"
tags: Flutter,Supabase,buildinpublic,Dart,PostgreSQL
published: true
---

# Notion-Like Dynamic Database in Flutter: JSONB Schema + DataTable Inline Edit

## What We Built

[自分株式会社](https://my-web-app-b67f4.web.app/) competes with Notion. One of Notion's core differentiators is the **Database** view — spreadsheet-like with dynamic columns users can add/remove at runtime.

The challenge: a normal relational table has a fixed schema. Adding a column requires `ALTER TABLE`. For a multi-tenant SaaS where each user defines their own columns, that's not viable.

Solution: store the column schema in `jsonb` and row data in `jsonb`. No `ALTER TABLE` ever.

---

## Schema: Two Tables

```sql
-- Table (database) definition
CREATE TABLE user_tables (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title      text        NOT NULL DEFAULT 'New Database',
  icon       text        DEFAULT '📊',
  columns    jsonb       NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- Row data
CREATE TABLE user_table_rows (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  table_id   uuid        REFERENCES user_tables(id) ON DELETE CASCADE NOT NULL,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  row_data   jsonb       NOT NULL DEFAULT '{}'::jsonb,
  sort_order int         DEFAULT 0,
  created_at timestamptz DEFAULT now() NOT NULL
);
```

`columns` stores an array of column definitions. `row_data` stores values keyed by column ID.

---

## Data Structures

Column definition (stored in `user_tables.columns`):

```json
[
  {"id": "col_abc123", "name": "Title",    "type": "text",     "options": []},
  {"id": "col_def456", "name": "Status",   "type": "select",   "options": ["Todo", "In Progress", "Done"]},
  {"id": "col_ghi789", "name": "Due Date", "type": "date",     "options": []},
  {"id": "col_jkl012", "name": "Done",     "type": "checkbox", "options": []}
]
```

Row data (stored in `user_table_rows.row_data`):

```json
{
  "col_abc123": "Write the proposal",
  "col_def456": "In Progress",
  "col_ghi789": "2026-04-01",
  "col_jkl012": "false"
}
```

Column IDs are stable. Renaming a column updates only the `columns` array — row data doesn't change. Deleting a column removes the definition; the orphaned keys in `row_data` are ignored (JSONB allows this).

---

## RLS

```sql
ALTER TABLE user_tables ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_tables_own" ON user_tables
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

Same policy on `user_table_rows`. Each user sees and writes only their own tables.

---

## Flutter: Column Definition Model

```dart
class _ColDef {
  String id;
  String name;
  String type; // text | number | date | checkbox | select
  List<String> options;

  factory _ColDef.fromJson(Map<String, dynamic> j) => _ColDef(
        id:      j['id']   as String,
        name:    j['name'] as String,
        type:    j['type'] as String? ?? 'text',
        options: (j['options'] as List?)?.map((e) => e as String).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id':      id,
        'name':    name,
        'type':    type,
        'options': options,
      };
}
```

---

## Flutter: Loading Rows

The key pattern: merge `row_data` (JSONB) with the row's own `id` into a flat map:

```dart
Future<void> _loadRows(String tableId) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) return;

  final data = await _db
      .from('user_table_rows')
      .select('id, row_data, sort_order')
      .eq('table_id', tableId)
      .eq('user_id', uid)
      .order('sort_order')
      .order('created_at');

  setState(() {
    _rows = (data as List).map((e) {
      final m  = Map<String, dynamic>.from(e as Map<String, dynamic>);
      final rd = Map<String, dynamic>.from(
          m['row_data'] as Map<String, dynamic>? ?? {},
      );
      return {'_id': m['id'], ...rd};  // spread merge
    }).toList();
  });
}
```

`{'_id': m['id'], ...rd}` — prefix the row UUID with `_id` (underscore prevents collision with column IDs like `col_abc123`), then spread all column values. Result: a flat map where `_rows[i][col.id]` returns the cell value.

---

## Flutter: DataTable with Type-Based Cells

```dart
DataTable(
  columns: [
    const DataColumn(label: Text('#')),
    ...cols.map((col) => DataColumn(
      label: Row(children: [
        Icon(_colIcon(col.type), size: 14),
        const SizedBox(width: 4),
        Text(col.name),
      ]),
    )),
    const DataColumn(label: SizedBox(width: 32)),
  ],
  rows: List.generate(_rows.length, (i) => DataRow(
    cells: [
      DataCell(Text('${i + 1}')),
      ...cols.map((col) => DataCell(
        _buildCell(_rows[i][col.id]?.toString() ?? '', col),
        onTap: () => _editCell(i, col),
      )),
      DataCell(IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteRow(i),
      )),
    ],
  )),
)
```

Each cell has `onTap: () => _editCell(i, col)` — opens a dialog with the appropriate input for the column type.

---

## Type-Based Cell Rendering

```dart
Widget _buildCell(String value, _ColDef col) {
  switch (col.type) {
    case 'checkbox':
      return Checkbox(value: value == 'true', onChanged: null);
    case 'date':
      return Text(value.isEmpty ? '—' : value);
    default:
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(
          value.isEmpty ? '—' : value,
          overflow: TextOverflow.ellipsis,
        ),
      );
  }
}
```

`onChanged: null` makes the `Checkbox` read-only (tap opens the edit dialog via `DataCell.onTap`). `ConstrainedBox(maxWidth: 200)` prevents long text from blowing out column widths.

---

## Lint Fixes

### `require_trailing_commas`

Multi-line function arguments need a trailing comma:

```dart
// Wrong
final rd = Map<String, dynamic>.from(
    m['row_data'] as Map<String, dynamic>? ?? {});

// Correct
final rd = Map<String, dynamic>.from(
    m['row_data'] as Map<String, dynamic>? ?? {},
);
```

### `DropdownButtonFormField` deprecated API

```dart
// Deprecated
DropdownButtonFormField<String>(value: colType, ...)

// Current
DropdownButtonFormField<String>(initialValue: colType, ...)
```

---

## Why JSONB Over a Separate Schema Table

Alternative: a `table_columns` relational table with one row per column.

| Approach | Pro | Con |
|----------|-----|-----|
| JSONB in `columns` | One query to get table + schema | No FK constraints on column IDs |
| Separate `table_columns` table | FK integrity, easier SQL filtering | Extra join on every query |

For a user-facing dynamic schema where columns are defined and read together, JSONB wins on simplicity. For analytics querying across columns, a relational approach is better.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/table-data)

#buildinpublic #Flutter #Supabase #Dart #PostgreSQL
