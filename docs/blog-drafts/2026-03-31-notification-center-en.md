---
title: "In-App Notification Center in Flutter Web: Supabase RLS + Unread Badge Pattern"
tags: Flutter,Supabase,buildinpublic,Dart,webdev
published: true
---

# In-App Notification Center in Flutter Web: Supabase RLS + Unread Badge Pattern

## What We Built

A full notification center for [自分株式会社](https://my-web-app-b67f4.web.app/):

- Bell icon in AppBar with unread count badge
- Notification list page (unread / read / all filters)
- Mark-as-read and mark-all-read actions
- 7 notification types: feature_update, achievement, cs_reply, system, marketing, blog, agent

---

## Table Design: `user_id IS NULL` for Broadcasts

```sql
CREATE TABLE app_notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE, -- null = broadcast to all
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'system',
  link text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

`user_id IS NULL` means "show to everyone." This lets you manage broadcast announcements and personal CS replies in a single table — no separate `broadcast_notifications` table needed.

### RLS Policy

```sql
CREATE POLICY "users_read_own_notifications" ON app_notifications
  FOR SELECT USING (
    auth.uid() = user_id OR user_id IS NULL
  );
```

Users see their own notifications AND all broadcasts. One policy, no joins.

---

## Edge Function: `notification-center`

One Edge Function handles four actions:

- `GET ?mode=user&filter=unread` → unread list + count
- `GET ?mode=admin` → all notifications (admin only)
- `POST {action: "mark_read", notification_id: "..."}` → mark one read
- `POST {action: "mark_read", mark_all: true}` → mark all read

Unread count uses a separate aggregate query — `head: true` means no rows returned, just the count:

```typescript
const { count: unreadCount } = await adminClient
  .from("app_notifications")
  .select("*", { count: "exact", head: true })
  .or(`user_id.eq.${user.id},user_id.is.null`)
  .eq("is_read", false);
```

`CountOption.exact` gives a precise integer count. The `.or()` filter handles both personal and broadcast notifications in one query.

---

## Flutter: Unread Badge on AppBar Icon

`Stack` + `Positioned` overlays a badge on any widget without a package:

```dart
Stack(
  alignment: Alignment.center,
  children: [
    IconButton(
      icon: const Icon(Icons.notifications_outlined),
      onPressed: () async {
        await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const NotificationsPage()));
        _fetchNotifUnreadCount(); // refresh after returning
      },
    ),
    if (_notifUnreadCount > 0)
      Positioned(
        top: 8, right: 8,
        child: Container(
          width: 16, height: 16,
          decoration: const BoxDecoration(
            color: Colors.red, shape: BoxShape.circle),
          child: Center(
            child: Text(
              _notifUnreadCount > 9 ? '9+' : '$_notifUnreadCount',
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
      ),
  ],
),
```

Cap at `'9+'` for counts above 9 — standard UX pattern, prevents layout overflow.

Call `_fetchNotifUnreadCount()` after `Navigator.push` returns so the badge updates when the user comes back from the notification page.

---

## Flutter: Notification List Page

```dart
final response = await _supabase.functions.invoke(
  'notification-center',
  queryParameters: {'mode': 'user', 'filter': _filter},
);
final data = response.data as Map<String, dynamic>?;
_notifications = (data?['notifications'] as List?)
    ?.cast<Map<String, dynamic>>() ?? [];
_unreadCount = (data?['unreadCount'] as num?)?.toInt() ?? 0;
```

Note: `as Map<String, dynamic>?` cast before property access — `avoid_dynamic_calls` lint rule enforced.

### Type-Based Icon + Color Map

```dart
static const Map<String, _NotifMeta> _typeMeta = {
  'feature_update': _NotifMeta(Icons.new_releases,  Color(0xFF6366F1), 'New Feature'),
  'achievement':    _NotifMeta(Icons.emoji_events,   Color(0xFFF59E0B), 'Achievement'),
  'cs_reply':       _NotifMeta(Icons.support_agent,  Color(0xFF10B981), 'Support Reply'),
  'system':         _NotifMeta(Icons.settings,        Color(0xFF6B7280), 'System'),
  'marketing':      _NotifMeta(Icons.campaign,        Color(0xFFEC4899), 'Announcement'),
  'blog':           _NotifMeta(Icons.article,         Color(0xFF0EA5E9), 'Blog'),
  'agent':          _NotifMeta(Icons.smart_toy,       Color(0xFF8B5CF6), 'Agent'),
};
```

Each notification type gets a distinct icon and color. No switch statement needed — lookup from the map with a fallback.

---

## Migrating `dart:html` → `package:web`

The same session required migrating CSV download from the deprecated `dart:html` API:

```dart
// BEFORE (deprecated in Flutter 3.19+)
import 'dart:html' as html;
final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
final url = html.Url.createObjectUrlFromBlob(blob);
html.AnchorElement(href: url)..click();

// AFTER (dart:js_interop + package:web)
import 'dart:js_interop';
import 'package:web/web.dart' as web;
final blob = web.Blob(
  [Uint8List.fromList(bytes).toJS].toJS,
  web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
);
final url = web.URL.createObjectURL(blob);
web.HTMLAnchorElement()
  ..href = url
  ..download = 'export.csv'
  ..click();
web.URL.revokeObjectURL(url);
```

Key gotcha: `List<int>` has no `.toJS` extension. Convert to `Uint8List.fromList(bytes)` first, then `.toJS`.

---

## Architecture Summary

| Layer | Responsibility |
|-------|---------------|
| `app_notifications` table | Storage, RLS enforcement |
| `notification-center` EF | Auth, filtering, mark-read logic |
| Flutter `NotificationsPage` | Rendering only |
| AppBar badge | Unread count polling |

The RLS policy does the heavy security lifting. The Edge Function adds business logic (admin mode, aggregated counts). Flutter stays thin.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #webdev
