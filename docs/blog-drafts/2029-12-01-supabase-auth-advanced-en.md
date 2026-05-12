---
title: "Supabase Auth Advanced — Custom Claims, Row Level Security, and Session Management"
tags: dart,flutter,webdev,indiedev
published: true
---

# Supabase Auth Advanced — Custom Claims, Row Level Security, and Session Management

Once you've mastered Supabase Auth basics (email auth, social login), the next step is production-grade security design using custom JWT claims and Row Level Security policies.

## JWT Custom Claims: app_metadata vs user_metadata

Supabase JWTs include two metadata fields with different trust levels:

| Field | Write Access | Use Case |
|---|---|---|
| `user_metadata` | User themselves | Display name, avatar URL, public profile |
| `app_metadata` | Service role only (admin) | Roles, billing status, permission flags |

Because users cannot modify `app_metadata`, it is the correct field for authorization decisions.

```sql
-- Grant a custom role via app_metadata (requires service role key)
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"role": "admin"}'::jsonb
WHERE id = 'user-uuid';
```

```dart
// Reading custom claims in Flutter
final user = supabase.auth.currentUser;
final role = user?.appMetadata['role'] as String?;
if (role == 'admin') {
  // Show admin UI
}
```

## Row Level Security with auth.uid()

RLS enforces data access at the database level. `auth.uid()` automatically extracts the user ID from the JWT, keeping authorization logic close to the data.

```sql
-- Basic: users can only see their own data
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
USING (id = auth.uid());

-- Users can only update their own data
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Admin policy using custom claims
CREATE POLICY "Admins can view all users"
ON profiles FOR SELECT
USING (
  auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'
);

-- Team-based sharing: members see their team's posts
CREATE POLICY "Team members can view team posts"
ON posts FOR SELECT
USING (
  team_id IN (
    SELECT team_id FROM team_members
    WHERE user_id = auth.uid()
  )
);
```

## Session Expiry and Auto-Refresh

Supabase Auth manages access tokens (1 hour) and refresh tokens (60 days) by default. The Flutter SDK handles background refresh automatically, but you need to handle app-restart state restoration correctly.

```dart
// main.dart: Initialize auth state on startup
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    anonKey: 'your-anon-key',
  );
  runApp(const MyApp());
}

// Watch auth state changes in real time
class AuthNotifier extends _$AuthNotifier {
  StreamSubscription? _sub;

  @override
  AuthState build() {
    final session = supabase.auth.currentSession;
    _sub = supabase.auth.onAuthStateChange.listen((data) {
      state = data.session != null
          ? AuthState.authenticated(data.session!)
          : const AuthState.unauthenticated();
    });
    ref.onDispose(() => _sub?.cancel());
    return session != null
        ? AuthState.authenticated(session)
        : const AuthState.unauthenticated();
  }
}
```

Redirect to login on session expiry with GoRouter:

```dart
// GoRouter redirect guard
redirect: (context, state) {
  final authState = ref.read(authNotifierProvider);
  final isLoggedIn = authState is AuthStateAuthenticated;
  final isOnAuthPage = state.matchedLocation == '/login';

  if (!isLoggedIn && !isOnAuthPage) return '/login';
  if (isLoggedIn && isOnAuthPage) return '/home';
  return null;
},
```

## Supabase Admin API for User Management

All admin operations must go through an Edge Function using the service role client — never expose the service role key to the frontend.

```typescript
// supabase/functions/admin-manage-user/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const adminClient = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!  // Never use this in Flutter
)

Deno.serve(async (req) => {
  const { userId, role } = await req.json()

  const { error } = await adminClient.auth.admin.updateUserById(userId, {
    app_metadata: { role }
  })

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    })
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## Authentication State Management in Flutter

A complete auth flow combining Riverpod with Supabase:

```dart
// Sign-in notifier with email and Google
@riverpod
class SignInNotifier extends _$SignInNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.yourapp://login-callback',
      );
    });
  }
}
```

## Summary

- Use `app_metadata` for authorization (roles, permissions) — it cannot be modified by users
- Combine `auth.uid()` and `auth.jwt()` in RLS policies for fine-grained data access control
- Leverage the Flutter SDK's built-in auto-refresh, and use GoRouter redirects to handle session expiry
- Always perform Admin API operations inside Edge Functions — never expose the service role key to the client
