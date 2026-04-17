---
title: "Reuse Existing Tables for New Features: Flutter Category Management + Medical Notes with ilike Filter"
tags: Flutter,Supabase,buildinpublic,Dart,PostgreSQL
published: true
---

# Reuse Existing Tables for New Features: Flutter Category Management + Medical Notes with ilike Filter

## What We Built

Two features added to [自分株式会社](https://my-web-app-b67f4.web.app/) in one session:

1. **Category Management** — user-defined tags for notes and tasks
2. **Medical Notes** — medication, clinic visits, health records

The interesting decision: medical notes reuse the existing `notes` table instead of creating a new one.

---

## Category Management: Standard RLS Pattern

```sql
CREATE TABLE categories (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name       text        NOT NULL,
  color      text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "categories_own" ON categories
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

`ON DELETE CASCADE` means deleting a user automatically deletes their categories — no orphaned rows.

Flutter fetch:

```dart
Future<void> _fetchCategories() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  final response = await supabase
      .from('categories')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: true);

  setState(() {
    _categories = List<Map<String, dynamic>>.from(response);
    _isLoading = false;
  });
}
```

`List<Map<String, dynamic>>.from(response)` converts the `List<dynamic>` that Supabase returns into a typed list — required to avoid `avoid_dynamic_calls` lint errors on subsequent `.map()` calls.

---

## Medical Notes: Reuse Existing Table with `.ilike()` Filter

Instead of creating a `medical_notes` table, medical records live in the existing `notes` table with a title prefix:

```dart
final data = await _supabase
    .from('notes')
    .select()
    .eq('user_id', userId)
    .ilike('title', '[Medical]%')
    .order('created_at', ascending: false)
    .limit(50);
```

`.ilike('title', '[Medical]%')` — case-insensitive LIKE filter. `%` matches anything after the prefix, so `[Medical] Prescription`, `[MEDICAL] Clinic visit`, and `[medical] Blood test` all match.

### Why Reuse Instead of a New Table

| New Table | Title Prefix |
|-----------|-------------|
| Schema migration needed | Zero schema changes |
| Extra RLS policy | Inherits notes RLS |
| Separate code path | One fetch pattern |
| Type-safe column | Free-form title |

The tradeoff: title prefix is informal — users could accidentally create a note titled `[Medical] something` that shows in medical notes. For a consumer app where the user IS the only data source, this is acceptable. For multi-user or programmatic ingestion, a dedicated column or table is better.

---

## Five Medical Categories

```dart
const categories = [
  '通院記録',    // Clinic visit
  '処方薬',      // Prescription
  '健康診断',    // Health checkup
  '手術・処置',  // Surgery / procedure
  'その他',      // Other
];
```

Categories are stored as part of the note content or in a metadata field — no enum column needed. The UI renders a `DropdownButton` to select category when creating a note, then includes it in the title: `[Medical][通院記録] Note content...`.

---

## Tool Catalog Integration

Both features are registered in `home_tool_catalog.dart` so they appear in search:

```dart
HomeToolEntry(
  id:        'categories',
  sectionId: 'knowledge',
  title:     'Category Management',
  subtitle:  'Organize notes and tasks by category',
  icon:      Icons.category_outlined,
  color:     Colors.blueGrey,
  keywords:  const ['category', 'tag', 'label', 'organize'],
  onOpen:    (context) => _pushPage(context, const CategoriesPage()),
),
```

`keywords` drives the home search — users typing "tag" or "label" find the categories page without knowing its exact name.

---

## Summary

- `ON DELETE CASCADE` keeps the DB clean when users are deleted
- `.ilike('title', '[Medical]%')` filters by prefix without schema changes
- `List<Map<String, dynamic>>.from(response)` converts Supabase's `List<dynamic>` to avoid lint errors
- Reusing existing tables is valid when the user is the sole data source and prefix collision risk is low

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #PostgreSQL
