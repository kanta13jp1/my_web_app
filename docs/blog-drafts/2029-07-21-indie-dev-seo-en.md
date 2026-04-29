---
title: "Indie SaaS SEO — Flutter Web Meta Tags, Tech Blogging, and Structured Data"
tags: flutter,supabase,webdev,indiedev
published: true
---

# Indie SaaS SEO — Flutter Web Meta Tags, Tech Blogging, and Structured Data

SEO is the highest ROI growth channel for indie SaaS. Zero ad spend, compounding returns. Here's how I drive 2,000+ organic visitors/month to a Flutter Web app.

## Flutter Web SEO Setup

Flutter Web is SPA + Canvas by default — bad for crawlers. Fix it with proper meta tags and structured data.

```html
<!-- web/index.html -->
<head>
  <meta name="description" content="AI-powered life management app. Tasks, journal, goals in one place. Free to start.">

  <!-- OGP -->
  <meta property="og:title" content="自分株式会社 — AI Life Management">
  <meta property="og:description" content="The all-in-one alternative to Notion + Evernote">
  <meta property="og:image" content="https://example.com/og-image.png">
  <meta property="og:type" content="website">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">

  <!-- Structured Data -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    "name": "自分株式会社",
    "applicationCategory": "ProductivityApplication",
    "operatingSystem": "Web",
    "offers": { "@type": "Offer", "price": "0", "priceCurrency": "JPY" },
    "aggregateRating": { "@type": "AggregateRating", "ratingValue": "4.8", "ratingCount": "127" }
  }
  </script>
</head>
```

## sitemap.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://my-web-app-b67f4.web.app/</loc><priority>1.0</priority></url>
  <url><loc>https://my-web-app-b67f4.web.app/features</loc><priority>0.9</priority></url>
  <url><loc>https://my-web-app-b67f4.web.app/pricing</loc><priority>0.8</priority></url>
</urlset>
```

## Keyword Strategy

For indie SaaS: long-tail + competitor alternatives.

```text
Target keywords:
✅ "notion alternative free" (1,200/mo, medium difficulty)
✅ "flutter web app productivity" (480/mo, low difficulty)
✅ "supabase personal finance" (320/mo, low difficulty)
❌ "productivity app" (too competitive)
❌ "notion" (brand term, not rankable)
```

## Tech Blogging (This Article's Strategy)

Weekly dev.to + Qiita posts = best SEO for indie devs.

```text
Content playbook:
1. 1 technical article/week (EN dev.to + JA Qiita)
2. Every article ends with product link + CTA
3. "Build in Public" — document the journey
4. Comparison articles: "Notion vs MyApp" for retargeting

High-CTR title patterns:
- "How I built [feature] with Flutter"
- "The [competitor] alternative I built for myself"
- "Month X of indie dev: revenue update"
```

## Landing Page SEO

```dart
class LandingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      // H1 equivalent — include primary keyword
      const Text('AI Life Management App — 自分株式会社',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      // Competitor keywords naturally
      const Text('Combines Notion, Evernote, and MoneyForward features. '
        'AI manages your tasks, journal, goals, and finances together.'),
      const ComparisonTable(),  // Competitor comparison = SEO + conversion
      const FAQSection(),       // Structured data + long-tail keywords
    ]),
  );
}
```

## Core Web Vitals

```yaml
# firebase.json hosting headers
headers:
  - source: "**/*.@(js|css|wasm)"
    headers:
      - key: Cache-Control
        value: max-age=31536000, immutable
  - source: "/"
    headers:
      - key: Cache-Control
        value: no-cache
```

## Measurement

Google Search Console monthly review:
- Low CTR keywords → rewrite titles
- Ranking position 6-15 → add more content to push into top 5
- High impressions, low clicks → fix meta description

6 months of consistent blogging → 2,000 organic visitors/month, zero ad spend.

---

What's your primary traffic source for your indie app? Always curious what's working for others in 2029.
