---
title: FlutterとSupabaseでNotionのDatabase機能を実装した話 — jsonbカラムで動的スキーマを作る
emoji: 📊
type: tech
topics: [flutter, supabase, dart, notion]
published: false
---

# FlutterとSupabaseでNotionのDatabase機能を実装した話

## はじめに

Notionの最大の差別化機能のひとつが「Database」です。表形式でデータを管理し、カンバン・カレンダー・ギャラリーなど複数のビューで同じデータを見られる機能です。

自分株式会社（[https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)）では、Notion・Evernote・Slack・MoneyForwardなど21社の競合を超えるAI統合プラットフォームを目指しています。このプロジェクトの一環として、FlutterとSupabaseを使ってNotionのDatabase機能相当を実装しました。

本記事では、**動的なカラム定義をjsonbで管理する手法**と、**Flutter DataTableウィジェットによるインライン編集**の実装を解説します。

## 技術スタック

- Flutter Web (Dart)
- Supabase (PostgreSQL + Row Level Security)
- Supabase Flutter SDK

## 設計方針

Notionのデータベースは「スキーマが動的に変わる」という点が特徴です。ユーザーがカラム（プロパティ）を自由に追加・削除できます。

通常のRDBでこれを実現しようとすると、`ALTER TABLE`が必要になります。しかしSupabaseの`jsonb`型を使えば、スキーマ変更なしに動的なカラム定義を実現できます。

### テーブル設計

```sql
-- テーブル（データベース）定義
CREATE TABLE user_tables (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title      text        NOT NULL DEFAULT '新しいデータベース',
  icon       text        DEFAULT '📊',
  columns    jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- カラム定義
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

-- 行データ
CREATE TABLE user_table_rows (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  table_id   uuid        REFERENCES user_tables(id) ON DELETE CASCADE NOT NULL,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  row_data   jsonb       NOT NULL DEFAULT '{}'::jsonb,  -- 実際のデータ
  sort_order int         DEFAULT 0,
  created_at timestamptz DEFAULT now() NOT NULL
);
```

`columns`フィールドは以下のような構造のJSON配列です：

```json
[
  {"id": "col_abc123", "name": "タイトル", "type": "text", "options": []},
  {"id": "col_def456", "name": "ステータス", "type": "select", "options": ["未着手", "進行中", "完了"]},
  {"id": "col_ghi789", "name": "期限", "type": "date", "options": []},
  {"id": "col_jkl012", "name": "完了", "type": "checkbox", "options": []}
]
```

`row_data`フィールドはカラムIDをキーにした辞書型です：

```json
{
  "col_abc123": "企画書を作成する",
  "col_def456": "進行中",
  "col_ghi789": "2026-04-01",
  "col_jkl012": "false"
}
```

この設計により、**スキーマ変更なし**でカラムの追加・削除が可能になります。

## Row Level Security

ユーザーは自分のデータのみアクセスできるようにRLSを設定します：

```sql
ALTER TABLE user_tables ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_tables_own" ON user_tables
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

## Flutter実装

### モデルクラス

```dart
class _ColDef {
  String id;
  String name;
  String type; // text | number | date | checkbox | select
  List<String> options;

  factory _ColDef.fromJson(Map<String, dynamic> j) => _ColDef(
        id: j['id'] as String,
        name: j['name'] as String,
        type: j['type'] as String? ?? 'text',
        options: (j['options'] as List?)?.map((e) => e as String).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'options': options,
      };
}
```

### データ取得

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

  // row_data (jsonb) を展開して _id と統合
  setState(() {
    _rows = (data as List).map((e) {
      final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
      final rd = Map<String, dynamic>.from(
          m['row_data'] as Map<String, dynamic>? ?? {},
      );
      return {'_id': m['id'], ...rd};
    }).toList();
  });
}
```

### Flutter DataTableによる表示

```dart
DataTable(
  columns: [
    const DataColumn(label: Text('#')),
    ...cols.map(
      (col) => DataColumn(
        label: Row(
          children: [
            Icon(_colIcon(col.type), size: 14),
            const SizedBox(width: 4),
            Text(col.name),
          ],
        ),
      ),
    ),
    const DataColumn(label: SizedBox(width: 32)),
  ],
  rows: List.generate(_rows.length, (i) {
    return DataRow(
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
    );
  }),
)
```

### 型に応じたセル表示

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
        child: Text(value.isEmpty ? '—' : value, overflow: TextOverflow.ellipsis),
      );
  }
}
```

## 詰まったポイント

### 1. `require_trailing_commas` Lint エラー

`flutter analyze`でエラーが出ました。Dartでは引数が複数行にまたがる場合、最後の引数の後にカンマが必要です：

```dart
// NG
final rd = Map<String, dynamic>.from(
    m['row_data'] as Map<String, dynamic>? ?? {});

// OK
final rd = Map<String, dynamic>.from(
    m['row_data'] as Map<String, dynamic>? ?? {},
);
```

### 2. DropdownButtonFormField の deprecated API

`value:` → `initialValue:` に変更が必要でした：

```dart
// NG (deprecated)
DropdownButtonFormField<String>(value: colType, ...)

// OK
DropdownButtonFormField<String>(initialValue: colType, ...)
```

### 3. jsonb の動的キーアクセス

Supabaseから返ってくる`jsonb`フィールドは`Map<String, dynamic>`として扱えます。カラムIDをキーにして値を取得・更新します：

```dart
// 更新時
await _db
    .from('user_table_rows')
    .update({'row_data': newData}).eq('id', rowId);
```

## まとめ

- `jsonb`カラムを使うことで、スキーマ変更なしに動的なカラム定義を実現
- SupabaseのRLSで安全なデータ分離を実現
- FlutterのDataTableウィジェットで横スクロール対応の表形式UIを構築
- カラム型（text/number/date/checkbox/select）に応じた適切なUI表示

Notionのような高度なDatabase機能の「シンプルな版」として十分使えるレベルになりました。次のステップはGalleryビューやCalendarビューの追加です。

---

URL: [https://my-web-app-b67f4.web.app/table-data](https://my-web-app-b67f4.web.app/table-data)
GitHubで開発状況をビルド・イン・パブリックで公開中 🚀 #FlutterWeb #Supabase #buildinpublic
