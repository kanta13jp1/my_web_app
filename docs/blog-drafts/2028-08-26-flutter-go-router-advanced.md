---
title: "Flutter GoRouter 応用 — ネスト・認証ガード・ディープリンク"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter GoRouter 応用 — ネスト・認証ガード・ディープリンク

GoRouter の基本を超えた実践パターンをまとめる。

## ネストされたナビゲーション (ShellRoute)

```dart
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithBottomNav(child: child),
      routes: [
        GoRoute(path: '/home', builder: (c, s) => const HomePage()),
        GoRoute(path: '/search', builder: (c, s) => const SearchPage()),
        GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
      ],
    ),
    // 認証画面はShellRouteの外
    GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
  ],
);

class ScaffoldWithBottomNav extends StatelessWidget {
  const ScaffoldWithBottomNav({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        onTap: (i) => switch (i) {
          0 => context.go('/home'),
          1 => context.go('/search'),
          _ => context.go('/profile'),
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '検索'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
        ],
      ),
    );
  }
}
```

## 認証ガード (redirect)

```dart
final router = GoRouter(
  redirect: (context, state) {
    final isLoggedIn = ref.read(authStateProvider).value != null;
    final isOnLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isOnLoginPage) return '/login';
    if (isLoggedIn && isOnLoginPage) return '/home';
    return null; // リダイレクトなし
  },
  refreshListenable: GoRouterRefreshStream(
    supabase.auth.onAuthStateChange.map((e) => e.session),
  ),
  routes: [...],
);

// リアルタイムで認証状態変化に反応するユーティリティ
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
```

## ディープリンク: パラメータとクエリ

```dart
// /posts/123?highlight=flutter のようなURL
GoRoute(
  path: '/posts/:postId',
  builder: (context, state) {
    final postId = state.pathParameters['postId']!;
    final highlight = state.uri.queryParameters['highlight'];
    return PostDetailPage(postId: postId, highlight: highlight);
  },
),

// ネストしたパス
GoRoute(
  path: '/users/:userId',
  builder: (c, s) => UserPage(userId: s.pathParameters['userId']!),
  routes: [
    GoRoute(
      path: 'posts/:postId',  // /users/:userId/posts/:postId
      builder: (c, s) => UserPostPage(
        userId: s.pathParameters['userId']!,
        postId: s.pathParameters['postId']!,
      ),
    ),
  ],
),
```

## まとめ

```
ShellRoute  → ボトムナビ共有レイアウト (ネストナビゲーション)
redirect    → 認証ガード (refreshListenable で状態変化に即反応)
pathParameters / queryParameters → URLからデータ取得
ディープリンク → Web / モバイル共通で同じルーティング
```

GoRouter を使いこなすと URL 設計から認証フローまで一元管理できる。
