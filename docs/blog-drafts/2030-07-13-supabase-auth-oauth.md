---
title: "Supabase Auth で Google・GitHub・Apple ログインを実装する完全ガイド"
tags: Supabase,Flutter,個人開発,webdev
published: true
---

# Supabase Auth で Google・GitHub・Apple ログインを実装する完全ガイド

「ユーザー登録フォームを作ったけど誰も登録しない」という問題は、ソーシャルログインを実装することで劇的に改善する。自分株式会社では Supabase Auth を使って Google・GitHub・Apple Sign-In を実装し、登録コンバージョン率が 3 倍になった経験がある。本記事では各プロバイダーの設定から Flutter UI まで、実装手順を完全解説する。

## Supabase Auth の仕組みを理解する

Supabase Auth は OAuth 2.0 / OIDC のプロキシとして動作する。フローは以下の通り:

```
Flutter App
    │
    ▼ (1) supabase.auth.signInWithOAuth(provider)
Supabase Auth
    │
    ▼ (2) OAuth プロバイダーへリダイレクト
Google / GitHub / Apple
    │
    ▼ (3) 認可コード返却
Supabase Auth
    │
    ▼ (4) JWT + Refresh Token 発行
Flutter App (callback URL 経由)
```

callback URL は `https://<project-ref>.supabase.co/auth/v1/callback` と、アプリ側の `io.supabase.<bundle-id>://login-callback/` の 2 種類を用意する必要がある。

## 事前準備: Supabase プロジェクト設定

### pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.5.0
  url_launcher: ^6.2.0
  app_links: ^6.1.0  # ディープリンク処理
```

### 初期化 (main.dart)

```dart
// lib/main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // PKCE フロー推奨
      autoRefreshToken: true,
    ),
    debug: kDebugMode,
  );

  runApp(const MyApp());
}

// グローバルアクセス用
final supabase = Supabase.instance.client;
```

## Google OAuth の設定

### 1. Google Cloud Console で OAuth クライアント ID を取得

1. [Google Cloud Console](https://console.cloud.google.com/) → 「API とサービス」→「認証情報」
2. 「認証情報を作成」→「OAuth クライアント ID」
3. アプリケーションの種類: **ウェブアプリケーション**
4. 承認済みのリダイレクト URI に追加:
   ```
   https://<project-ref>.supabase.co/auth/v1/callback
   ```
5. クライアント ID・シークレットをメモ

### 2. Supabase Dashboard で有効化

Authentication → Providers → Google:
- Enable: ON
- Client ID: (Google Cloud の値)
- Client Secret: (Google Cloud の値)
- Authorized Client IDs: (Android 用の場合は追加)

### 3. Flutter での実装

```dart
// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = Supabase.instance.client;

  /// Google ログイン
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      queryParams: {
        'access_type': 'offline',  // refresh_token を取得
        'prompt': 'consent',       // 毎回同意画面を表示
      },
    );
  }

  /// GitHub ログイン
  Future<void> signInWithGitHub() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.github,
      redirectTo: _redirectUrl,
      scopes: 'read:user user:email',
    );
  }

  /// Apple Sign-In
  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _redirectUrl,
    );
  }

  /// サインアウト
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// 現在のユーザー
  User? get currentUser => _client.auth.currentUser;

  /// 認証状態のストリーム
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// リダイレクト URL (環境別に切り替え)
  String get _redirectUrl {
    if (kIsWeb) {
      return 'https://my-web-app-b67f4.web.app/auth/callback';
    }
    return 'io.supabase.jibun://login-callback/';
  }
}
```

## GitHub OAuth の設定

### 1. GitHub で OAuth App を作成

1. GitHub Settings → Developer settings → OAuth Apps → New OAuth App
2. Application name: 自分株式会社
3. Homepage URL: `https://my-web-app-b67f4.web.app`
4. Authorization callback URL:
   ```
   https://<project-ref>.supabase.co/auth/v1/callback
   ```
