---
title: "Supabase Auth Advanced: OAuth, Magic Link, MFA, and RLS"
tags: supabase,ai,indiedev,programming
published: true
---

# Supabase Auth Advanced: OAuth, Magic Link, MFA, and RLS

Beyond `.signInWithPassword()` — the auth patterns that matter in production.

## OAuth (Google / GitHub)

```dart
// Google OAuth — PKCE flow (Supabase Flutter SDK v2)
Future<void> signInWithGoogle() async {
  await supabase.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: kIsWeb
        ? null
        : 'io.supabase.myapp://login-callback',
    authScreenLaunchMode: LaunchMode.externalApplication,
  );
}

// Dashboard: Authentication > Providers > Google
// → Client ID / Secret from Google Cloud Console
// → Add https://<project>.supabase.co/auth/v1/callback as redirect URI
```

**Flutter Deep Link** (`android/app/src/main/AndroidManifest.xml`):

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="io.supabase.myapp" android:host="login-callback" />
</intent-filter>
```

## Magic Link (Passwordless)

```dart
// Send magic link
await supabase.auth.signInWithOtp(
  email: email,
  emailRedirectTo: 'io.supabase.myapp://login-callback',
);

// After the user taps the link, receive the session
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedIn) {
    Navigator.pushReplacementNamed(context, '/home');
  }
});
```

Customize the email template in Dashboard > Authentication > Email Templates.
Default link expiry is 1 hour (configurable).

## MFA (TOTP)

```dart
// Step 1: Enroll
final response = await supabase.auth.mfa.enroll(
  factorType: FactorType.totp,
  issuer: 'MyApp',
);
final qrCode = response.totp?.qrCode;  // base64 PNG for display
final secret = response.totp?.secret;  // manual entry fallback

// Step 2: Challenge + verify with 6-digit code
final challengeResponse = await supabase.auth.mfa.challenge(
  factorId: response.id,
);
await supabase.auth.mfa.verify(
  factorId: response.id,
  challengeId: challengeResponse.id,
  code: userInputCode,
);
```

## Auth + RLS Integration

```sql
-- auth.uid() returns the currently authenticated user's ID
CREATE POLICY "users see own tasks"
ON tasks FOR SELECT
USING (user_id = auth.uid());

-- auth.jwt() exposes custom claims (e.g., premium plan check)
CREATE POLICY "premium only"
ON ai_results FOR INSERT
WITH CHECK (
  (auth.jwt() -> 'user_metadata' ->> 'plan') = 'premium'
);
```

**Update user_metadata from Flutter**:

```dart
await supabase.auth.updateUser(
  UserAttributes(
    data: {'plan': 'premium', 'onboarded': true},
  ),
);
```

## Session Management

```dart
Future<void> initAuth() async {
  final session = supabase.auth.currentSession;
  if (session == null) return; // → login screen

  if (session.isExpired) {
    await supabase.auth.refreshSession(); // SDK handles this automatically
  }
}

await supabase.auth.signOut();
```

## Summary

```
OAuth        → Google/GitHub via PKCE + Deep Link
Magic Link   → passwordless; receive session via onAuthStateChange
MFA (TOTP)   → enroll → challenge → verify (3 steps)
RLS          → auth.uid() / auth.jwt() in row-level policies
```

Because Supabase Auth integrates directly with Postgres, enabling RLS
eliminates most backend authorization code entirely.
