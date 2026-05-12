---
title: "Flutter GoRouter 完全ガイド — Navigation 2.0 でルーティングを完全制御する"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter GoRouter 完全ガイド — Navigation 2.0 でルーティングを完全制御する

GoRouter は Flutter 公式推奨のルーティングパッケージです。URL ベースのナビゲーション・ディープリンク・認証ガード・ネスト構造をシンプルなコードで実現します。

## GoRouter の基本

```yaml
# pubspec.yaml
dependencies:
  go_router: ^13.0.0
```

```dart
// main.dart
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/profile/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return ProfilePage(userId: userId);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);

void main() {
  runApp(MaterialApp.router(routerConfig: router));
}
```

## ナビゲーション

```dart
// push (戻れる)
context.push('/settings');

// go (履歴を置き換え)
context.go('/home');

// パラメータ付き
context.push('/profile/user-123');

// クエリパラメータ
context.push('/search?q=flutter&tag=dart');

// 戻る
context.pop();

// 結果を受け取る
final result = await context.push<bool>('/confirm');
if (result == true) doSomething();
```

## 認証ガード

```dart
// Riverpod と組み合わせた認証ガード
final router = GoRouter(
  refreshListenable: authNotifier, // 認証状態が変わると router が再評価
  redirect: (context, state) {
    final isAuthenticated = authNotifier.isAuthenticated;
    final isGoingToLogin = state.matchedLocation == '/login';

    if (!isAuthenticated && !isGoingToLogin) {
      // 未認証 → ログインページへ (元の URL は redirect パラメータで保持)
      return '/login?redirect=${state.uri}';
    }
    if (isAuthenticated && isGoingToLogin) {
      // 認証済みでログインページへ → ホームへ
      return '/';
    }
    return null; // リダイレクト不要
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
  ],
);
```

## ネストルート (ShellRoute)

```dart
// ボトムナビゲーションバーを維持したままページ切り替え
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
          routes: [
            // /profile/edit はプロフィールの子ルート
            GoRoute(
              path: 'edit',
              builder: (context, state) => const EditProfilePage(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNavBar({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (i) => _onItemTapped(i, context),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.search), label: '検索'),
          NavigationDestination(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/search');
      case 2: context.go('/profile');
    }
  }
}
```

## Riverpod と組み合わせる

```dart
// authProvider の変化を GoRouter が監視
@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    refreshListenable: _AuthNotifier(ref),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: routes,
  );
}

// MaterialApp で使用
@override
Widget build(BuildContext context, WidgetRef ref) {
  final router = ref.watch(routerProvider);
  return MaterialApp.router(routerConfig: router);
}
```

## ディープリンク (Web & モバイル)

```dart
// Android: android/app/src/main/AndroidManifest.xml に intent-filter 追加
// iOS: ios/Runner/Info.plist に CFBundleURLSchemes 追加

// GoRouter は自動的に URL からルートを解決する
// https://myapp.com/profile/user-123 → ProfilePage(userId: 'user-123')

// カスタムページ遷移アニメーション
GoRoute(
  path: '/details/:id',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: DetailsPage(id: state.pathParameters['id']!),
    transitionsBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  ),
),
```

## まとめ

GoRouter で:

- **URL ベースナビゲーション**でディープリンク対応
- **認証ガード**で未認証ユーザーを自動リダイレクト
- **ShellRoute**でボトムナビゲーションを維持したページ切り替え
- **Riverpod 統合**で状態変化に応じた自動ルーティング

Flutter の Navigation 2.0 を使いやすく抽象化した GoRouter は、中規模以上のアプリには必須です。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
