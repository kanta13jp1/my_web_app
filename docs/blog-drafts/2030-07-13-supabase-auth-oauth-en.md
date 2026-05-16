---
title: "Supabase Auth OAuth in Flutter — Google, GitHub, and Apple Sign-In End-to-End"
tags: supabase,flutter,oauth,security
published: true
---

# Supabase Auth OAuth in Flutter — Google, GitHub, and Apple Sign-In End-to-End

Social login is the single highest-leverage UX improvement you can make for a new product. At Jibun Inc., adding Google and GitHub OAuth tripled our sign-up conversion rate overnight. This guide covers the full implementation: provider setup in each developer console, Supabase dashboard config, Flutter auth flow, callback handling, and social button UI patterns.

## How Supabase Auth OAuth Works

Supabase Auth acts as an OAuth 2.0 / OIDC proxy. Understanding this flow saves hours of debugging:

```
Flutter App
    │
    │ (1) supabase.auth.signInWithOAuth(provider)
    ▼
Supabase Auth  ──────────────────────────────►  Google / GitHub / Apple
                (2) redirect to provider                │
                                                        │ (3) auth code
                                        ◄───────────────┘
Supabase Auth
    │
    │ (4) exchange code → JWT + refresh token
    ▼
Flutter App  (via callback URL)
```

You need **two callback URLs** registered at every provider:
1. `https://<project-ref>.supabase.co/auth/v1/callback` — Supabase's server-side endpoint
2. `io.supabase.<bundle-id>://login-callback/` — deep link for the native app (mobile only)

## Project Setup

### pubspec.yaml

```yaml
dependencies:
  supabase_flutter: ^2.5.0
  app_links: ^6.1.0      # deep link handling on mobile
  url_launcher: ^6.2.0   # fallback browser launcher
```

### Initialization

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,   // always use PKCE
      autoRefreshToken: true,
    ),
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;
```

## Google OAuth Setup

### Step 1: Google Cloud Console

1. Open [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
2. Create Credentials → OAuth Client ID → Web Application
3. Add authorized redirect URIs:
   ```
   https://<project-ref>.supabase.co/auth/v1/callback
   ```
4. Copy the **Client ID** and **Client Secret**

### Step 2: Supabase Dashboard

Authentication → Providers → Google → Enable. Paste your Client ID and Secret.

### Step 3: Flutter Implementation

```dart
// lib/services/auth_service.dart
class AuthService {
  final _client = Supabase.instance.client;

  String get _redirectUrl => kIsWeb
      ? 'https://my-web-app-b67f4.web.app/auth/callback'
      : 'io.supabase.jibun://login-callback/';

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      queryParams: {
        'access_type': 'offline',  // get refresh_token
        'prompt': 'consent',
      },
    );
  }

  Future<void> signInWithGitHub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: _redirectUrl,
      scopes: 'read:user user:email',
    );
  }

  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _redirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}
```

## GitHub OAuth Setup

### Step 1: Create GitHub OAuth App

Settings → Developer Settings → OAuth Apps → New OAuth App:

| Field | Value |
|-------|-------|
| Application name | Jibun Inc. |
| Homepage URL | `https://my-web-app-b67f4.web.app` |
| Authorization callback URL | `https://<project-ref>.supabase.co/auth/v1/callback` |

Copy the Client ID and generate a Client Secret, then paste both into Supabase Dashboard → Providers → GitHub.

**Why GitHub?** Developer-users who sign in via GitHub have 20% better retention in Jibun Inc.'s data. If your app targets developers, GitHub login is worth the 15 minutes of setup.

## Apple Sign-In Setup (Most Complex)

Apple Sign-In is **mandatory** for any iOS app distributed via the App Store that offers third-party login. Plan an extra hour for the Apple Developer Console steps.

### Step 1: Apple Developer Console

