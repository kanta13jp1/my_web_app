---
title: "Flutter GoRouter Deep Dive: Nested Routes, Redirects, and Deep Links"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter GoRouter Deep Dive: Nested Routes, Redirects, and Deep Links

GoRouter tames Navigator 2.0 complexity. Three practical patterns.

## Basic Setup

```dart
// lib/router.dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/tasks',
      builder: (context, state) => const TaskListPage(),
      routes: [
        GoRoute(
          path: ':id',  // /tasks/123
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TaskDetailPage(taskId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);

// main.dart
MaterialApp.router(routerConfig: router);
```

## Nested Routes: ShellRoute for Persistent Bottom Nav

```dart
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/tasks', builder: (_, __) => const TaskListPage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
  ],
);

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNavBar({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex(context),
        onTap: (i) => _onTap(context, i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/tasks'); break;
      case 2: context.go('/profile'); break;
    }
  }
}
```

## Redirect: Auth Guard

```dart
final router = GoRouter(
  redirect: (context, state) {
    final isLoggedIn = supabase.auth.currentSession != null;
    final isGoingToLogin = state.matchedLocation == '/login';

    if (!isLoggedIn && !isGoingToLogin) return '/login';
    if (isLoggedIn && isGoingToLogin) return '/home';
    return null; // no redirect
  },
  refreshListenable: GoRouterRefreshStream(
    supabase.auth.onAuthStateChange,
  ),
  routes: [ /* ... */ ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

## Deep Links: Web + Mobile

```dart
// Query parameters
GoRoute(
  path: '/tasks',
  builder: (context, state) {
    final filter = state.uri.queryParameters['filter']; // /tasks?filter=done
    return TaskListPage(filter: filter);
  },
),

// Type-safe navigation with extra
GoRoute(
  path: '/task-detail',
  builder: (context, state) {
    final task = state.extra as Task;
    return TaskDetailPage(task: task);
  },
),

// Calling side
context.go('/task-detail', extra: task);
```

**Web URL config** (`web/index.html`):

```html
<base href="/" />
```

## Summary

```
Basic routes   → GoRoute + path parameters
Nested         → ShellRoute keeps bottom nav persistent
Redirect       → redirect + refreshListenable for auth guard
Deep links     → queryParameters / extra for type safety
```

GoRouter is maintained by the Flutter team and is the standard routing
solution for Flutter 3.x. Migrating from Navigator.push()? Start with
ShellRoute — it's the lowest-risk entry point.
