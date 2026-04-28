---
title: "Flutter Riverpod State Management: From Provider to AsyncNotifier"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Riverpod State Management: From Provider to AsyncNotifier

Flutter has too many state management options. Here's why I chose Riverpod and the patterns I use daily.

## Why Riverpod

```
setState:    single widget state — often sufficient
Provider:   simple, Flutter's DI approach
Riverpod:   Provider's successor — testable, compile-time safe
Bloc:       boilerplate-heavy — better for large teams
```

Riverpod hits the sweet spot for indie development: compile-time error detection + easy testing + more intuitive than Provider.

## Setup

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

dev_dependencies:
  riverpod_generator: ^2.3.0
  build_runner: ^2.4.0
```

```dart
// main.dart
void main() {
  runApp(
    const ProviderScope(  // wrap the whole app
      child: MyApp(),
    ),
  );
}
```

## Pattern 1: Provider (static values)

```dart
// For constants and configuration
final appNameProvider = Provider<String>((ref) => 'My App');

// Use in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = ref.watch(appNameProvider);
    return Text(appName);
  }
}
```

## Pattern 2: StateProvider (simple mutable state)

```dart
// Counters, flags, selection values
final counterProvider = StateProvider<int>((ref) => 0);
final isDarkModeProvider = StateProvider<bool>((ref) => false);

// Update
ref.read(counterProvider.notifier).state++;
ref.read(isDarkModeProvider.notifier).state = true;
```

## Pattern 3: FutureProvider (async data)

```dart
// Fetch from Supabase
final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final data = await supabase
      .from('development_achievements')
      .select('*')
      .order('completed_at', ascending: false);
  return data.map((e) => Achievement.fromJson(e)).toList();
});

// Widget
class AchievementsPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievementsAsync = ref.watch(achievementsProvider);

    return achievementsAsync.when(
      data: (achievements) => ListView.builder(
        itemCount: achievements.length,
        itemBuilder: (_, i) => ListTile(title: Text(achievements[i].title)),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (err, _) => Text('Error: $err'),
    );
  }
}
```

## Pattern 4: AsyncNotifier (async state with mutations)

```dart
// With riverpod_generator code generation
@riverpod
class AchievementList extends _$AchievementList {
  @override
  Future<List<Achievement>> build() async {
    return _fetchAchievements();
  }

  Future<List<Achievement>> _fetchAchievements() async {
    final data = await supabase
        .from('development_achievements')
        .select('*')
        .order('completed_at', ascending: false);
    return data.map((e) => Achievement.fromJson(e)).toList();
  }

  Future<void> addAchievement(String title, String description) async {
    await supabase.from('development_achievements').insert({
      'title': title,
      'description': description,
      'completed_at': DateTime.now().toIso8601String(),
    });
    ref.invalidateSelf(); // invalidate cache → re-fetch
  }
}
```

## Provider Dependencies

```dart
// auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((e) => e.session?.user);
});

// depends on auth
final userProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  final data = await supabase.from('profiles').select().eq('id', user.id).single();
  return Profile.fromJson(data);
});
```

`ref.watch()` observes other providers — when the dependency changes, this provider recomputes automatically.

## Testing Is Easy

```dart
final testAchievements = [
  Achievement(id: '1', title: 'Test Achievement', completedAt: DateTime.now()),
];

testWidgets('shows achievements', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Override FutureProvider with mock data
        achievementsProvider.overrideWith((_) async => testAchievements),
      ],
      child: const MaterialApp(home: AchievementsPage()),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('Test Achievement'), findsOneWidget);
});
```

`ProviderScope.overrides` lets you inject mocks per test without any additional mocking library.

## Choosing the Right Provider

- Static values → `Provider`
- Simple mutable state → `StateProvider`
- Async fetch (read-only) → `FutureProvider`
- Async fetch + mutations → `AsyncNotifier`
- Realtime streams → `StreamProvider`

Start with `FutureProvider`. Graduate to `AsyncNotifier` when you need mutations.
