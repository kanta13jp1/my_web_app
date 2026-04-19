---
title: "FlutterのメモアプリにNotionライクなタグ機能を追加する — Supabase配列カラム活用"
tags: Flutter,Supabase,個人開発,buildinpublic,Notion
published: true
---

# FlutterのメモアプリにNotionライクなタグ機能を追加する

## 背景: Notionとの差別化

自分株式会社のメモ機能は Notion の競合として位置づけている。
Notion の強みの一つがタグによる横断検索。これを Flutter + Supabase で実装する。

## DBスキーマ: text[] 配列カラム

```sql
-- notes テーブルに tags カラムを追加
ALTER TABLE notes ADD COLUMN tags text[] DEFAULT '{}';

-- タグで検索するインデックス
CREATE INDEX idx_notes_tags ON notes USING GIN(tags);
```

PostgreSQL の `text[]` (配列型) を使う。
正規化して別テーブルにする必要はない — 個人開発の規模ではシンプルさを優先。

## GIN インデックスと検索クエリ

```sql
-- タグで検索
SELECT * FROM notes WHERE 'work' = ANY(tags);

-- 複数タグで AND 検索
SELECT * FROM notes WHERE tags @> ARRAY['work', 'project'];

-- タグの前方一致
SELECT * FROM notes WHERE EXISTS (
  SELECT 1 FROM unnest(tags) t WHERE t LIKE 'wor%'
);
```

GIN インデックスが `ANY` や `@>` を高速化する。

## AI タグ提案: ai-hub EF

タグ入力の UX を上げるために AI が自動提案する:

```typescript
// ai-hub/index.ts (action: "tags.suggest")
case "tags.suggest": {
  const { text, existing_tags } = params;
  const response = await groq.chat.completions.create({
    model: "llama-3.3-70b-versatile",
    messages: [{
      role: "user",
      content: `以下のテキストに適切なタグを3-5個提案してください。
既存タグ: ${existing_tags.join(', ')}
テキスト: ${text}
JSONで返す: {"tags": ["tag1", "tag2", ...]}`
    }],
    response_format: { type: "json_object" },
  });
  return JSON.parse(response.choices[0].message.content);
}
```

Groq の llama-3.3-70b を使う → 無料枠内・高速。

## Flutter UI: タグチップ入力

```dart
// タグ入力 + AI提案コンポーネント
class TagInputField extends StatefulWidget {
  final List<String> initialTags;
  final ValueChanged<List<String>> onChanged;
  // ...

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 現在のタグ
        Wrap(
          spacing: 8,
          children: _tags.map((tag) => Chip(
            label: Text('#$tag'),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => _removeTag(tag),
            backgroundColor: const Color(0xFF1E3A5F),
          )).toList(),
        ),
        // 入力フィールド
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: 'タグを追加 (Enter で確定)',
          ),
          onSubmitted: _addTag,
        ),
        // AI提案ボタン
        if (_tags.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AIでタグを提案'),
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
    final suggested = List<String>.from(response.data['tags'] ?? []);
    setState(() => _suggestedTags = suggested);
  }
}
```

## Supabase: タグの保存と取得

```dart
// タグ付きでメモを保存
await Supabase.instance.client
    .from('notes')
    .update({'tags': tags})
    .eq('id', noteId);

// タグでフィルタリング
final notes = await Supabase.instance.client
    .from('notes')
    .select()
    .contains('tags', [selectedTag])
    .order('updated_at', ascending: false);
```

Supabase の PostgREST は `contains` フィルターで配列の包含チェックができる。

## タグ一覧の取得 (ユニーク)

```dart
// 全タグをユニークで取得
final result = await Supabase.instance.client
    .rpc('get_unique_tags');

// SQL function
CREATE OR REPLACE FUNCTION get_unique_tags()
RETURNS text[] AS $$
  SELECT ARRAY(
    SELECT DISTINCT unnest(tags) FROM notes
    WHERE user_id = auth.uid()
    ORDER BY 1
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

## まとめ

| 実装要素 | 技術選択 |
|---------|---------|
| DB スキーマ | `text[]` + GIN インデックス |
| 検索 | `@>` 演算子 + PostgREST `contains` |
| AI提案 | ai-hub `tags.suggest` (Groq llama-3.3-70b) |
| UI | Chip + debounce TextField |
| 一括取得 | `unnest()` + SQL function |

Notion のタグ機能は `text[]` + GIN + AI提案の組み合わせで再現できる。
個人開発の規模なら正規化テーブルより配列型の方が実装が速い。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #buildinpublic #個人開発 #Notion
