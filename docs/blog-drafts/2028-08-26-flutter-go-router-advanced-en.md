---
title: "Flutter GoRouter Advanced — Nested Navigation, Auth Guards, and Deep Links"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter GoRouter Advanced — Nested Navigation, Auth Guards, and Deep Links

Practical GoRouter patterns beyond the basics.

## Nested Navigation with ShellRoute

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
    // Auth screen lives outside ShellRoute
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
```

## Authentication Guard (redirect)

```dart
final router = GoRouter(
  redirect: (context, state) {
    final isLoggedIn = ref.read(authStateProvider).value != null;
    final isOnLoginPage = state.matchedLocation == '/login';

    if (!isLoggedIn && !isOnLoginPage) return '/login';
    if (isLoggedIn && isOnLoginPage) return '/home';
    return null; // no redirect
  },
  refreshListenable: GoRouterRefreshStream(
    supabase.auth.onAuthStateChange.map((e) => e.session),
  ),
  routes: [...],
);

// Utility that reacts to auth state changes in real time
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
```

## Deep Links: Path Parameters and Query Strings

```dart
// URL like /posts/123?highlight=flutter
GoRoute(
  path: '/posts/:postId',
  builder: (context, state) {
    final postId = state.pathParameters['postId']!;
    final highlight = state.uri.queryParameters['highlight'];
    return PostDetailPage(postId: postId, highlight: highlight);
  },
),

// Nested paths
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

## Summary

```
ShellRoute         → shared bottom nav layout (nested navigation)
redirect           → auth guard (refreshListenable reacts to state changes)
pathParameters /
queryParameters    → extract data from the URL
Deep links         → same routing for both web and mobile
```

Mastering GoRouter gives you unified control from URL design to auth flows.
