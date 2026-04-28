---
title: "Indie Dev Landing Page Optimization: 6 Changes That Tripled My CVR"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev Landing Page Optimization: 6 Changes That Tripled My CVR

My landing page CVR went from 1.2% to 3.8%. No designer, no agency. Here's what I changed.

## Why LP Optimization Matters

```
With zero ad spend, CVR is your only lever.

1,000 visitors × 1% CVR = 10 signups
1,000 visitors × 4% CVR = 40 signups

A 4x difference — achievable without spending a cent.
```

## Change 1: Make Your Hero Section a Verb

```
❌ Before: "AI Life Management App"
✅ After:  "Manage Notion, budget, and Twitter from one screen"
```

Users are looking for what they can do — not what your product is. Lead with verbs.

```dart
Column(
  children: [
    Text(
      'Manage Notion, Budget & Twitter\nin One Place',
      style: Theme.of(context).textTheme.headlineLarge,
    ),
    const SizedBox(height: 16),
    Text(
      'Replaces 21 apps. Starting at \$7/month.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: 32),
    ElevatedButton(
      onPressed: () => context.go('/signup'),
      child: const Text('Start Free → 14-day trial'),
    ),
  ],
)
```

## Change 2: Show Social Proof with Numbers

```
❌ "Loved by users worldwide"
✅ "2,400 users · 8-min avg session · 0.8% refund rate"
```

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: [
    _StatBadge(number: '2,400+', label: 'Users'),
    _StatBadge(number: '8 min', label: 'Avg Session'),
    _StatBadge(number: '4.7★', label: 'Rating'),
  ],
)
```

## Change 3: Remove CTA Friction

```
❌ "Buy Now"      → implies commitment
✅ "Try Free"     → zero friction
✅ "Start 14-Day Free Trial — No Credit Card"  → pre-answers objections
```

Sticky FAB that follows scroll:

```dart
Scaffold(
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => context.go('/signup'),
    label: const Text('Try Free'),
    icon: const Icon(Icons.arrow_forward),
  ),
  body: SingleChildScrollView(child: Column(children: [...])),
)
```

## Change 4: Build a Competitor Comparison Table

Users compare before choosing — own the comparison:

```dart
Table(
  children: [
    TableRow(children: [
      TableCell(child: Text('Feature')),
      TableCell(child: Text('My App')),
      TableCell(child: Text('Notion')),
      TableCell(child: Text('Evernote')),
    ]),
    TableRow(children: [
      TableCell(child: Text('AI Journal')),
      TableCell(child: const Icon(Icons.check, color: Colors.green)),
      TableCell(child: const Icon(Icons.close, color: Colors.red)),
      TableCell(child: const Icon(Icons.close, color: Colors.red)),
    ]),
    // 21 competitors...
  ],
)
```

Direct CTA from the comparison table → high-intent signups.

## Change 5: Improve Page Speed

```
LCP 4.2s → 1.5s = 22% improvement in bounce rate

How:
  1. Convert images to WebP (70% size reduction)
  2. Flutter Web --wasm build
  3. Firebase Hosting cache headers
  4. Don't lazy-load above-the-fold content
```

```yaml
hosting:
  headers:
    - source: "**/*.{js,css,wasm}"
      headers:
        - key: Cache-Control
          value: public,max-age=31536000,immutable
```

## Change 6: A/B Test Everything

```
Variant A: "Try Free" button (blue)
Variant B: "Start Now" button (orange)
```

```dart
final variant = Random().nextBool() ? 'A' : 'B';

await supabase.from('ab_events').insert({
  'variant': variant,
  'event': 'lp_view',
  'session_id': sessionId,
});

final buttonText = variant == 'A' ? 'Try Free' : 'Start Now';
final buttonColor = variant == 'A' ? Colors.blue : Colors.orange;
```

## Results

```
Before: CVR 1.2%
After:  CVR 3.8% (+216%)

Impact by change:
  #1: CTA copy change     +0.9%
  #2: Page speed          +0.7%
  #3: Comparison table    +0.6%
  #4: Social proof        +0.4%
  #5: Hero rewrite        +0.3%
  #6: A/B testing (ongoing)
```

## Summary

LP optimization is the only lever for reducing CAC with zero ad budget.

Priority order:
1. Rewrite hero with verbs
2. Remove CTA friction
3. Add numbers to social proof
4. Fix page speed
5. Add competitor comparison
6. A/B test continuously

When your LP speaks to what users actually want, conversion follows — no big budget needed.