```
App IDs → <Your App ID> → Capabilities:
  ☑ Sign In with Apple

Services IDs → New:
  Description: Jibun Inc. Web
  Identifier:  com.jibun.web           ← different from App ID
  ☑ Sign In with Apple → Configure:
    Primary App ID: <Your App ID>
    Domains:       my-web-app-b67f4.web.app
    Return URLs:   https://<project-ref>.supabase.co/auth/v1/callback

Keys → New:
  ☑ Sign In with Apple → Configure:
    Primary App ID: <Your App ID>
  → Download the .p8 file  (keep it safe — it cannot be re-downloaded)
```

### Step 2: Supabase Dashboard

| Field | Value |
|-------|-------|
| Service ID | `com.jibun.web` |
| Team ID | Your 10-character Apple Team ID |
| Key ID | The key ID from the Apple Developer portal |
| Private Key | Full contents of the `.p8` file |

## Social Login Button UI

A polished social login screen significantly reduces friction. Here is the pattern used in Jibun Inc.:

```dart
// lib/pages/login_page.dart
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  bool _loading = false;

  Future<void> _login(Future<void> Function() fn) async {
    setState(() => _loading = true);
    try {
      await fn();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AppLogo(),
                const SizedBox(height: 40),
                if (_loading)
                  const CircularProgressIndicator()
                else
                  _LoginButtons(onLogin: _login, auth: _auth),
                const SizedBox(height: 24),
                const _LegalText(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButtons extends StatelessWidget {
  const _LoginButtons({required this.onLogin, required this.auth});

  final Future<void> Function(Future<void> Function()) onLogin;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OAuthButton(
          label: 'Continue with Google',
          assetPath: 'assets/icons/google.png',
          bg: Colors.white,
          fg: Colors.black87,
          border: Colors.grey.shade300,
          onTap: () => onLogin(auth.signInWithGoogle),
        ),
        const SizedBox(height: 12),
        _OAuthButton(
          label: 'Continue with GitHub',
          assetPath: 'assets/icons/github.png',
          bg: const Color(0xFF24292E),
          fg: Colors.white,
          border: Colors.transparent,
          onTap: () => onLogin(auth.signInWithGitHub),
        ),
        const SizedBox(height: 12),
        _OAuthButton(
          label: 'Continue with Apple',
          assetPath: 'assets/icons/apple.png',
          bg: Colors.black,
          fg: Colors.white,
          border: Colors.transparent,
          onTap: () => onLogin(auth.signInWithApple),
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton({
    required this.label, required this.assetPath,
    required this.bg, required this.fg,
    required this.border, required this.onTap,
  });

  final String label, assetPath;
  final Color bg, fg, border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(assetPath, width: 20, height: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}
```

## Handling the Callback (Web)

On Flutter Web, the OAuth callback returns to your app as a URL. GoRouter handles it transparently if you add the callback route:

```dart
GoRoute(
  path: '/auth/callback',
  builder: (context, state) {
    // Supabase Flutter detects the URL params automatically.
    // Just redirect to home; the session is already set.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  },
  redirect: (context, state) {
    final isLoggedIn = supabase.auth.currentUser != null;
    return isLoggedIn ? '/' : null;
  },
),
```

## Security Checklist

| Item | Recommendation |
|------|---------------|
| PKCE flow | Always use `AuthFlowType.pkce` — never implicit |
| Redirect URL validation | Supabase restricts to the URL you register — no wildcards |
| Token storage | Supabase Flutter stores tokens in `SharedPreferences` (encrypted on iOS) |
| RLS policies | Always add `auth.uid() = user_id` to your Supabase tables |
| Scopes | Request minimum required scopes per provider |

## Summary

Supabase Auth abstracts away all OAuth complexity — no token exchange code, no manual JWT verification. The total implementation time for all three providers is roughly 2–3 hours, mostly spent in the Apple Developer Console. Start with Google (widest coverage), add Apple if you ship on iOS, and add GitHub if your user base skews technical.

---

*Based on real implementation at Jibun Inc. (Flutter Web + Supabase).*
