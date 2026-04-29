---
title: "Dart Sealed Classes Guide — Type-Safe State Management with Pattern Matching"
tags: flutter,dart,webdev,indiedev
published: true
---

# Dart Sealed Classes Guide — Type-Safe State Management with Pattern Matching

Dart 3's `sealed` classes are the evolution of enums. They restrict subtyping to a closed set and enforce exhaustive `switch` coverage. The result: fewer runtime errors, richer domain models, cleaner state machines.

## Basic Sealed Class

```dart
sealed class AuthState {}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {
  final String userId;
  final String email;
  AuthSuccess({required this.userId, required this.email});
}

class AuthError extends AuthState {
  final String message;
  final String? code;
  AuthError({required this.message, this.code});
}
```

## Exhaustive Switch — No More Missing Cases

```dart
Widget buildFromState(AuthState state) => switch (state) {
  AuthInitial()  => const LoginForm(),
  AuthLoading()  => const CircularProgressIndicator(),
  AuthSuccess(:final email) => WelcomeScreen(email: email),
  AuthError(:final message, :final code) => ErrorView(
    message: message,
    code: code ?? 'unknown',
  ),
};
// Adding a new AuthState subclass = compile error here until handled
```

## Result Type

Type-safe success/failure without exceptions leaking into UI.

```dart
sealed class Result<T> {
  const Result();
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final String error;
  final Object? exception;
  const Failure(this.error, {this.exception});
}

// Usage
Future<Result<UserProfile>> fetchProfile(String userId) async {
  try {
    final data = await supabase
        .from('profiles').select().eq('id', userId).single();
    return Success(UserProfile.fromJson(data));
  } catch (e) {
    return Failure('Profile fetch failed', exception: e);
  }
}

final result = await fetchProfile(userId);
switch (result) {
  case Success(:final value):
    setState(() => _profile = value);
  case Failure(:final error):
    showErrorSnackBar(error);
}
```

## API Response Modeling

```dart
sealed class ApiResponse<T> { const ApiResponse(); }

final class ApiSuccess<T> extends ApiResponse<T> {
  final T data;
  final int statusCode;
  const ApiSuccess(this.data, {this.statusCode = 200});
}

final class ApiError<T> extends ApiResponse<T> {
  final String message;
  final int statusCode;
  const ApiError(this.message, {required this.statusCode});
}

final class ApiNetworkError<T> extends ApiResponse<T> {
  final String reason;
  const ApiNetworkError(this.reason);
}

// In UI
switch (response) {
  case ApiSuccess(:final data):
    setState(() => _tasks = data);
  case ApiError(:final message, :final statusCode) when statusCode == 401:
    router.go('/login');
  case ApiError(:final message):
    _showError(message);
  case ApiNetworkError(:final reason):
    _showOfflineBanner();
}
```

## With Riverpod

```dart
sealed class TasksState {}
class TasksLoading extends TasksState {}
class TasksData extends TasksState {
  final List<Task> tasks;
  TasksData(this.tasks);
}
class TasksError extends TasksState {
  final String message;
  TasksError(this.message);
}

// Provider
class TasksNotifier extends AsyncNotifier<TasksState> {
  @override
  Future<TasksState> build() async {
    try {
      return TasksData(await ref.read(taskRepoProvider).getAll());
    } catch (e) {
      return TasksError(e.toString());
    }
  }
}

// UI
ref.watch(tasksProvider).when(
  data: (state) => switch (state) {
    TasksLoading() => const Spinner(),
    TasksData(:final tasks) => TaskList(tasks: tasks),
    TasksError(:final message) => ErrorView(message: message),
  },
  loading: () => const Spinner(),
  error: (e, _) => ErrorView(message: e.toString()),
)
```

## Sealed Class vs Enum

| Use case | Choose |
|---|---|
| Simple flag / status | enum |
| Each case carries data | sealed class |
| Pattern match on variants | sealed class |
| Immutable + copyWith | sealed class + Freezed |

Since switching to sealed classes for all state management, I've had ~30% fewer runtime crashes. The compiler catches every unhandled case.

---

Are you using sealed classes yet? What's your favorite pattern? Drop a comment below.
