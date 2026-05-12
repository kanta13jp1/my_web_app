---
title: "Indie Dev SEO Strategy: /vs-* Pages, Structured Data, and Core Web Vitals"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev SEO Strategy: /vs-* Pages, Structured Data, and Core Web Vitals

Stop building in the dark. Three SEO tactics that actually moved organic traffic for my indie app.

## Tactic 1: /vs-* Comparison Pages — Steal Competitor Search Traffic

"Notion alternative" and "Notion vs X" searches drive enormous volume.

```
Why /vs-* pages work:
  Target keywords: "[competitor] alternative" / "[competitor] vs [your app]"
  Monthly volume:  hundreds to tens of thousands (scales with competitor fame)
  Competition gap: the competitor's own site can't easily outrank you here
```

**Flutter Web implementation**:

```dart
GoRoute(
  path: '/vs/:competitor',
  builder: (context, state) {
    final competitor = state.pathParameters['competitor']!;
    return VsPage(competitor: competitor);
  },
),
```

**SEO meta tags per page**:

```html
<!-- /vs/notion -->
<title>My App vs Notion: Features, Pricing & UI Compared (2026)</title>
<meta name="description" content="My App vs Notion — side-by-side comparison of AI life management features, pricing, and UX. Considering switching from Notion?" />
<link rel="canonical" href="https://example.com/vs/notion" />
```

**JSON-LD structured data**:

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [{
    "@type": "Question",
    "name": "How is My App different from Notion?",
    "acceptedAnswer": {
      "@type": "Answer",
      "text": "My App is an AI-native life management platform. Where Notion focuses on document management, My App integrates daily AI judgment, habit tracking, and financial management in one place."
    }
  }]
}
```

## Tactic 2: Core Web Vitals — Speed Is a Ranking Factor

```
Three metrics Google measures:
  LCP (Largest Contentful Paint): under 2.5s
  FID (First Input Delay):         under 100ms
  CLS (Cumulative Layout Shift):   under 0.1
```

**Flutter Web fixes**:

```dart
// LCP: preload the hero image
// web/index.html
<link rel="preload" href="assets/hero_image.webp" as="image" />

// CLS: always specify dimensions on images
Image.network(
  heroImageUrl,
  width: 1200,
  height: 630,
  fit: BoxFit.cover,
)

// FID: move heavy work off the main thread
Future<String> processData(String data) async {
  return Isolate.run(() => _heavyComputation(data));
}
```

## Tactic 3: Structured Data for Rich Results

```json
// BreadcrumbList
{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {"@type": "ListItem", "position": 1, "name": "Home",       "item": "https://example.com/"},
    {"@type": "ListItem", "position": 2, "name": "Compare",    "item": "https://example.com/vs/"},
    {"@type": "ListItem", "position": 3, "name": "vs Notion",  "item": "https://example.com/vs/notion"}
  ]
}

// SoftwareApplication
{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "My App",
  "applicationCategory": "LifestyleApplication",
  "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
  "aggregateRating": {"@type": "AggregateRating", "ratingValue": "4.8", "ratingCount": "124"}
}
```

## Priority Order

```
High priority (results in 3 months):
  1. Build /vs-* pages for 20 competitors
  2. Add FAQPage + BreadcrumbList JSON-LD
  3. Fix Core Web Vitals (LCP < 2.5s)

Medium priority (results in 6 months):
  4. Blog posts: 4/month × 6 months = 24 articles
  5. Automate sitemap updates (GHA cron)
  6. Internal link optimization

Long-term:
  7. Backlink acquisition
  8. Product Hunt comments on competitor listings
```

## Automate Sitemap Pings with GHA

```yaml
on:
  push:
    paths:
      - 'web/sitemap.xml'

jobs:
  ping-google:
    steps:
      - name: Ping Google Search Console
        run: curl "https://www.google.com/ping?sitemap=https://example.com/sitemap.xml"
```

## Summary

```
Fastest wins:   /vs-* pages (high-intent competitor traffic)
Medium-term:    Structured data (rich results in SERPs)
Ongoing:        Core Web Vitals + content publishing
Automation:     GHA cron for sitemap + ping
```

The indie dev SEO advantage: you can target competitors by name, and their brand power becomes your keyword pool. No big budget needed — just execution.

