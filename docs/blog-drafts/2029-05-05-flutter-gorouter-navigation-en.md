---
title: "Flutter GoRouter Complete Guide — Full Control Over Navigation 2.0"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter GoRouter Complete Guide — Full Control Over Navigation 2.0

GoRouter is Flutter's officially recommended routing package. URL-based navigation, deep links, auth guards, and nested routes — all with clean, readable code.

## Basic Setup

```yaml
dependencies:
  go_router: ^13.0.0
```

```dart
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

## Navigation

```dart
// Push (keeps back stack)
context.push('/settings');

// Go (replaces history)
context.go('/home');

// With path parameters
context.push('/profile/user-123');

// With query parameters
context.push('/search?q=flutter&tag=dart');

// Go back
context.pop();

// Await a result
final confirmed = await context.push<bool>('/confirm');
if (confirmed == true) proceed();
```

## Auth Guard

```dart
final router = GoRouter(
  refreshListenable: authNotifier,
  redirect: (context, state) {
    final isAuthenticated = authNotifier.isAuthenticated;
    final isGoingToLogin = state.matchedLocation == '/login';

    if (!isAuthenticated && !isGoingToLogin) {
      return '/login?redirect=${state.uri}';
    }
    if (isAuthenticated && isGoingToLogin) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
  ],
);
```

## Nested Routes with ShellRoute

```dart
// Keep bottom nav bar while switching tabs
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/search', builder: (_, __) => const SearchPage()),
        GoRoute(
          path: '/profile',
          builder: (_, __) => const ProfilePage(),
          routes: [
            GoRoute(path: 'edit', builder: (_, __) => const EditProfilePage()),
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
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (i) => _navigate(i, context),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/search')) return 1;
    if (loc.startsWith('/profile')) return 2;
    return 0;
  }

  void _navigate(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/search');
      case 2: context.go('/profile');
    }
  }
}
```

## Riverpod Integration

```dart
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

@override
Widget build(BuildContext context, WidgetRef ref) {
  return MaterialApp.router(routerConfig: ref.watch(routerProvider));
}
```

## Deep Links and Custom Transitions

```dart
// GoRouter resolves URL → route automatically
// https://myapp.com/profile/user-123 → ProfilePage(userId: 'user-123')

// Custom page transition
GoRoute(
  path: '/details/:id',
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: DetailsPage(id: state.pathParameters['id']!),
    transitionsBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  ),
),
```

## Summary

GoRouter delivers:

- **URL-based navigation** with automatic deep link support
- **Auth guards** that auto-redirect unauthenticated users
- **ShellRoute** for persistent bottom nav during tab switches
- **Riverpod integration** for reactive routing on state changes

For any Flutter app of medium complexity or above, GoRouter is the routing solution to reach for first.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
