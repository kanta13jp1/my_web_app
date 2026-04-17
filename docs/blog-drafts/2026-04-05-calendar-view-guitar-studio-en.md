---
title: "TableCalendar in Flutter Web: O(1) Event Lookup + share_plus BuildContext Fix"
tags: Flutter,Supabase,buildinpublic,Dart,webdev
published: true
---

# TableCalendar in Flutter Web: O(1) Event Lookup + share_plus BuildContext Fix

## What We Shipped

Two features in one session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **Calendar View** — Notion Database parity using `table_calendar: ^3.1.2` + `calendar-events` Edge Function
2. **Guitar Studio lint fixes** — `use_build_context_synchronously`, `undefined_identifier`, and `unnecessary_import` resolved

---

## Calendar View: O(1) Event Lookup with Date-Key HashMap

### The Date Key Pattern

`TableCalendar`'s `eventLoader` receives a `DateTime day`. The simplest fast lookup: convert to a `YYYY-MM-DD` string key and store events in a `Map`:

```dart
final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};

static String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
```

Pass it to `TableCalendar`:

```dart
TableCalendar(
  eventLoader: (day) => _eventsByDate[_dateKey(day)] ?? [],
  ...
)
```

O(1) lookup per day — no iteration over the full event list.

### Fetch Per Month, Cache Locally

Only fetch when the user swipes to a new month. Already-fetched months stay in `_eventsByDate`:

```dart
onPageChanged: (focusedDay) {
  _focusedDay = focusedDay;
  _fetchMonth(focusedDay);
},
```

On back-navigation, the cached data renders instantly without a network round-trip.

### GET Request to Edge Function

`supabase_flutter`'s `functions.invoke` supports GET + query parameters:

```dart
final res = await _supabase.functions.invoke(
  'calendar-events',
  method: HttpMethod.get,
  queryParameters: {
    'view': 'month',
    'year': month.year.toString(),
    'month': month.month.toString(),
  },
);
```

No body needed for GET — pass everything as query params.

### No-Package Color Picker

5-color circle picker without any third-party package:

```dart
Wrap(
  spacing: 8,
  children: colors.map((c) => GestureDetector(
    onTap: () => setDialogState(() => selectedColor = c),
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Color(int.parse('FF${c.replaceFirst('#', '')}', radix: 16)),
        shape: BoxShape.circle,
        border: selectedColor == c
            ? Border.all(color: Colors.black87, width: 2.5)
            : null,
      ),
    ),
  )).toList(),
),
```

`'FF${hexString}'` with `radix: 16` converts a CSS hex color to a Flutter `Color` constant.

---

## Guitar Studio: Three Lint Fixes

### Fix 1: `use_build_context_synchronously`

Flutter 3.33+ enforces this strictly. Using `context` after any `await` without a `mounted` check is an error:

```dart
// BEFORE — lint error
await someFuture();
ScaffoldMessenger.of(context).showSnackBar(...);  // context used after async gap

// AFTER — correct
await someFuture();
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(...);
```

Add `if (!mounted) return` immediately after every `await` that precedes a `context` use.

### Fix 2: `undefined_identifier` + `prefer_final_fields`

Referencing a field before declaring it, or declaring a mutable field that's never mutated:

```dart
// BEFORE — undefined
final level = _audioLevel;  // _audioLevel not declared

// AFTER — declare with final
final double _audioLevel = 0.0;
```

`prefer_final_fields` requires `final` on any field that's set once and never reassigned.

### Fix 3: `unnecessary_import`

`share_plus` re-exports `XFile` from `cross_file`. Importing `cross_file` directly is redundant:

```dart
// BEFORE — redundant import
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';

// AFTER — one import is enough
import 'package:share_plus/share_plus.dart';
```

`flutter analyze` catches this as `unnecessary_import`. The re-export is stable across `share_plus` versions.

---

## Why Notion Calendar Parity Was Cheap to Implement

The calendar-events Edge Function already existed. `table_calendar` was already in `pubspec.yaml`. The Flutter page was mostly wiring:

1. Add `onPageChanged` → call `_fetchMonth`
2. Add `eventLoader` → return from HashMap
3. Style markers with `CalendarBuilders`

Total new Flutter code: ~150 lines. The Edge Function: 0 changes needed.

**Pattern**: Before building something new, check what infrastructure already exists. Features that look complex on the surface are often just UI over existing data.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #webdev
