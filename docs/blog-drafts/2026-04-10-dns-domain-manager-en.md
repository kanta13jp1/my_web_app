---
title: "DNS & Domain Manager in Flutter Web: TabController FAB Rebuild + colorScheme Token Pattern"
tags: Flutter,Supabase,buildinpublic,Dart,webdev
published: true
---

# DNS & Domain Manager in Flutter Web: TabController FAB Rebuild + colorScheme Token Pattern

## What We Built

A full DNS management UI for [自分株式会社](https://my-web-app-b67f4.web.app/) — competing with Cloudflare, Google Domains, and Amazon Route53:

- **Domains tab**: domain list + add dialog (registrar: Cloudflare / Google Domains / Route53)
- **DNS Records tab**: A / AAAA / CNAME / MX / TXT / NS / SRV / CAA records per domain
- **SSL tab**: certificate expiry monitoring across all domains

---

## TabController FAB Rebuild Pattern

`FloatingActionButton` needs to change per tab. The key is `addListener` + `indexIsChanging` guard:

```dart
_tabController.addListener(() {
  if (!_tabController.indexIsChanging) {
    setState(() {});  // trigger FAB rebuild
    if (_tabController.index == 2 && _sslStatus.isEmpty) {
      _fetchSslStatus();  // lazy-load SSL data on first visit
    }
  }
});
```

Without `!_tabController.indexIsChanging`, the listener fires during the tab animation — causing redundant rebuilds and potentially double-firing the SSL fetch.

In `build()`, return the correct FAB based on the current tab index:

```dart
floatingActionButton: _tabController.index == 0
  ? FloatingActionButton.extended(
      onPressed: _showAddDomainDialog,
      icon: const Icon(Icons.add),
      label: const Text('Add Domain'),
    )
  : _tabController.index == 1
    ? FloatingActionButton.extended(
        onPressed: _selectedDomain != null ? _showAddRecordDialog : null,
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
      )
    : null,
```

---

## `app_analytics` as Generic Storage (No New Table)

DNS data lives in the existing `app_analytics` table, using `source` as a discriminator:

```typescript
// Add domain
await supabase.from("app_analytics").insert({
  user_id: userId,
  source: "dns_domain",
  metadata: { domain, registrar, created_at: new Date().toISOString() },
});

// Add DNS record
await supabase.from("app_analytics").insert({
  user_id: userId,
  source: "dns_record",
  metadata: { domain_id, record_type, name, value, ttl, priority },
});
```

Query by source:
```typescript
const { data: domains } = await supabase
  .from("app_analytics")
  .select("*")
  .eq("user_id", userId)
  .eq("source", "dns_domain");
```

No schema migration needed for a new feature — reuse `app_analytics` + JSONB metadata.

---

## `colorScheme` Token Pattern for Dark Mode

Hardcoded colors break dark mode. Replace them with Material 3 semantic tokens:

```dart
// WRONG — hardcoded, breaks in dark mode
color: Colors.black54

// CORRECT — semantic tokens, auto-adapts
color: colorScheme.outline
color: colorScheme.onSurfaceVariant
color: colorScheme.surfaceContainerHighest
```

Lookup the token:

```dart
final colorScheme = Theme.of(context).colorScheme;
```

When the app's `ThemeData` switches between light and dark, all `colorScheme.*` references update automatically — including the DNS management page.

---

## `DropdownButtonFormField`: `value` → `initialValue`

Flutter 3.33+ deprecated the `value` property:

```dart
// DEPRECATED
DropdownButtonFormField<String>(
  value: selectedType,
  ...
)

// CORRECT
DropdownButtonFormField<String>(
  initialValue: selectedType,
  ...
)
```

`flutter analyze` catches this as `deprecated_member_use`. Mechanical rename — no behavioral change.

---

## Edge Function Action Map

```typescript
// GET ?view=domains         → domain list
// GET ?view=records&domain_id=xxx → DNS records for domain
// GET ?view=ssl_status      → SSL expiry for all domains

// POST {action: "add_domain",    domain, registrar}
// POST {action: "add_record",    domain_id, record_type, name, value, ttl, priority}
// POST {action: "delete_record", record_id}
```

Flutter calls:

```dart
// GET with query params
final response = await _supabase.functions.invoke(
  'dns-domain-manager',
  method: HttpMethod.get,
  queryParameters: {'view': 'domains'},
);

// POST
await _supabase.functions.invoke(
  'dns-domain-manager',
  body: {'action': 'add_domain', 'domain': domain, 'registrar': registrar},
);
```

---

## Architecture Summary

| Layer | What it does |
|-------|-------------|
| `app_analytics` table | Storage (reused, no new migration) |
| `dns-domain-manager` EF | Auth, CRUD, SSL check aggregation |
| Flutter 3-tab UI | Rendering only |
| `colorScheme` tokens | Automatic dark/light mode |

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #webdev
