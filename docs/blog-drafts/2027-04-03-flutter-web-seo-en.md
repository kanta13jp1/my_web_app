---
title: "Flutter Web SEO: canonical, OGP, and JSON-LD for a 175-Route SPA"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Web SEO: canonical, OGP, and JSON-LD for a 175-Route SPA

Flutter Web is a Single Page Application. By default, search engines see one page. Here's how this project implemented full SEO across 175 routes.

## The SPA SEO Problem

```
Normal web:
  /page-a → page-a.html (independent HTML files)
  /page-b → page-b.html

Flutter Web SPA:
  /page-a → index.html
  /page-b → index.html
  → Google treats /page-a and /page-b as the same page
```

Flutter Web routes via JavaScript inside a single `index.html`. To fix SEO, you either dynamically rewrite `<head>` meta tags, or statically embed them at build time.

## Approach: Static Meta Tags in index.html

```html
<script>
const COMPETITOR_META = {
  'notion': {
    title: '自分株式会社 vs Notion — What Makes It Different?',
    description: 'Feature comparison between this AI life management app and Notion...',
    ogImage: '/og/vs-notion.png',
  },
  'evernote': {
    title: '自分株式会社 vs Evernote',
    description: '...',
    ogImage: '/og/vs-evernote.png',
  },
  // ... 174 more
};

function setMetaTags() {
  const path = window.location.pathname;
  const vsMatch = path.match(/^\/vs-([a-z0-9\-_]+)/);
  
  if (vsMatch) {
    const key = vsMatch[1];
    const meta = COMPETITOR_META[key];
    if (meta) {
      document.title = meta.title;
      document.querySelector('meta[property="og:title"]').content = meta.title;
      document.querySelector('meta[property="og:description"]').content = meta.description;
      document.querySelector('meta[property="og:image"]').content = meta.ogImage;
      document.querySelector('link[rel="canonical"]').href =
        `https://my-web-app-b67f4.web.app${path}`;
    }
  }
}

setMetaTags();
window.addEventListener('popstate', setMetaTags);
</script>
```

Google Bot executes JavaScript. Twitter/Facebook card crawlers don't — but the initial `setMetaTags()` call runs before the Flutter app loads, so the tags are set in time.

## JSON-LD Structured Data

```html
<script id="json-ld-webpage" type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "name": "Default page title",
  "url": "https://my-web-app-b67f4.web.app/"
}
</script>
<script id="json-ld-breadcrumb" type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": []
}
</script>
```

Update the JSON-LD on navigation:

```javascript
function updateJsonLd(competitor, url) {
  document.getElementById('json-ld-webpage').textContent = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": `自分株式会社 vs ${competitor}`,
    "url": url,
  });

  document.getElementById('json-ld-breadcrumb').textContent = JSON.stringify({
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": [
      {"@type": "ListItem", "position": 1, "name": "Home", "item": "https://my-web-app-b67f4.web.app/"},
      {"@type": "ListItem", "position": 2, "name": "Competitors", "item": "https://my-web-app-b67f4.web.app/competitors"},
      {"@type": "ListItem", "position": 3, "name": `vs ${competitor}`}
    ],
  });
}
```

## sitemap.xml: All 175 Routes

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://my-web-app-b67f4.web.app/</loc>
    <priority>1.0</priority>
    <changefreq>weekly</changefreq>
  </url>
  <url>
    <loc>https://my-web-app-b67f4.web.app/competitors</loc>
    <priority>0.9</priority>
  </url>
  <url>
    <loc>https://my-web-app-b67f4.web.app/vs-notion</loc>
    <priority>0.8</priority>
    <changefreq>monthly</changefreq>
  </url>
  <!-- ... 172 more vs-* routes -->
</urlset>
```

## Canonical URL Setup

Flutter Web supports two routing strategies. **Use path routing for SEO**, not hash routing:

```dart
// lib/main.dart — path strategy (no #)
GoRouter(routes: [...]);
// Produces /vs-notion, not /#/vs-notion
```

```html
<!-- index.html -->
<link id="canonical-link" rel="canonical" href="https://my-web-app-b67f4.web.app/">
<script>
document.getElementById('canonical-link').href =
  'https://my-web-app-b67f4.web.app' + window.location.pathname;
</script>
```

## Firebase Hosting Rewrite

All paths must route to `index.html`:

```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```

## Summary

Five things that make Flutter Web SEO work:
1. **Use path routing.** Hash URLs (`/#/page`) are SEO-hostile.
2. **Set meta tags in index.html via JS.** React to `popstate` for navigation.
3. **Embed JSON-LD.** WebPage + BreadcrumbList on every route.
4. **List every route in sitemap.xml.** Let Google discover them.
5. **Firebase Hosting rewrite.** All paths → `index.html`.

Flutter Web SEO isn't "impossible." It requires deliberate implementation. After doing it across 175 routes, organic search traffic increased measurably.
