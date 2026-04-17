---
title: "Building a Public Guitar Gallery With 4 Users: Action Extension Pattern + Viral Design"
tags: Flutter,Supabase,buildinpublic,webdev,guitar
published: true
---

# Building a Public Guitar Gallery With 4 Users: Action Extension Pattern + Viral Design

## Why Build Community Features at 4 Users

[自分株式会社](https://my-web-app-b67f4.web.app/) had 4 registered users when this was built.

The counterintuitive argument: **a discoverable place must exist before sharing behavior can emerge**. If you wait until you have 100 users to add a public gallery, those first 100 users never experienced the motivation to share. Build the destination first, then let sharing behavior follow.

---

## The Constraint: 94/94 Edge Functions

Supabase (Free tier) caps Edge Functions at 94. The app was at 93 deployed. Adding a new function was impossible without deleting one.

**Solution: add an action to an existing function.**

`guitar-recording-studio` already handled save, share, and delete. Add `public_gallery` as a new action:

```typescript
case "public_gallery":
  return jsonResponse(
    await listPublicRecordings(auth.adminClient, url),
  );
```

No new deployment slot used.

---

## The `listPublicRecordings` Implementation

```typescript
async function listPublicRecordings(
  adminClient: SupabaseClient,
  url: URL,
) {
  const limit = Math.min(
    parseInt(url.searchParams.get("limit") ?? "20", 10),
    50,   // hard cap
  );
  const offset = parseInt(url.searchParams.get("offset") ?? "0", 10);
  const sortBy = url.searchParams.get("sortBy") ?? "created_at";

  // Whitelist validation — prevents SQL injection via sortBy param
  const validSorts = ["created_at", "likes", "plays"];
  const orderColumn = validSorts.includes(sortBy) ? sortBy : "created_at";

  const { data, error, count } = await adminClient
    .from("guitar_recordings")
    .select("*", { count: "exact" })  // get total for pagination
    .eq("is_public", true)
    .order(orderColumn, { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw error;
  return { success: true, recordings: data ?? [], total: count ?? 0, offset, limit };
}
```

Three security/performance notes:
1. **Whitelist `sortBy`** — user-controlled sort columns are a SQL injection vector if not validated
2. **Hard cap at 50** — prevents expensive full-table scans from a single request
3. **`count: "exact"`** — returns total row count alongside data for pagination, in one query

---

## Flutter Gallery Card

Each card shows: title, date, preset (acoustic_fingerpicking / etc.), BPM, tuning, tags, likes, plays, a like button (works unauthenticated), and a "Play" button that navigates to the shared view.

Sort toggle via `PopupMenuButton`:

```dart
PopupMenuButton<String>(
  onSelected: (sort) {
    setState(() => _sortBy = sort);
    _fetchGallery();
  },
  itemBuilder: (_) => [
    const PopupMenuItem(value: 'created_at', child: Text('Newest')),
    const PopupMenuItem(value: 'likes',      child: Text('Most Liked')),
    const PopupMenuItem(value: 'plays',      child: Text('Most Played')),
  ],
)
```

---

## Landing Page Integration

Added a gallery link inside the guitar studio banner on the LP:

```dart
GestureDetector(
  onTap: () => Navigator.of(context).pushNamed('/public-guitar-gallery'),
  child: Row(
    children: [
      Icon(Icons.library_music_outlined, color: Color(0xFFFF6B35)),
      SizedBox(width: 8),
      Text('Listen to public recordings →'),
    ],
  ),
),
```

**Visitor flow**: LP → "Listen to recordings" → gallery → sign up to record your own.

Also added `/public-guitar-gallery` to `sitemap.xml` — it's a page with user-generated content that updates daily, making it a meaningful SEO target.

---

## `withValues(alpha:)` — Not `withOpacity()`

```dart
// DEPRECATED (Flutter 3.19+)
color: const Color(0xFFFF6B35).withOpacity(0.2),

// CORRECT
color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
```

`flutter analyze` catches this as `deprecated_member_use`. Run it after every new page — the deprecation is easy to introduce and easy to miss.

---

## The Viral Design Logic

```
Recording saved with is_public = true
  → appears in /public-guitar-gallery
  → visitor discovers content
  → visitor signs up to record their own
  → their recording appears in the gallery
  → cycle repeats
```

The gallery is also the auto-X-post destination (via the fire-and-forget pattern described in a [previous post](https://my-web-app-b67f4.web.app/)). Every public recording becomes an X post. Every X post links back to the gallery. Two growth loops with one feature.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #guitar #webdev
