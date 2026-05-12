---
title: "Dart Patterns Advanced — Sealed Classes, Guard Clauses, and Destructuring in Practice"
tags: dart,flutter,webdev,indiedev
published: true
---

# Dart Patterns Advanced — Sealed Classes, Guard Clauses, and Destructuring in Practice

Dart 3's pattern matching features — sealed classes, guard clauses, record destructuring, and object patterns — dramatically simplify state management, error handling, and data transformation in Flutter apps. This article covers advanced patterns you can apply in production code today.

## Sealed Classes for Exhaustive Pattern Matching

`sealed class` lets the compiler track all subclasses, turning missing branches in `switch` expressions into compile-time errors rather than runtime bugs.

```dart
// Result type implemented as a sealed class
sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final String message;
  final Object? error;
  const Failure(this.message, {this.error});
}

final class Loading<T> extends Result<T> {
  const Loading();
}

// Exhaustive pattern match — missing branches are compile errors
Widget buildWidget(Result<UserProfile> result) {
  return switch (result) {
    Success(data: final user) => UserCard(user: user),
    Failure(message: final msg) => ErrorBanner(message: msg),
    Loading() => const CircularProgressIndicator(),
  };
}
```

Unlike `if (result is Success)` checks, the `switch` exhaustiveness check means that adding a new subclass (e.g., `Cancelled`) will immediately surface every `switch` that needs updating — before the code ships.

## switch expression vs switch statement

Dart 3's `switch expression` returns a value, making it ideal for variable assignment and inline widget construction.

```dart
// switch statement (traditional)
String getLabel(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending:
      return 'Processing';
    case PaymentStatus.completed:
      return 'Completed';
    case PaymentStatus.failed:
      return 'Failed';
  }
}

// switch expression (Dart 3 idiomatic)
String getLabel(PaymentStatus status) => switch (status) {
  PaymentStatus.pending   => 'Processing',
  PaymentStatus.completed => 'Completed',
  PaymentStatus.failed    => 'Failed',
};

// Inline in widget tree
Text(
  switch (paymentStatus) {
    PaymentStatus.pending   => 'Processing payment...',
    PaymentStatus.completed => 'Payment complete',
    PaymentStatus.failed    => 'An error occurred',
  },
  style: TextStyle(
    color: switch (paymentStatus) {
      PaymentStatus.pending   => Colors.orange,
      PaymentStatus.completed => Colors.green,
      PaymentStatus.failed    => Colors.red,
    },
  ),
)
```

## Guard Clauses (when) for Conditional Filtering

The `when` keyword adds extra conditions to a pattern branch without breaking exhaustiveness.

```dart
sealed class PriceAlert {}
final class AboveThreshold extends PriceAlert {
  final double price;
  final double threshold;
  const AboveThreshold(this.price, this.threshold);
}
final class BelowThreshold extends PriceAlert {
  final double price;
  final double threshold;
  const BelowThreshold(this.price, this.threshold);
}

// Guard clauses filter within a pattern match
String describeAlert(PriceAlert alert) => switch (alert) {
  AboveThreshold(price: final p, threshold: final t)
      when p > t * 1.5 => 'Sharp rise (+50%): \$${p.toStringAsFixed(2)}',
  AboveThreshold(price: final p) => 'Rising: \$${p.toStringAsFixed(2)}',
  BelowThreshold(price: final p, threshold: final t)
      when p < t * 0.5 => 'Sharp drop (-50%): \$${p.toStringAsFixed(2)}',
  BelowThreshold(price: final p) => 'Falling: \$${p.toStringAsFixed(2)}',
};
```

## Record Destructuring for Tuple-Like Return Values

Dart 3's `Record` type enables type-safe multi-value returns without defining a dedicated class.

```dart
// Return multiple values as a Record
(String name, int age, bool isPremium) fetchUserSummary(String userId) {
  // ... implementation
  return ('Jane Smith', 28, true);
}

// Destructure at the call site
final (name, age, isPremium) = fetchUserSummary(userId);
print('$name ($age) - ${isPremium ? 'Premium' : 'Free'}');

// Combine with switch for conditional logic
final summary = fetchUserSummary(userId);
final badge = switch (summary) {
  (_, _, true)  => const PremiumBadge(),
  (_, var a, _) when a >= 60 => const SeniorBadge(),
  _ => const StandardBadge(),
};
```

## Object Patterns for Deep Nested Destructuring

Object patterns let you match and extract nested fields in a single expression.

```dart
class Order {
  final String id;
  final User customer;
  final List<OrderItem> items;
  final PaymentStatus status;
  const Order({required this.id, required this.customer, required this.items, required this.status});
}

class User {
  final String name;
  final bool isPremium;
  const User({required this.name, required this.isPremium});
}

// Object pattern destructures deeply nested objects in one switch
String orderSummary(Order order) => switch (order) {
  Order(
    customer: User(name: final name, isPremium: true),
    status: PaymentStatus.completed,
  ) => '$name (Premium) — order complete',
  Order(
    customer: User(name: final name),
    status: PaymentStatus.failed,
  ) => 'Payment failed for $name',
  Order(status: PaymentStatus.pending) => 'Processing...',
  _ => 'Unknown state',
};
```

## Flutter in Practice: Safe Supabase Response Handling

```dart
// Wrap Supabase response in a Result type
@riverpod
Future<Result<List<Product>>> products(ProductsRef ref) async {
  try {
    final data = await ref
        .watch(supabaseClientProvider)
        .from('products')
        .select()
        .order('created_at', ascending: false);
    return Success(data.map(Product.fromJson).toList());
  } on PostgrestException catch (e) {
    return Failure('Database error: ${e.message}', error: e);
  } catch (e) {
    return Failure('Unexpected error', error: e);
  }
}

// Widget — sealed class exhaustiveness keeps the UI in sync
class ProductListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(productsProvider);
    return result.when(
      data: (r) => switch (r) {
        Success(data: final products) when products.isEmpty =>
            const EmptyState(message: 'No products found'),
        Success(data: final products) =>
            ProductGrid(products: products),
        Failure(message: final msg) => ErrorBanner(message: msg),
        Loading() => const CircularProgressIndicator(),
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => ErrorBanner(message: e.toString()),
    );
  }
}
```

Dart 3's pattern matching rewrites the way you handle state and errors in Flutter. The combination of sealed classes and switch expressions works naturally with Riverpod's `AsyncValue.when()`, giving you exhaustive compile-time safety across your entire state model with less code than traditional approaches.

---

*This series covers Flutter, Supabase, and indie SaaS development. New articles every week.*
