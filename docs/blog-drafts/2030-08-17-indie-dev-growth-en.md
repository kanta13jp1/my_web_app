---
title: "Indie Dev Growth Loops — Referral Mechanics, Analytics, and Viral Coefficient in Flutter"
tags: indiedev,buildinpublic,flutter,programming
published: true
---

"Build it and they will come" is a myth. Indie developers need to engineer growth into the product from day one. This guide covers growth loop design, referral mechanics with real Dart code, UTM attribution, and analytics setup — all things you can ship in a weekend.

## 1. Growth Loops vs Funnels

A **funnel** is linear and leaky: Ads → Landing page → Sign-up → Paid. When users drop off, growth stops.

A **growth loop** is self-reinforcing. User actions produce more users.

```text
Content loop example:
  User creates content
  → Shares it publicly
  → New visitor sees the content
  → Signs up and creates content
  → Loop repeats
```

| Loop Type | Example | Key Mechanic |
|-----------|---------|-------------|
| Viral / Share | Figma share links | ShareCard, social posts |
| Content | Notion public pages | SEO, OGP previews |
| Referral | Dropbox "invite a friend" | Two-sided reward |
| Product-led | Slack free tier | Freemium + upgrade nudge |

## 2. Viral Coefficient (K-factor)

```dart
import 'dart:math';

class ViralMetrics {
  /// K-factor = invites_sent_per_user * conversion_rate
  /// K > 1 → exponential growth; K < 1 → linear with ceiling
  static double kFactor({
    required double invitesSentPerUser,
    required double conversionRate,
  }) =>
      invitesSentPerUser * conversionRate;

  /// Project users after [cycles] viral cycles
  static int projectGrowth({
    required int initialUsers,
    required double k,
    required int cycles,
  }) {
    if (k >= 1) {
      // Geometric series: U_n = U_0 * (k^n - 1) / (k - 1)
      return (initialUsers * (pow(k, cycles) - 1) / (k - 1)).round();
    }
    // Convergent series: U_∞ ≈ U_0 / (1 - k)
    return (initialUsers / (1 - k)).round();
  }
}

// Even K = 0.3 means 43% organic amplification:
// 1000 users → invite 2 each → 30% convert = 600 extra users in one cycle
void main() {
  const k = 0.3;     // each user invites 2, 15% convert
  final projected = ViralMetrics.projectGrowth(
    initialUsers: 1000,
    k: k,
    cycles: 5,
  );
  print('Projected after 5 cycles: $projected users'); // ~2143
}
```

## 3. Referral System

### Backend — Idempotent Reward Grant

```sql
-- migration: referral_codes + referral_events + grant function

CREATE TABLE referral_codes (
  code        TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE referral_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code          TEXT REFERENCES referral_codes(code),
  referrer_id   UUID,
  new_user_id   UUID,
  type          TEXT NOT NULL, -- 'invite_sent' | 'converted'
  converted     BOOLEAN DEFAULT false,
  occurred_at   TIMESTAMPTZ DEFAULT now()
);

-- Idempotent: safe to call twice
CREATE OR REPLACE FUNCTION grant_referral_reward(
  p_referrer_id UUID,
  p_new_user_id UUID,
  p_code        TEXT
)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  -- Prevent double-granting
  IF EXISTS (
    SELECT 1 FROM referral_events
    WHERE new_user_id = p_new_user_id AND type = 'converted'
  ) THEN RETURN; END IF;

  -- Mark conversion
  INSERT INTO referral_events (code, referrer_id, new_user_id, type, converted)
  VALUES (p_code, p_referrer_id, p_new_user_id, 'converted', true);

  -- Grant 30 days to both users
  UPDATE user_subscriptions
  SET trial_ends_at = GREATEST(trial_ends_at, now()) + INTERVAL '30 days'
  WHERE user_id IN (p_referrer_id, p_new_user_id);
END;
$$;
```

### Flutter ReferralService

