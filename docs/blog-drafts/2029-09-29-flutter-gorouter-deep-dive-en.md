---
title: "Flutter GoRouter Deep Dive — Type-safe Navigation, Nested Routes, and Redirects"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter GoRouter Deep Dive — Type-safe Navigation, Nested Routes, and Redirects

Flutter's declarative routing library **GoRouter** is the officially recommended solution that handles URL synchronization, deep linking, and type-safe navigation all at once. In this article we'll cover setup, `TypedGoRoute` for compile-time safety, shell routes for shared UI, and redirect-based auth guards — all with real working code.

## Installing GoRouter

Add the dependency to `pubspec.yaml`:

```yaml
dependencies:
  go_router: ^14.0.0
```

Define your router in its own file and pass it to `MaterialApp.router`:

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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'My App',
      routerConfig: router,
    );
  }
}
```

## Type-safe Navigation with TypedGoRoute

String-based path parameters are error-prone. `TypedGoRoute` (available since GoRouter 7.0) generates type-safe route classes at compile time using `build_runner`.

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

// Query parameters are automatically mapped from the URL
@TypedGoRoute<SearchRoute>(path: '/search')
class SearchRoute extends GoRouteData {
  const SearchRoute({this.query = '', this.page = 1});
  final String query;
  final int page;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return SearchPage(query: query, page: page);
  }
}
```

Navigation calls become fully typed — the compiler catches typos:

```dart
// Type-safe navigation — no magic strings
ProfileRoute(userId: 'abc123').go(context);
SearchRoute(query: 'flutter', page: 2).push(context);

// Generate the code
// dart run build_runner build --delete-conflicting-outputs
```

## Nested Routes and ShellRoute

`ShellRoute` wraps child routes in a persistent shell widget — perfect for `BottomNavigationBar` or `NavigationRail` layouts where the shell stays in place while the body navigates.

```dart
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomePage(),
          routes: [
            GoRoute(
              path: 'post/:postId',
              builder: (context, state) {
                return PostPage(postId: state.pathParameters['postId']!);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/explore',
          builder: (context, state) => const ExplorePage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
    // Routes outside the shell (e.g. login) don't show the nav bar
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
  ],
);

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});
  final Widget child;

  static const _tabs = ['/home', '/explore', '/settings'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
```

## Auth Redirect Guard

The `redirect` callback runs before each navigation. Combined with `refreshListenable`, it reacts to auth state changes automatically.

```dart
class AuthNotifier extends ChangeNotifier {
  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
    _loggedIn = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    _loggedIn = false;
    notifyListeners();
  }
}

final _auth = AuthNotifier();

final router = GoRouter(
  refreshListenable: _auth,
  redirect: (context, state) {
    final loggedIn = _auth.loggedIn;
    final onLogin = state.matchedLocation == '/login';

    if (!loggedIn && !onLogin) {
      // Preserve the intended destination as a query param
      final encoded = Uri.encodeComponent(state.uri.toString());
      return '/login?from=$encoded';
    }

    if (loggedIn && onLogin) {
      // After login, redirect to the original destination or home
      final from = state.uri.queryParameters['from'];
      return from != null ? Uri.decodeComponent(from) : '/home';
    }

    return null; // No redirect needed
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
  ],
);
```

## Named Routes and Error Handling

Named routes decouple navigation calls from URL strings, making large-scale refactoring safer.

```dart
final router = GoRouter(
  errorBuilder: (context, state) => NotFoundPage(error: state.error),
  routes: [
    GoRoute(
      name: 'home',
      path: '/',
      builder: (_, __) => const HomePage(),
    ),
    GoRoute(
      name: 'user-profile',
      path: '/users/:userId',
      builder: (context, state) {
        return ProfilePage(userId: state.pathParameters['userId']!);
      },
    ),
  ],
);

// Navigation by name — refactor-friendly
context.goNamed('user-profile', pathParameters: {'userId': '123'});
context.pushNamed(
  'user-profile',
  pathParameters: {'userId': '456'},
  queryParameters: {'tab': 'posts'},
);

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({this.error, super.key});
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('404 — The page you\'re looking for doesn\'t exist.'),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Stateful Shell Route (Preserving Tab State)

Flutter 3.7 introduced `StatefulShellRoute` which keeps each tab's navigation stack alive when switching between tabs — mimicking native app behavior.

```dart
final router = GoRouter(
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => TabShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/explore', builder: (_, __) => const ExplorePage())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsPage())],
        ),
      ],
    ),
  ],
);

class TabShell extends StatelessWidget {
  const TabShell({required this.shell, super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell, // Each branch's stack is preserved
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) {
          shell.goBranch(
            index,
            // If tapping the current tab, pop to root
            initialLocation: index == shell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
```

## Summary

| Feature | API |
|---------|-----|
| Type-safe routes | `TypedGoRoute` + `build_runner` |
| Persistent shell UI | `ShellRoute` / `StatefulShellRoute` |
| Auth guard | `redirect` + `refreshListenable` |
| Named navigation | `goNamed` / `pushNamed` |
| Custom 404 page | `errorBuilder` |
| Preserve tab state | `StatefulShellRoute.indexedStack` |

GoRouter is Flutter's officially recommended routing library and continues to add features. The combination of `TypedGoRoute` and `StatefulShellRoute` covers virtually all real-world navigation requirements while keeping code maintainable.

---

Are you using GoRouter in your Flutter project? Have you run into tricky edge cases with nested routes or auth redirects? Drop a comment below — I'd love to hear how you've structured your app's navigation.
