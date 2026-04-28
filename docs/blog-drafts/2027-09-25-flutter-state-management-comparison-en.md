---
title: "Flutter State Management Compared: Provider vs Riverpod vs Bloc"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter State Management Compared: Provider vs Riverpod vs Bloc

Stop guessing which one to use. Here are three real implementations and a clear decision framework.

## When You Need State Management

```dart
// ❌ BAD: setState can't share state across widgets
class ProfilePage extends StatefulWidget { ... }
class _ProfilePageState extends State<ProfilePage> {
  String? username; // Want this in another page — setState won't work
}
```

**Rule of thumb**:

```
Single widget only → setState is fine
Multiple widgets share state → use a state management library
```

## Provider: Straightforward DI

```dart
// 1. Define a ChangeNotifier
class UserModel extends ChangeNotifier {
  String? _username;
  String? get username => _username;

  Future<void> loadUser(String id) async {
    final res = await supabase.from('profiles').select().eq('id', id).single();
    _username = res['username'] as String;
    notifyListeners();
  }
}

// 2. Provide it above the widget tree
ChangeNotifierProvider(
  create: (_) => UserModel(),
  child: MaterialApp(home: ProfilePage()),
)

// 3. Consume in a widget
class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel>();
    return Text(user.username ?? 'Loading...');
  }
}
```

**Provider's pain points**:

```
- Needs BuildContext → hard to test
- MultiProvider grows unwieldy as dependencies multiply
- Async state (loading/error/data) is manual
```

## Riverpod: Provider, Evolved

```dart
// 1. Declare a provider (global, no context needed)
@riverpod
Future<Profile> userProfile(UserProfileRef ref, String userId) async {
  return supabase
      .from('profiles')
      .select()
      .eq('id', userId)
      .single()
      .then((r) => Profile.fromJson(r));
}

// 2. Use in a ConsumerWidget
class ProfilePage extends ConsumerWidget {
  final String userId;
  const ProfilePage({required this.userId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    return profileAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
      data: (profile) => Text(profile.username),
    );
  }
}
```

**Riverpod's superpowers**:

```dart
// Automatic dependency tracking
@riverpod
Future<List<Post>> userPosts(UserPostsRef ref) async {
  final profile = await ref.watch(userProfileProvider('user-123').future);
  return fetchPosts(profile.id); // re-runs automatically when profile updates
}

// Testing with ProviderContainer
final container = ProviderContainer(
  overrides: [
    userProfileProvider('test-id').overrideWith(
      (ref) => Future.value(Profile(id: 'test-id', username: 'test')),
    ),
  ],
);
```

## Bloc: Event-Driven for Large Apps

```dart
// 1. Events
abstract class UserEvent {}
class LoadUser extends UserEvent { final String id; LoadUser(this.id); }

// 2. States
abstract class UserState {}
class UserLoading extends UserState {}
class UserLoaded extends UserState {
  final Profile profile;
  UserLoaded(this.profile);
}
class UserError extends UserState { final String message; UserError(this.message); }

// 3. Bloc logic
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserLoading()) {
    on<LoadUser>((event, emit) async {
      emit(UserLoading());
      try {
        emit(UserLoaded(await fetchProfile(event.id)));
      } catch (e) {
        emit(UserError(e.toString()));
      }
    });
  }
}

// 4. Widget
BlocBuilder<UserBloc, UserState>(
  builder: (context, state) => switch (state) {
    UserLoading() => const CircularProgressIndicator(),
    UserError(:final message) => Text(message),
    UserLoaded(:final profile) => Text(profile.username),
    _ => const SizedBox(),
  },
)
```

## Decision Guide

```
Small app (1-3 screens) / beginners  → Provider
Medium app / testability matters      → Riverpod (recommended)
Large team / complex business logic   → Bloc
```

**For indie devs, Riverpod wins**:

```
- AsyncValue handles loading/error/data automatically
- ref.watch() declares dependencies declaratively
- ProviderContainer overrides replace mocks in tests
- Code generation (@riverpod) eliminates boilerplate
```

Start with Riverpod. If you ever need a team or strict audit trails, migrate to Bloc then. Migration cost is manageable; premature complexity isn't.