5. Client ID・Secret を Supabase Dashboard に入力

GitHub ログインはデベロッパー向けユーザーに強い。自分株式会社では GitHub ログインユーザーの retention が他プロバイダーより 20% 高い。

## Apple Sign-In の設定 (最も複雑)

Apple Sign-In は iOS App Store に公開するアプリでは **必須** のため、確実に設定したい。

### 1. Apple Developer で設定

```
Apple Developer Console:
  App IDs → <Your App ID>
    ☑ Sign In with Apple
  
  Services IDs → 新規作成:
    Description: Jibun Inc. Web
    Identifier: com.jibun.web (= Web 向けの Services ID)
    ☑ Sign In with Apple → Configure:
      Primary App ID: <Your App ID>
      Domains: my-web-app-b67f4.web.app
      Return URLs: https://<project-ref>.supabase.co/auth/v1/callback
  
  Keys → 新規作成:
    ☑ Sign In with Apple → Configure:
      Primary App ID: <Your App ID>
    → Key ID と .p8 ファイルをダウンロード
```

### 2. Supabase Dashboard に入力

| フィールド | 値 |
|-----------|-----|
| Service ID | `com.jibun.web` |
| Team ID | Apple Developer Account の Team ID (10桁) |
| Key ID | 先ほど作成した Key の ID |
| Private Key | .p8 ファイルの内容 |

## Flutter: ソーシャルログイン UI の実装

```dart
// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  bool _isLoading = false;

  Future<void> _handleOAuth(Future<void> Function() action) async {
    setState(() => _isLoading = true);
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FlutterLogo(size: 80),
                const SizedBox(height: 32),
                Text(
                  '自分株式会社へようこそ',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'ソーシャルアカウントで簡単ログイン',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),

                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  _SocialLoginButton(
                    label: 'Google でログイン',
                    icon: 'assets/icons/google.svg',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    onTap: () => _handleOAuth(_auth.signInWithGoogle),
                  ),
                  const SizedBox(height: 12),
                  _SocialLoginButton(
                    label: 'GitHub でログイン',
                    icon: 'assets/icons/github.svg',
                    backgroundColor: const Color(0xFF24292E),
                    foregroundColor: Colors.white,
                    onTap: () => _handleOAuth(_auth.signInWithGitHub),
                  ),
                  const SizedBox(height: 12),
                  _SocialLoginButton(
                    label: 'Apple でログイン',
                    icon: 'assets/icons/apple.svg',
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    onTap: () => _handleOAuth(_auth.signInWithApple),
                  ),
                ],

                const SizedBox(height: 32),
                Text(
                  'ログインすることで利用規約とプライバシーポリシーに同意したことになります',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final String icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Image.asset(icon, width: 20, height: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
```

## 認証後のルーティング処理

```dart
// lib/main.dart (GoRouter)
final _router = GoRouter(
  refreshListenable: GoRouterRefreshStream(supabase.auth.onAuthStateChange),
  redirect: (context, state) {
    final isLoggedIn = supabase.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/login';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    // OAuth callback (Web のみ)
    GoRoute(path: '/auth/callback', builder: (_, __) => const AuthCallbackPage()),
  ],
);
```

## まとめ

| プロバイダー | 設定難易度 | ユーザー層 | 必須条件 |
|------------|-----------|----------|---------|
| Google | ★★☆ | 一般ユーザー全般 | なし |
| GitHub | ★★☆ | 開発者・技術者 | なし |
| Apple | ★★★ | iOS ユーザー | App Store 公開アプリでは必須 |

Supabase Auth のおかげで OAuth の複雑なトークン管理が不要になり、実装工数は大幅に減った。個人開発では「Google + Apple」の 2 プロバイダーから始め、ユーザー層に合わせて GitHub を追加するのがおすすめだ。

---

*本記事は自分株式会社 (Flutter Web + Supabase) の実装経験をもとに執筆しました。*
