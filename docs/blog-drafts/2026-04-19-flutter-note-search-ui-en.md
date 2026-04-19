---
title: "Adding Search UI to a Flutter Notes List — SearchBar + Supabase Full-Text Search"
tags: Flutter,Supabase,buildinpublic,webdev,UI
published: false
---

# Adding Search UI to a Flutter Notes List

## The Problem: Notes Become Unsearchable Past 50

Once a note list exceeds 50 items, scrolling to find something breaks the user flow. The fix: instant search, like Notion.

## Implementation Strategy

| Approach | Used | Why |
|----------|------|-----|
| Client-side filter | ✅ | Fast enough for ≤100 notes |
| Supabase full-text search (pg_trgm) | ✅ combined | Ready for 100+ notes |
| 300ms debounce | ✅ | Avoids queries on every keystroke |

## Flutter Implementation

```dart
// note_list_page.dart
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
          hintText: 'Search notes...',
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

Using Flutter 3.10+'s `SearchBar` widget — cleaner than a plain `TextField` for this use case.

## Supabase Side: Full-Text Search for Scale

```sql
-- Add tsvector column and GIN index
ALTER TABLE notes ADD COLUMN IF NOT EXISTS search_vector tsvector;
CREATE INDEX IF NOT EXISTS notes_search_idx ON notes USING gin(search_vector);

-- Auto-update trigger
CREATE OR REPLACE FUNCTION update_notes_search_vector()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector := to_tsvector(
    'simple',
    COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.content, '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notes_search_trigger
  BEFORE INSERT OR UPDATE ON notes
  FOR EACH ROW EXECUTE FUNCTION update_notes_search_vector();
```

```typescript
// Edge Function query
const { data } = await supabase
  .from('notes')
  .select('*')
  .textSearch('search_vector', query)
  .limit(50);
```

Switch from client filter to this when the note count grows past 100.

## Highlight Matches in Results

```dart
Widget _buildHighlightedText(String text, String query) {
  if (query.isEmpty) return Text(text);

  final spans = <TextSpan>[];
  final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
  int last = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(0),
      style: const TextStyle(
        backgroundColor: Color(0xFFFFEB3B),
        fontWeight: FontWeight.bold,
      ),
    ));
    last = match.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

  return RichText(
    text: TextSpan(children: spans, style: DefaultTextStyle.of(context).style),
  );
}
```

## Two-Tier Approach

- **≤100 notes**: client-side filter, zero latency, no network call
- **100+ notes**: Supabase `textSearch` with GIN index

The client filter is the default; the Supabase path is the fallback that activates when the local list gets large. Both use the same UI — the switch is invisible to the user.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #buildinpublic #webdev
