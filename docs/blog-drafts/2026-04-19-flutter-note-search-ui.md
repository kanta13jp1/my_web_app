---
title: "Flutterメモ一覧に検索UIを追加した — SearchBar + Supabase全文検索の実装"
tags: Flutter,Supabase,個人開発,buildinpublic,UI
published: true
---

# Flutterメモ一覧に検索UIを追加した

## 課題: メモが増えると探せない

ノート機能でメモが50件を超えると、スクロールで探すのが辛くなる。
Notionのような即時検索が必要だった。

## 実装方針

| 選択肢 | 採用 | 理由 |
|--------|------|------|
| クライアント側フィルタ | ✅ | 100件以下なら十分高速 |
| Supabase全文検索 (pg_trgm) | ✅ 併用 | 100件超に備えて |
| debounce 300ms | ✅ | 入力中の無駄クエリ削減 |

## Flutter 実装

```dart
// note_list_page.dart
class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final _searchController = SearchController();
  Timer? _debounce;
  String _query = '';
  List<Note> _allNotes = [];
  List<Note> _filteredNotes = [];

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = query.toLowerCase();
        _filteredNotes = _allNotes.where((note) {
          return note.title.toLowerCase().contains(_query) ||
              note.content.toLowerCase().contains(_query);
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchBar(
          controller: _searchController,
          hintText: 'メモを検索...',
          onChanged: _onSearchChanged,
          leading: const Icon(Icons.search),
          trailing: [
            if (_query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              ),
          ],
        ),
      ),
      body: ListView.builder(
        itemCount: _filteredNotes.length,
        itemBuilder: (context, index) => NoteCard(note: _filteredNotes[index]),
      ),
    );
  }
}
```

Flutter 3.10以降の `SearchBar` ウィジェットを使用。`TextField` より見た目が整っている。

## Supabase側: 全文検索 (100件超対応)

```sql
-- migration: add full-text search index
ALTER TABLE notes ADD COLUMN IF NOT EXISTS search_vector tsvector;

CREATE INDEX IF NOT EXISTS notes_search_idx
  ON notes USING gin(search_vector);

-- トリガーで自動更新
CREATE OR REPLACE FUNCTION update_notes_search_vector()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector := to_tsvector('japanese', COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.content, ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notes_search_trigger
  BEFORE INSERT OR UPDATE ON notes
  FOR EACH ROW EXECUTE FUNCTION update_notes_search_vector();
```

```typescript
// Edge Function (全文検索クエリ)
const { data } = await supabase
  .from('notes')
  .select('*')
  .textSearch('search_vector', query, { config: 'japanese' })
  .limit(50);
```

## ハイライト表示

検索ヒット箇所を黄色でハイライト:

```dart
Widget _buildHighlightedText(String text, String query) {
  if (query.isEmpty) return Text(text);

  final parts = text.split(RegExp(query, caseSensitive: false));
  final matches = RegExp(query, caseSensitive: false).allMatches(text);

  final spans = <TextSpan>[];
  int i = 0;
  for (final match in matches) {
    spans.add(TextSpan(text: parts[i]));
    spans.add(TextSpan(
      text: match.group(0),
      style: const TextStyle(
        backgroundColor: Color(0xFFFFEB3B),
        fontWeight: FontWeight.bold,
      ),
    ));
    i++;
  }
  if (i < parts.length) spans.add(TextSpan(text: parts[i]));

  return RichText(text: TextSpan(children: spans, style: DefaultTextStyle.of(context).style));
}
```

## まとめ

- **100件以下**: クライアント側フィルタで十分 (遅延なし)
- **100件超**: Supabase `pg_trgm` 全文検索に切り替え
- `SearchBar` ウィジェットで Material 3 準拠の見た目

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #buildinpublic #個人開発
