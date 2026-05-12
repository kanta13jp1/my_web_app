---
title: "Flutter GoRouter 深化 — ネスト / リダイレクト / ディープリンク"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter GoRouter 深化 — ネスト / リダイレクト / ディープリンク

Navigator 2.0 の複雑さを GoRouter が解消する。実用的な3パターン。

## 基本セットアップ

```dart
// lib/router.dart
import 'package:go_router/go_router.dart';

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
MaterialApp.router(
  routerConfig: router,
);
```

## ネストルート: ShellRoute でボトムナビを維持

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
    // ナビバー外のルート
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
  ],
);

// ボトムナビバー
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'タスク'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'プロフィール'),
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

## リダイレクト: 認証ガード

```dart
final router = GoRouter(
  redirect: (context, state) {
    final isLoggedIn = supabase.auth.currentSession != null;
    final isGoingToLogin = state.matchedLocation == '/login';

    if (!isLoggedIn && !isGoingToLogin) return '/login';
    if (isLoggedIn && isGoingToLogin) return '/home';
    return null; // リダイレクトなし
  },
  refreshListenable: GoRouterRefreshStream(
    supabase.auth.onAuthStateChange,
  ),
  routes: [ /* ... */ ],
);

// onAuthStateChange を Listenable に変換
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

## ディープリンク: Web / モバイル対応

```dart
// クエリパラメータを受け取る
GoRoute(
  path: '/tasks',
  builder: (context, state) {
    final filter = state.uri.queryParameters['filter'];  // /tasks?filter=done
    return TaskListPage(filter: filter);
  },
),

// Extra オブジェクトで型安全に遷移
GoRoute(
  path: '/task-detail',
  builder: (context, state) {
    final task = state.extra as Task;
    return TaskDetailPage(task: task);
  },
),

// 遷移側
context.go('/task-detail', extra: task);
```

**Web の URL 設定** (`web/index.html`):

```html
<base href="/" />
```

## まとめ

```
基本ルート     → GoRoute + path parameters
ネスト        → ShellRoute でボトムナビを維持
リダイレクト   → redirect + refreshListenable で認証ガード
ディープリンク → queryParameters / extra で型安全
```

GoRouter は Flutter チームが公式メンテナンスしており、Flutter 3.x の標準ルーティング。
Navigator.push() からの移行は ShellRoute から始めると最も安全。
