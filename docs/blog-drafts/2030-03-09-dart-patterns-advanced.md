---
title: "Dart パターンマッチング上級編 — Sealed Classes・Guard Clauses・Destructuring の実践"
tags: flutter,dart,個人開発,AI
published: true
---

# Dart パターンマッチング上級編 — Sealed Classes・Guard Clauses・Destructuring の実践

Dart 3 で導入されたパターンマッチングは、Flutter アプリの状態管理・エラーハンドリング・データ変換を劇的にシンプルにします。本記事では、実際のプロダクションコードで役立つ上級パターンを解説します。

## Sealed Class で網羅的パターンマッチング

`sealed class` を使うと、コンパイラがすべてのサブクラスを把握し、`switch` での分岐漏れをコンパイルエラーで検出できます。

```dart
// Result 型を sealed class で実装
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

// 網羅的パターンマッチング — 分岐漏れはコンパイルエラー
Widget buildWidget(Result<UserProfile> result) {
  return switch (result) {
    Success(data: final user) => UserCard(user: user),
    Failure(message: final msg) => ErrorBanner(message: msg),
    Loading() => const CircularProgressIndicator(),
  };
}
```

従来の `if (result is Success)` スタイルと違い、`switch` の網羅性チェックにより、新しいサブクラス (`Cancelled` など) を追加した際に既存の `switch` 文がコンパイルエラーになるため、変更漏れを防げます。

## switch expression vs switch statement

Dart 3 の `switch expression` は値を返せるため、変数代入やウィジェット構築に使えます。

```dart
// switch statement（従来）
String getLabel(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending:
      return '処理中';
    case PaymentStatus.completed:
      return '完了';
    case PaymentStatus.failed:
      return '失敗';
  }
}

// switch expression（Dart 3 推奨）
String getLabel(PaymentStatus status) => switch (status) {
  PaymentStatus.pending  => '処理中',
  PaymentStatus.completed => '完了',
  PaymentStatus.failed   => '失敗',
};

// 直接 Widget に埋め込み
Text(
  switch (paymentStatus) {
    PaymentStatus.pending  => '支払い処理中...',
    PaymentStatus.completed => '支払い完了',
    PaymentStatus.failed   => 'エラーが発生しました',
  },
  style: TextStyle(
    color: switch (paymentStatus) {
      PaymentStatus.pending  => Colors.orange,
      PaymentStatus.completed => Colors.green,
      PaymentStatus.failed   => Colors.red,
    },
  ),
)
```

## Guard Clause (when) でフィルタリング

`when` キーワードで追加条件を付けることができます。

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

// guard clause で追加条件フィルタリング
String describeAlert(PriceAlert alert) => switch (alert) {
  AboveThreshold(price: final p, threshold: final t)
      when p > t * 1.5 => '大幅上昇（+50%超）: ¥${p.toInt()}',
  AboveThreshold(price: final p) => '上昇: ¥${p.toInt()}',
  BelowThreshold(price: final p, threshold: final t)
      when p < t * 0.5 => '大幅下落（-50%超）: ¥${p.toInt()}',
  BelowThreshold(price: final p) => '下落: ¥${p.toInt()}',
};
```

## Record Destructuring でタプルライクな返り値

Dart 3 の `Record` 型は複数値の返り値を型安全に扱えます。

```dart
// 複数値を返す関数 — Record 型
(String name, int age, bool isPremium) fetchUserSummary(String userId) {
  // ... 実装
  return ('田中太郎', 32, true);
}

// 使用側でのデストラクチャリング
final (name, age, isPremium) = fetchUserSummary(userId);
print('$name ($age) - ${isPremium ? 'プレミアム' : '無料'}');

// switch でのパターンマッチングと組み合わせ
final summary = fetchUserSummary(userId);
final badge = switch (summary) {
  (_, _, true)  => const PremiumBadge(),
  (_, var a, _) when a >= 60 => const SeniorBadge(),
  _ => const StandardBadge(),
};
```

## Object Pattern で深いネスト分解

ネストされたオブジェクトも型安全に分解できます。

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

// Object pattern で深いネストを一度に分解
String orderSummary(Order order) => switch (order) {
  Order(
    customer: User(name: final name, isPremium: true),
    status: PaymentStatus.completed,
  ) => '$name さん (プレミアム) の注文が完了しました',
  Order(
    customer: User(name: final name),
    status: PaymentStatus.failed,
  ) => '$name さんの支払いに失敗しました',
  Order(status: PaymentStatus.pending) => '処理中...',
  _ => '不明な状態',
};
```

## Flutter での実践: Supabase レスポンスの安全なハンドリング

```dart
// Supabase からのレスポンスを Result 型でラップ
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
    return Failure('データベースエラー: ${e.message}', error: e);
  } catch (e) {
    return Failure('予期しないエラーが発生しました', error: e);
  }
}

// Widget — sealed class の網羅チェックで安全に表示
class ProductListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(productsProvider);
    return result.when(
      data: (r) => switch (r) {
        Success(data: final products) when products.isEmpty =>
            const EmptyState(message: '商品が見つかりません'),
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

Dart 3 のパターンマッチングは、Flutter の状態管理コードを劇的に簡潔・安全にします。特に sealed class + switch expression の組み合わせは、Riverpod の `AsyncValue.when()` と相性が良く、個人開発コードの品質を大きく引き上げてくれます。

---

*このシリーズは Flutter × Supabase × インディー開発をテーマに毎週更新しています。*
