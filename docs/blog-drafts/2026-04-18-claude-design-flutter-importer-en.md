---
title: "I Built a Flutter Importer for Claude Design Handoff Bundles"
tags: Flutter,Supabase,buildinpublic,webdev,AI
published: false
---

# I Built a Flutter Importer for Claude Design Handoff Bundles

Anthropic Labs' **Claude Design** can generate UI designs and export them as a JSON handoff bundle. I built a Flutter importer at `/dev/claude-design-importer` that parses that JSON, diffs it against the project's design tokens, and generates Flutter widget code.

## What's in a Handoff Bundle?

```json
{
  "tokens": {
    "colors": { "primary": "#F97316", "surface": "#141414" },
    "typography": { "h1": { "fontSize": 32, "fontWeight": "700" } },
    "spacing": { "sm": 8, "md": 16, "lg": 24 },
    "radius": { "card": 12 }
  },
  "components": [
    { "name": "PrimaryButton", "htmlSnippet": "<button>Click me</button>", "props": {} }
  ],
  "pages": [
    { "name": "Dashboard", "route": "/dashboard", "description": "Main screen" }
  ]
}
```

## The Four Files

### handoff_bundle.dart — Parser

Parses colors from `#RRGGBB` and `#AARRGGBB` hex strings into Flutter `Color` objects. Handles typography with `fontWeight` as either a number string (`"700"`) or keyword (`"bold"`).

```dart
factory DesignTokens.fromJson(Map<String, dynamic> json) {
  final rawColors = (json['colors'] as Map<String, dynamic>?) ?? {};
  final colors = <String, Color>{};
  for (final entry in rawColors.entries) {
    final hex = (entry.value as String?)?.replaceAll('#', '');
    if (hex != null && hex.length == 6) {
      colors[entry.key] = Color(int.parse('FF$hex', radix: 16));
    }
  }
  // ... typography, spacing, radius
}
```

### token_diff.dart — Design Token Diff

Compares incoming bundle tokens against the project's current `DESIGN.md` tokens. Classifies each token as `added`, `modified`, or `removed`.

```dart
class TokenDiff {
  final Map<String, TokenChange> colors;
  final Map<String, TokenChange> spacing;
  final int addedCount;
  final int modifiedCount;
  final int removedCount;
}
```

This answers: *"What would change in our design system if we adopted this bundle?"*

### flutter_codegen.dart — HTML → Flutter (~70% fidelity)

Pattern-based conversion of HTML snippets to Flutter widgets:

```dart
// <button> → ElevatedButton or OutlinedButton
// <input> → TextField
// <img> → Image.network or Icon
// <h1>/<h2> → Text with fontSize
// <div style="flex-direction: row"> → Row
// <div> → Column (default)
```

Not perfect — no CSS positioning, no complex layouts — but eliminates most boilerplate for standard UI components.

### importer_page.dart — 3-Tab UI

- **Tokens tab**: Color swatches + diff highlighting (added=green, modified=yellow, removed=red)
- **Components tab**: Side-by-side HTML snippet and generated Dart code with copy button
- **Pages tab**: Route table for the imported page structure

## Workflow

1. Design in Claude Design → Export as JSON
2. Open `/dev/claude-design-importer`
3. Paste JSON → "Parse"
4. Review token diffs → update `docs/DESIGN.md` if needed
5. Copy generated Dart → place in `lib/widgets/generated/`

## Testing

28 unit tests cover the full pipeline: hex color parsing, typography mapping, HTML→widget conversion for all supported tags, and diff counting.

```dart
test('FlutterCodegen button → ElevatedButton', () {
  final code = FlutterCodegen.generateFromComponent(
    DesignComponent(name: 'btn', htmlSnippet: '<button>Click</button>', props: {}),
  );
  expect(code, contains('ElevatedButton'));
});
```

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #Claude #Anthropic
