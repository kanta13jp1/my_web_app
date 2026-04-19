---
title: "Adding Notion-Style Tags to a Flutter Note App with Supabase text[] Arrays"
tags: Flutter,Supabase,buildinpublic,webdev,Notion
published: false
---

# Adding Notion-Style Tags to a Flutter Note App with Supabase

## The Schema: text[] with GIN Index

```sql
ALTER TABLE notes ADD COLUMN tags text[] DEFAULT '{}';
CREATE INDEX idx_notes_tags ON notes USING GIN(tags);
```

PostgreSQL's array column handles tags without a join table. GIN index makes array searches fast.

## Array Query Patterns

```sql
-- Single tag filter
SELECT * FROM notes WHERE 'work' = ANY(tags);

-- AND filter (note has all specified tags)
SELECT * FROM notes WHERE tags @> ARRAY['work', 'project'];

-- Prefix search across all tags
SELECT * FROM notes WHERE EXISTS (
  SELECT 1 FROM unnest(tags) t WHERE t LIKE 'wor%'
);
```

## AI Tag Suggestions via ai-hub

```typescript
// ai-hub/index.ts
case "tags.suggest": {
  const { text, existing_tags } = params;
  const response = await groq.chat.completions.create({
    model: "llama-3.3-70b-versatile",
    messages: [{
      role: "user",
      content: `Suggest 3-5 tags for this text.
Existing tags: ${existing_tags.join(', ')}
Text: ${text}
Return JSON: {"tags": ["tag1", "tag2", ...]}`
    }],
    response_format: { type: "json_object" },
  });
  return JSON.parse(response.choices[0].message.content);
}
```

Groq's llama-3.3-70b: free tier, low latency, reliable JSON output.

## Flutter: Tag Chip Input

```dart
class TagInputField extends StatefulWidget {
  final List<String> initialTags;
  final String noteContent;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          children: _tags.map((tag) => Chip(
            label: Text('#$tag'),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => _removeTag(tag),
            backgroundColor: const Color(0xFF1E3A5F),
          )).toList(),
        ),
        TextField(
          controller: _controller,
          decoration: const InputDecoration(hintText: 'Add tag (Enter to confirm)'),
          onSubmitted: _addTag,
        ),
        if (_tags.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Suggest tags with AI'),
            onPressed: _suggestTags,
          ),
      ],
    );
  }

  Future<void> _suggestTags() async {
    final response = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'tags.suggest',
        'text': widget.noteContent,
        'existing_tags': _tags,
      },
    );
    setState(() => _suggestedTags =
        List<String>.from(response.data['tags'] ?? []));
  }
}
```

## Supabase Read/Write

```dart
// Save tags
await Supabase.instance.client
    .from('notes')
    .update({'tags': tags})
    .eq('id', noteId);

// Filter by tag
final notes = await Supabase.instance.client
    .from('notes')
    .select()
    .contains('tags', [selectedTag])
    .order('updated_at', ascending: false);
```

PostgREST's `.contains()` maps to PostgreSQL `@>` — GIN index kicks in.

## Get All Unique Tags

```dart
final result = await Supabase.instance.client.rpc('get_unique_tags');
```

```sql
CREATE OR REPLACE FUNCTION get_unique_tags()
RETURNS text[] AS $$
  SELECT ARRAY(
    SELECT DISTINCT unnest(tags) FROM notes
    WHERE user_id = auth.uid()
    ORDER BY 1
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

## Design Tradeoffs

Using `text[]` vs a separate `note_tags` join table:

| | text[] | Join table |
|--|--------|-----------|
| Schema complexity | Simple | Normalized |
| Query syntax | `@>` / `ANY` | JOIN + WHERE |
| Performance (solo app) | GIN index sufficient | Slightly faster at scale |
| Refactoring tags | UPDATE array | FK updates |

For a personal app at this scale, `text[]` is faster to ship and simpler to query. A join table would be justified at team scale or if tags needed metadata (color, description, etc).

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #buildinpublic #webdev
