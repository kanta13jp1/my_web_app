---
title: "Notion-Style Team Workspace in Flutter Web: Supabase RLS EXISTS Subquery + Invite Code Pattern"
tags: Flutter,Supabase,buildinpublic,Dart,security
published: true
---

# Notion-Style Team Workspace in Flutter Web: Supabase RLS EXISTS Subquery + Invite Code Pattern

## What We Built

A team collaboration layer for [自分株式会社](https://my-web-app-b67f4.web.app/):

- Team creation with invite codes (8-char alphanumeric)
- Join via invite code (no email required)
- Shared notes within a team
- Supabase RLS enforces per-team isolation

---

## Schema: 3 Tables

```sql
-- Teams
CREATE TABLE teams (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  owner_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  description text,
  invite_code text NOT NULL UNIQUE DEFAULT upper(substring(gen_random_uuid()::text, 1, 8)),
  created_at  timestamptz DEFAULT now()
);

-- Memberships
CREATE TABLE team_memberships (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  team_id    uuid NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role       text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at  timestamptz DEFAULT now(),
  UNIQUE (team_id, user_id)
);

-- Shared Notes
CREATE TABLE team_shared_notes (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  team_id     uuid NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
  shared_by   uuid NOT NULL REFERENCES auth.users(id),
  note_id     uuid NOT NULL,
  shared_at   timestamptz DEFAULT now()
);
```

---

## RLS: EXISTS Subquery Pattern

Teams are visible to owners AND members — the key is `EXISTS` on the membership table:

```sql
-- Users see teams they own OR are a member of
CREATE POLICY "teams_select" ON teams FOR SELECT
  USING (
    owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM team_memberships tm
      WHERE tm.team_id = teams.id
        AND tm.user_id = auth.uid()
    )
  );
```

No JOIN in the policy — `EXISTS` is more efficient (short-circuits on first match).

Shared notes have a three-way policy (sharer, member, or team owner):

```sql
CREATE POLICY "team_shared_notes_select" ON team_shared_notes FOR SELECT
  USING (
    shared_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM team_memberships tm
      WHERE tm.team_id = team_shared_notes.team_id
        AND tm.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM teams t
      WHERE t.id = team_shared_notes.team_id
        AND t.owner_id = auth.uid()
    )
  );
```

---

## Why Invite Code Over Email Invite

| | Email Invite | Invite Code |
|--|-------------|-------------|
| Setup required | Resend API + email templates | None |
| User experience | Click link in email | Share 8-char code via any channel |
| Spam risk | High (email can be harvested) | Low (code expires or is revoked) |
| Dev complexity | ~2 hours | ~20 minutes |

The invite code is generated with:

```sql
DEFAULT upper(substring(gen_random_uuid()::text, 1, 8))
```

8 uppercase alphanumeric characters from a UUID. Collision probability at 100 teams: negligible.

---

## Flutter: One-Tap Copy for Invite Code

```dart
InkWell(
  onTap: () {
    Clipboard.setData(ClipboardData(text: team['invite_code']));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  },
  child: const Icon(Icons.copy, size: 16, color: Colors.grey),
),
```

The icon is a tap target — no separate "Copy" button. The snackbar confirms the copy.

---

## `avoid_dynamic_calls` with Supabase List Responses

Supabase returns `List<dynamic>`. Accessing properties directly triggers `avoid_dynamic_calls`:

```dart
// WRONG — lint error
final ownedIds = (owned as List).map((t) => t['id']).toSet();

// CORRECT — explicit cast to typed list
final ownedList = List<Map<String, dynamic>>.from(owned as List);
final ownedIds = ownedList.map((t) => t['id'] as String).toSet();
```

`List<Map<String, dynamic>>.from()` converts `List<dynamic>` to a typed list. Every subsequent `.map()` call is then lint-clean.

---

## Dynamic OGP for Competitor Comparison Pages

Same session: added per-competitor Open Graph tags to `index.html`. `/vs-notion` gets a different `og:title` and `og:description` than `/vs-slack`:

```js
var vsMatch = path.match(/\/vs-([a-z0-9\-]+)$/);
if (vsMatch) {
  var competitor = vsMatch[1];
  var meta = competitorMeta[competitor];
  if (meta) {
    document.title = meta.title;
    setMeta('og:title', meta.title);
    setMeta('og:description', meta.desc);
  }
}
```

Flutter Web is a SPA — index.html is the entry point for all routes. JavaScript reading `window.location.pathname` and setting meta tags runs before the Flutter app boots, so crawlers see the correct OGP.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #security
