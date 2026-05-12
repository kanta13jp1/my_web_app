---
title: "Indie Dev ASO Complete Guide — Climbing App Store Rankings with Optimization"
tags: indiedev,ai,flutter,buildinpublic
published: true
---

# Indie Dev ASO Complete Guide — Climbing App Store Rankings with Optimization

Building a great app is only half the battle — users need to find it. App Store Optimization (ASO) increases discoverability and drives organic installs.

## What is ASO?

ASO is the process of optimizing your app's presence in the App Store and Google Play. Think of it as SEO for apps. Key elements:

- **Title & Subtitle**: Naturally include keywords
- **Description**: Clearly explain how you solve user problems
- **Screenshots**: The first 3 are critical
- **Reviews & Ratings**: Maintain 4.0+
- **Update Frequency**: Regular updates signal quality to stores

## Keyword Strategy

### Keyword Research

```
Tools:
- App Annie / data.ai (competitor analysis)
- Sensor Tower (market data)
- AppFollow (review analysis)
- Free tier: AppFollow limited plan / Google Play Console Insights
```

Low-cost strategy for indie developers:

1. **Analyze top competitors**: Extract keywords from their titles and descriptions
2. **App Store search suggestions**: Great for keyword ideas
3. **Mine reviews for language**: Use the exact words users use

### Keyword Placement Priority

| Location | Importance | Character Limit |
|---------|------------|----------------|
| App Name | ★★★ | 30 chars |
| Subtitle | ★★★ | 30 chars |
| Keyword Field (iOS) | ★★ | 100 chars |
| Description (first 3 lines) | ★★ | Unlimited |
| Description (rest) | ★ | Unlimited |

## Screenshot Optimization

Screenshots have the biggest impact on install rate:

**Bad**: Feature list screenshots
**Good**: Screenshots that tell a "problem → solution" story

```
Example screenshot sequence:
1st: Strongest value proposition ("AI supports your daily decisions")
2nd: Visual of main feature (dashboard view)
3rd: Social proof ("★4.8 / 1,000+ reviews")
4th: Specific use case
5th: Premium feature appeal
```

## Automating Review Requests

Request reviews from your Flutter app at the right moment:

```dart
import 'package:in_app_review/in_app_review.dart';

final InAppReview inAppReview = InAppReview.instance;

Future<void> requestReviewIfAppropriate() async {
  // Show after positive experience
  final shouldRequest = await _shouldShowReviewRequest();
  if (shouldRequest && await inAppReview.isAvailable()) {
    await inAppReview.requestReview();
    await _markReviewRequested();
  }
}

Future<bool> _shouldShowReviewRequest() async {
  // Example: 5th session / after completing 3 tasks
  final usageCount = await _getUsageCount();
  final hasRequested = await _hasRequestedReview();
  return usageCount >= 5 && !hasRequested;
}
```

## Tracking ASO Metrics with Supabase

```sql
CREATE TABLE aso_metrics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  date DATE NOT NULL,
  platform TEXT CHECK (platform IN ('ios', 'android')),
  impressions INT DEFAULT 0,
  page_views INT DEFAULT 0,
  installs INT DEFAULT 0,
  rating DECIMAL(2,1),
  rating_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## A/B Testing for Continuous Improvement

App Store Connect (iOS) and Google Play Console both support A/B testing of screenshots and descriptions:

- **iOS**: Product Page Optimization (90-day window)
- **Android**: Store Listing Experiments

Test ideas:
- Screenshot 1: Feature-focused vs. emotion-focused
- Icon design variations
- Short vs. detailed descriptions

## Summary

ASO is an ongoing process, not a one-time task. Schedule a monthly review of metrics and keyword adjustments. Even indie developers can grow organic traffic with consistent ASO effort.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
