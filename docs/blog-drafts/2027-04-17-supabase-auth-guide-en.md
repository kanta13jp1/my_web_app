---
title: "Supabase Auth in Flutter: JWT, Magic Links, and OAuth from Scratch"
tags: supabase,flutter,postgresql,indiedev
published: true
---

# Supabase Auth in Flutter: JWT, Magic Links, and OAuth from Scratch

Supabase Auth is wired directly to PostgreSQL's Row Level Security. Authentication, authorization, and data access are unified in one system. Here's the complete Flutter implementation.

## Why Supabase Auth Is Different

```
User → Supabase Auth → JWT issued
                       ↓
              PostgreSQL RLS filters automatically
              auth.uid() = user_id
```

The auth service and the database aren't separate. JWTs issued by auth automatically apply to every DB query. This is what makes Supabase simpler than Firebase Auth + Firestore.

## Flutter Setup

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.0.0
```

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    anonKey: 'your-anon-key',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

## Magic Link (Passwordless Email)

The simplest auth flow:

```dart
// Send the link
await supabase.auth.signInWithOtp(
  email: 'user@example.com',
  emailRedirectTo: 'io.supabase.myapp://login-callback/',
);

// Receive via deep link (main.dart)
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedIn && data.session != null) {
    context.go('/home');
  }
});
```

## Email / Password Auth

```dart
// Sign up
await supabase.auth.signUp(
  email: 'user@example.com',
  password: 'secure-password',
);

// Sign in
await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'secure-password',
);

// Sign out
await supabase.auth.signOut();

// Check current session
final session = supabase.auth.currentSession;
final user = supabase.auth.currentUser;
```

## OAuth (Google / GitHub)

```dart
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'io.supabase.myapp://login-callback/',
  authScreenLaunchMode: LaunchMode.externalApplication,
);
```

`redirectTo`: custom URL scheme for mobile, `window.location.origin` for web.

## Session Management: onAuthStateChange

```dart
class _AuthWrapperState extends State<AuthWrapper> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
```

## Anonymous Guard: Redirect Unauthenticated Users

Per-page check:

```dart
@override
void initState() {
  super.initState();
  if (supabase.auth.currentUser == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/login');
    });
  }
}
```

Or centralize with GoRouter redirect:

```dart
GoRouter(
  redirect: (context, state) {
    final isLoggedIn = supabase.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/login';
    
    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/home';
    return null;
  },
  routes: [...],
);
```

## JWT Verification in Edge Functions

```typescript
async function getAuthenticatedUser(req: Request) {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
  );

  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) throw new Error('Unauthorized');
  return user;
}
```

`SUPABASE_ANON_KEY` + user JWT → RLS applies automatically. `SUPABASE_SERVICE_ROLE_KEY` is for admin operations only.

## Implementation Checklist

1. `supabase.auth.currentUser` null check → anonymous guard on every protected page
2. `onAuthStateChange` listener → automatic routing on auth state changes
3. Magic Link / OAuth → passwordless UX, no password resets to handle
4. Combine with RLS → data access controlled at the DB layer
5. In Edge Functions: ANON_KEY + JWT for user operations, Service Role for admin only

The auth + DB integration is Supabase's biggest architectural advantage. It eliminates the category of bugs where auth passes but data access wasn't checked.