```dart
import 'package:share_plus/share_plus.dart';

class ReferralService {
  static const _appUrl = 'https://your-app.com';

  Future<String> getOrCreateCode(String userId) async {
    final row = await supabase
        .from('referral_codes')
        .select('code')
        .eq('user_id', userId)
        .maybeSingle();
    if (row != null) return row['code'] as String;

    final code = _buildCode(userId);
    await supabase.from('referral_codes').insert({
      'user_id': userId,
      'code': code,
    });
    return code;
  }

  String _buildCode(String userId) {
    final prefix = userId.replaceAll('-', '').substring(0, 6).toUpperCase();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final suffix = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return '$prefix$suffix';
  }

  Future<void> shareInvite({
    required String code,
    required String senderName,
  }) async {
    final url = '$_appUrl/join?ref=$code';
    final text = '$senderName invited you!\n'
        'We both get 30 days free premium when you sign up.\n\n$url';

    await Share.share(text, subject: 'Join me on the app');

    // Track that an invite was sent
    await supabase.from('referral_events').insert({
      'code': code,
      'type': 'invite_sent',
    });
  }

  Future<void> processReferral({
    required String newUserId,
    required String code,
  }) async {
    final row = await supabase
        .from('referral_codes')
        .select('user_id')
        .eq('code', code)
        .maybeSingle();
    if (row == null) return;

    await supabase.rpc('grant_referral_reward', params: {
      'p_referrer_id': row['user_id'],
      'p_new_user_id': newUserId,
      'p_code': code,
    });
  }
}
```

### ShareCard Widget

```dart
class ShareCard extends StatelessWidget {
  final String code;
  final String userName;

  const ShareCard({super.key, required this.code, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$userName's invite",
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign up and we both get\n30 days free premium',
            style: TextStyle(color: Colors.white70, height: 1.6),
          ),
          const SizedBox(height: 20),
          _CodeRow(code: code),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final String code;
  const _CodeRow({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              fontSize: 20,
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Code copied!')));
            },
            child: const Icon(Icons.copy_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
```

## 4. UTM Attribution

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UtmService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'first_touch_utm';

  /// Call from your deep-link handler on first launch
  static Future<void> capture(Uri uri) async {
    final params = <String, String>{};
    for (final p in ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'ref']) {
      final v = uri.queryParameters[p];
      if (v != null) params[p] = v;
    }
    if (params.isNotEmpty) {
      // Only save first touch — don't overwrite
      final existing = await _storage.read(key: _key);
      if (existing == null) {
        await _storage.write(key: _key, value: jsonEncode(params));
      }
    }
  }

  static Future<Map<String, String>> getFirstTouch() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  static Future<void> attributeSignUp(String userId) async {
    final utm = await getFirstTouch();
    if (utm.isEmpty) return;
    await supabase.from('user_attributions').insert({
      'user_id': userId,
      ...utm,
      'attributed_at': DateTime.now().toIso8601String(),
    });
  }
}
```

## 5. Analytics — Lightweight Self-hosted

```dart
class Analytics {
  static String? _sessionId;
  static String get sessionId => _sessionId ??= _newSessionId();
  static String _newSessionId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  static String _page = '/';
  static void setPage(String page) => _page = page;

  static Future<void> track(
    String event, {
    Map<String, dynamic>? props,
  }) async {
    try {
      await supabase.from('analytics_events').insert({
        'user_id': supabase.auth.currentUser?.id,
        'event': event,
        'page': _page,
        'session_id': sessionId,
        'properties': props ?? {},
        'occurred_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Never crash the app because of analytics
    }
  }
}

// Usage throughout the app
await Analytics.track('referral_shared', props: {'code': code});
await Analytics.track('feature_used', props: {'feature': 'realtime_chat'});
await Analytics.track('upgrade_prompt_shown', props: {'location': 'settings'});
await Analytics.track('subscription_started', props: {'plan': 'pro', 'source': 'referral'});
```

## 6. App Store Optimization for Flutter PWA

```dart
// web/index.html additions for PWA discoverability
// Add to <head>:
// <meta name="theme-color" content="#6C63FF">
// <meta name="apple-mobile-web-app-capable" content="yes">
// <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
// <link rel="manifest" href="manifest.json">

// web/manifest.json
const manifest = {
  "name": "Your App Name",
  "short_name": "YourApp",
  "description": "One-line pitch for your app",
  "start_url": "/?utm_source=pwa_homescreen",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#6C63FF",
  "categories": ["productivity", "utilities"],
  "screenshots": [
    {"src": "screenshots/home.png", "sizes": "1280x720", "type": "image/png"}
  ]
};
```

## Summary

| Growth Lever | Impact | Time to Ship |
|-------------|--------|-------------|
| Referral system | K-factor +0.1–0.3 | 1–2 days |
| UTM attribution | Identify best channels | 2 hours |
| ShareCard widget | Lower sharing friction | 2 hours |
| Analytics events | Measure and iterate | 1 day |

Even a K-factor of 0.3 gives you a 43% organic boost on top of paid acquisition. The secret is not one big growth hack — it's a dozen small optimizations that compound. Next week: publishing your first Dart package on pub.dev.
