---
title: "Flutter GoRouter 深掘り — 型安全ナビゲーション・ネストルート・リダイレクト完全ガイド"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter GoRouter 深掘り — 型安全ナビゲーション・ネストルート・リダイレクト完全ガイド

Flutter の宣言的ルーティングライブラリ **GoRouter** は、Web URL との整合性・ディープリンク・型安全ナビゲーションを同時に解決する現代的な選択肢です。本記事では基本セットアップから `TypedGoRoute`・ネストルート・認証リダイレクトまで実際のコードで解説します。

## GoRouter のセットアップ

まず `pubspec.yaml` に依存を追加します。

```yaml
dependencies:
  go_router: ^14.0.0
```

最小構成のルーターを定義します。

```dart
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
  ],
);

// main.dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
    );
  }
}
```

## TypedGoRoute で型安全なナビゲーション

GoRouter 7.0 以降で導入された `TypedGoRoute` を使うと、パスパラメータの型ミスをコンパイル時に検出できます。`build_runner` でコード生成します。

```dart
// routes.dart
part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData {
  const HomeRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
}

@TypedGoRoute<ProfileRoute>(path: '/profile/:userId')
class ProfileRoute extends GoRouteData {
  const ProfileRoute({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ProfilePage(userId: userId);
  }
}

@TypedGoRoute<ItemRoute>(path: '/items/:itemId')
class ItemRoute extends GoRouteData {
  const ItemRoute({required this.itemId, this.tab = 'overview'});
  final int itemId;
  final String tab; // クエリパラメータは自動マッピング

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ItemPage(itemId: itemId, tab: tab);
  }
}
```

ナビゲーション呼び出しが型付きになります。

```dart
// 型安全な遷移
ProfileRoute(userId: 'abc123').go(context);
ItemRoute(itemId: 42, tab: 'reviews').push(context);

// コード生成実行
// dart run build_runner build --delete-conflicting-outputs
```

## ネストルート (ShellRoute)

BottomNavigationBar のように共通 UI を持ちながら子ルートを切り替えるには `ShellRoute` を使います。

```dart
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
          routes: [
            GoRoute(
              path: 'detail/:id',
              builder: (context, state) {
                return DetailPage(id: state.pathParameters['id']!);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.search), label: '検索'),
          NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/search');
      case 2: context.go('/settings');
    }
  }
}
```

## リダイレクトガード（認証）

`redirect` コールバックで認証状態を監視し、未ログインユーザーをログインページへ誘導します。`refreshListenable` と組み合わせると認証状態変化を自動検知します。

```dart
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> login(String email, String password) async {
    // Supabase 認証など
    await supabase.auth.signInWithPassword(email: email, password: password);
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    _isLoggedIn = false;
    notifyListeners();
  }
}

final authNotifier = AuthNotifier();

final router = GoRouter(
  refreshListenable: authNotifier,
  redirect: (context, state) {
    final isLoggedIn = authNotifier.isLoggedIn;
    final isOnLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isOnLoginPage) {
      // 未認証 → ログインページへ。元の遷移先を returnUrl として保存
      final from = state.uri.toString();
      return '/login?returnUrl=${Uri.encodeComponent(from)}';
    }

    if (isLoggedIn && isOnLoginPage) {
      // 認証済みでログインページにいる → ホームへ
      final returnUrl = state.uri.queryParameters['returnUrl'];
      return returnUrl ?? '/home';
    }

    return null; // リダイレクト不要
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/home', builder: (_, __) => const HomePage()),
    // 認証が必要なルートは redirect が自動ガード
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
  ],
);
```

## 名前付きルートとエラーハンドリング

URL を直書きするとリファクタリング時に壊れやすいため、名前付きルートで管理します。

```dart
final router = GoRouter(
  errorBuilder: (context, state) => ErrorPage(error: state.error),
  routes: [
    GoRoute(
      name: 'home',
      path: '/',
      builder: (_, __) => const HomePage(),
    ),
    GoRoute(
      name: 'profile',
      path: '/profile/:userId',
      builder: (context, state) {
        return ProfilePage(userId: state.pathParameters['userId']!);
      },
    ),
  ],
);

// 名前付きナビゲーション
context.goNamed('profile', pathParameters: {'userId': '123'});
context.pushNamed('profile', pathParameters: {'userId': '456'});

// エラーページ
class ErrorPage extends StatelessWidget {
  const ErrorPage({required this.error, super.key});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('ページが見つかりません', style: Theme.of(context).textTheme.headlineSmall),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('ホームへ戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Web URL との整合性

Flutter Web では `GoRouter` が URL バーと自動同期します。`UrlPathStrategy` を設定することでハッシュ (`#`) なしのクリーン URL を実現できます。

```dart
// main.dart
void main() {
  // Web 向けクリーン URL (# なし)
  GoRouter.optionURLReflectsImperativeAPIs = true;
  runApp(const MyApp());
}
```

## まとめ

| 機能 | API |
|------|-----|
| 型安全ナビゲーション | `TypedGoRoute` + `build_runner` |
| 共通レイアウト | `ShellRoute` |
| 認証ガード | `redirect` + `refreshListenable` |
| 名前付きルート | `goNamed` / `pushNamed` |
| エラーページ | `errorBuilder` |

GoRouter は Flutter の公式推奨ルーターとして活発に開発されています。型安全な `TypedGoRoute` を採用することで、大規模アプリでも安心してリファクタリングできます。

---

あなたのプロジェクトで GoRouter を使っていますか？ShellRoute の分岐や認証ガードの設計で詰まった箇所があればコメントで教えてください！
