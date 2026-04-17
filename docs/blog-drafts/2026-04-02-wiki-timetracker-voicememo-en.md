---
title: "Wiki + Time Tracker + Voice Memo in Flutter Web: SegmentedButton, LinearProgressIndicator Bar Chart & Flutter 3.33 Deprecations"
tags: Flutter,Supabase,buildinpublic,Dart,webdev
published: true
---

# Wiki + Time Tracker + Voice Memo in Flutter Web

## What We Shipped

Three features in one session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **Wiki Database** — competing with Notion, Confluence (hierarchical pages + table view)
2. **Time Tracker** — competing with Jobcan, Toggl, Clockify (clock-in/out + project-based tracking)
3. **Voice Memo Transcriber** — competing with Google Keep, LINE Keep (voice + AI summary + note conversion)

All three use the same Edge Function First architecture.

---

## Common Pattern: Edge Function First

Every page follows the same fetch pattern:

```dart
Future<void> _fetchData() async {
  setState(() => _isLoading = true);
  try {
    final response = await _supabase.functions.invoke(
      'edge-function-name',
      queryParameters: {'view': 'list'},
    );
    final data = response.data as Map<String, dynamic>?;
    if (data?['items'] is List) {
      setState(() => _items = (data!['items'] as List).cast<Map<String, dynamic>>());
    }
  } catch (e) {
    setState(() => _errorMessage = 'Failed to load: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

Flutter only renders. All validation, DB access, and business logic live in the Deno Edge Function.

---

## Wiki Database: Hierarchical Pages

### Parallel Child + Table Fetch

```dart
Future<void> _fetchPageDetail(String pageId) async {
  final response = await _supabase.functions.invoke(
    'wiki-database',
    queryParameters: {'view': 'page', 'page_id': pageId},
  );
  // Returns page, children[], and tableRows[] in one response
}
```

One call returns the page content, its child pages, and table rows together. The UI is a 2-tab `TabBarView` — selecting a page auto-switches to the detail tab.

---

## Time Tracker: SegmentedButton + Bar Chart

### Period Selector

```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'today', label: Text('Today')),
    ButtonSegment(value: 'week',  label: Text('This Week')),
    ButtonSegment(value: 'month', label: Text('This Month')),
  ],
  selected: {_view},
  onSelectionChanged: (s) {
    setState(() => _view = s.first);
    _fetchEntries();
  },
),
```

`SegmentedButton` is Material 3 — no radio buttons or custom toggle needed.

### LinearProgressIndicator as Bar Chart

Project-time breakdown rendered with `LinearProgressIndicator`:

```dart
final ratio = maxHours > 0 ? hours / maxHours : 0.0;
LinearProgressIndicator(
  value: ratio.toDouble(),
  valueColor: AlwaysStoppedAnimation<Color>(color),
  minHeight: 8,
)
```

Normalize each project's hours against the maximum — `LinearProgressIndicator` does the rendering. No chart package needed for a simple bar chart.

### Overtime Alert

```dart
if (data?['overtimeAlert'] == true)
  Container(
    padding: const EdgeInsets.all(8),
    color: Colors.orange.shade100,
    child: const Text('⚠️ Overtime detected today'),
  ),
```

The Edge Function sets `overtimeAlert: true` when daily hours exceed the threshold. Flutter just shows or hides the banner.

---

## Voice Memo: Search + ExpansionTile + Note Conversion

### Server-Side Search

```dart
Future<void> _searchMemos(String q) async {
  final response = await _supabase.functions.invoke(
    'voice-memo-transcriber',
    queryParameters: {'view': 'search', 'q': q.trim()},
  );
}
```

Search runs in the Edge Function with a full-text or ILIKE query — no client-side filtering.

### ExpansionTile for Summary + Transcript

Each memo item uses `ExpansionTile`: collapsed shows title + duration, expanded shows AI summary and full transcript. No extra state management needed.

### Convert to Note

A "Convert to Note" button saves AI summary + transcript as Markdown to the `notes` table:

```dart
TextButton.icon(
  onPressed: () => _convertToNote(memo),
  icon: const Icon(Icons.note_add, size: 16),
  label: const Text('Save as Note'),
)
```

The Edge Function generates the Markdown and does the insert — Flutter fires the action and shows a snackbar.

---

## Flutter 3.33 Deprecation Fixes

### `DropdownButtonFormField.value` → `initialValue`

```dart
// DEPRECATED
DropdownButtonFormField<String>(
  value: _selectedStyle,
  ...
)

// CORRECT
DropdownButtonFormField<String>(
  initialValue: _selectedStyle,
  ...
)
```

`flutter analyze` catches this as `deprecated_member_use`. The rename is mechanical — `value` → `initialValue`, no behavioral change.

### `require_trailing_commas`

Multi-line widget arguments need a trailing comma on every last argument:

```dart
// WRONG — lint error
subtitle: Text(
  longText,
  style: const TextStyle(fontSize: 12)),  // missing trailing comma

// CORRECT
subtitle: Text(
  longText,
  style: const TextStyle(fontSize: 12),
),
```

Easy to miss inside ternary expressions. `flutter analyze` catches all of them — run it before every commit.

---

## Key Takeaways

| Pattern | What it solves |
|---------|---------------|
| Single EF call returns all tab data | Avoids waterfall fetches on tab switches |
| `LinearProgressIndicator` as bar chart | No chart package for simple visualizations |
| `SegmentedButton` for period filter | Material 3 toggle, zero custom code |
| `ExpansionTile` for memo detail | Progressive disclosure without state management |
| Overtime flag from EF | Business logic stays server-side |

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #webdev
