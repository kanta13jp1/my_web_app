---
title: "Supabase Auth Complete Guide: Magic Link, OAuth, and MFA"
tags: supabase,flutter,indiedev,ai
published: true
---

# Supabase Auth Complete Guide: Magic Link, OAuth, and MFA

User authentication is the first real obstacle in indie development. Here's how to implement three Supabase Auth patterns with working code.

## Why Supabase Auth

```
Rolling your own auth:
  - Password hashing (bcrypt/Argon2)
  - Session management (JWT + refresh tokens)
  - OAuth flow implementation
  - Email delivery + token verification
  - MFA (TOTP + backup codes)
  → Minimum 2 weeks + security risk

Supabase Auth:
  → 30-minute setup + production quality
```

## Magic Link (Passwordless Email)

```dart
// Send a login link — that's it
await supabase.auth.signInWithOtp(email: 'user@example.com');

// When the user clicks the link → deep link back into the app
// Requires deep link config in AndroidManifest.xml / Info.plist
```

**Handling the deep link in Flutter**:

```dart
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        context.go('/home');
      }
    });
  }
}
```

## OAuth (Google / GitHub / Apple)

```dart
// Google login (Flutter Web)
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'https://your-app.web.app/auth/callback',
);

// GitHub login
await supabase.auth.signInWithOAuth(
  OAuthProvider.github,
  redirectTo: kIsWeb
    ? null                              // Web: Supabase handles it
    : 'io.your.app://login-callback',  // Mobile: custom scheme
);
```

**Dashboard setup**:

```
Authentication → Providers → Google
  Client ID:     [from Google Cloud Console]
  Client Secret: [from Google Cloud Console]
  Redirect URL:  https://your-project.supabase.co/auth/v1/callback
```

**Reading user metadata**:

```dart
final user = supabase.auth.currentUser;
final meta = user?.userMetadata;
print(meta?['full_name']);   // Google: display name
print(meta?['avatar_url']);  // Google: profile picture URL
```

## MFA (Multi-Factor Authentication)

```dart
// 1. Start TOTP enrollment
final response = await supabase.auth.mfa.enroll(
  factorType: FactorType.totp,
);
final qrCodeUrl = response.totp.qrCode; // show as QR image
final secret    = response.totp.secret; // show as text fallback

// 2. User scans QR code → enters OTP to confirm
await supabase.auth.mfa.verify(
  factorId:    response.id,
  challengeId: challengeResponse.id,
  code:        '123456',
);

// 3. Future logins require both password and OTP
final challengeResponse = await supabase.auth.mfa.challenge(
  factorId: factorId,
);
await supabase.auth.mfa.verify(
  factorId:    factorId,
  challengeId: challengeResponse.id,
  code:        otpController.text,
);
```

## Sessions and RLS

```dart
// Sign out
await supabase.auth.signOut();

// Current session
final session = supabase.auth.currentSession;

// RLS policy (SQL side)
// Users can only read their own profile
// CREATE POLICY "users can read own profile"
//   ON profiles FOR SELECT
//   USING (auth.uid() = user_id);
```

**RLS in practice**:

```dart
// Supabase automatically injects the auth token
// → if RLS is enabled, other users' data is invisible
final myProfile = await supabase
    .from('profiles')
    .select()
    .single(); // returns only the authenticated user's row
```

## Summary

```
Passwordless sign-in  → Magic Link
Social login          → OAuth (Google / GitHub / Apple)
Security hardening    → MFA (TOTP)
Data protection       → RLS (tied to auth.uid())
```

Start with Magic Link + Google OAuth. Add MFA and tighten RLS policies when you move to B2B or handle sensitive data. Supabase Auth handles the hard parts — spend that time on product instead.

