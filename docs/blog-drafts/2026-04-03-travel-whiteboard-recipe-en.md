---
title: "Travel Planner + Whiteboard + Recipe Manager in Flutter Web: RadioListTile Migration & const Propagation"
tags: Flutter,Supabase,buildinpublic,Dart,webdev
published: true
---

# Travel Planner + Whiteboard + Recipe Manager in Flutter Web

## What We Shipped

Three features in one session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **Travel Itinerary Planner** — competing with Google Travel, TripAdvisor
2. **Virtual Whiteboard** — competing with Miro, Microsoft Whiteboard
3. **Recipe & Meal Planner** — competing with Cookpad, Amazon Fresh

All three used pre-existing Edge Functions — the session was entirely Flutter UI.

---

## Edge Function First: UI Catches Up to Backend

```dart
// Travel planner: invoke the EF, parse the response
final response = await _supabase.functions.invoke(
  'travel-itinerary-planner',
  queryParameters: {'view': 'itinerary', 'trip_id': tripId},
);
final data = response.data as Map<String, dynamic>?;
if (data?['itinerary'] is Map) {
  final raw = data!['itinerary'] as Map;
  setState(() {
    _itinerary = raw.map(
      (k, v) => MapEntry(
        k.toString(),
        (v as List).cast<Map<String, dynamic>>(),
      ),
    );
  });
}
```

The Edge Functions (`travel-itinerary-planner`, `virtual-whiteboard`, `recipe-meal-planner`) already existed. The Flutter UI was built to consume them. **Pattern**: deploy backend logic first, ship UI when ready. The two timelines are independent.

---

## Tab Layouts

| Feature | Tabs |
|---------|------|
| Travel Planner | Itinerary / Bookings / Packing List / Budget |
| Whiteboard | My Boards / Templates |
| Recipe Manager | Recipes / Meal Plan / Shopping List |

All use `SingleTickerProviderStateMixin` + `TabController`:

```dart
class _TravelItineraryPageState extends State<TravelItineraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchTrips();
  }
```

---

## `RadioListTile` → `ListTile` + `Icon` Migration

Flutter 3.32+ deprecated `RadioListTile.groupValue` / `onChanged`. For simple dialogs, replace with `ListTile` + a check icon:

```dart
// DEPRECATED
RadioListTile<String>(
  value: tmplId,
  groupValue: _selectedTemplateId,
  onChanged: (v) => setState(() => _selectedTemplateId = v),
  title: Text(template['name']),
)

// CORRECT (Flutter 3.32+)
final isSelected = _selectedTemplateId == tmplId;
ListTile(
  leading: Icon(
    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
    color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
    size: 20,
  ),
  title: Text(template['name']),
  selected: isSelected,
  onTap: () => setState(() => _selectedTemplateId = tmplId),
)
```

Behavior is identical. No `RadioGroup` migration needed for this use case.

---

## `const` Propagation: Outer Widget Must be `const` Too

`prefer_const_constructors` requires `const` on widgets with no runtime-variable children. But the outer widget must also be `const` for the lint to pass:

```dart
// BEFORE — lint error: prefer_const_constructors on inner widgets
return Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.flight_takeoff, size: 64, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('No trips yet'),
    ],
  ),
);

// AFTER — const propagates outward
return const Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.flight_takeoff, size: 64, color: Colors.grey),
      SizedBox(height: 16),
      Text('No trips yet'),
    ],
  ),
);
```

When all children are `const`, the parent `Column` and `Center` can also be `const`. Remove the `const` from each child and move it to the outermost widget.

---

## `require_trailing_commas`: Multi-Line Formatting

```dart
// WRONG — missing trailing comma
_budgetStat('Balance', '¥${_formatNum(remaining)}',
    remaining >= 0 ? Colors.green : Colors.red),

// CORRECT — trailing comma added, each arg on its own line
_budgetStat(
  'Balance',
  '¥${_formatNum(remaining)}',
  remaining >= 0 ? Colors.green : Colors.red,
),
```

The trailing comma rule fires when arguments span multiple lines. `dart format` can auto-apply this — run it before every commit.

---

## Type Name: `HomeToolEntry` Not `HomeTool`

One easy-to-miss mistake when adding to the tool catalog:

```dart
// WRONG — doesn't exist
HomeToolCategory(tools: [HomeTool(...)])

// CORRECT
HomeToolCategory(tools: [HomeToolEntry(...)])
```

`flutter analyze` catches this as `undefined_identifier` immediately. Run analyze after every page addition — don't wait for CI.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #webdev
