---
title: "Flutter Riverpod 状態管理入門 — Provider から AsyncNotifier まで実践パターン"
tags: flutter,AI,個人開発,buildinpublic
published: true
---

# Flutter Riverpod 状態管理入門 — Provider から AsyncNotifier まで実践パターン

Flutter の状態管理は選択肢が多い。Riverpod を選んだ理由と、実際の使いパターンを解説する。

## なぜ Riverpod か

```
setState:     単一ウィジェット内の状態 → これで十分なケースも多い
Provider:     シンプル・Flutter の DI
Riverpod:     Provider の後継・テスト容易・コンパイル時安全
Bloc:         ボイラープレートが多い → 大規模チーム向け
```

個人開発には Riverpod が最適。コンパイル時エラー検出 + テストしやすい + Provider より直感的。

## セットアップ

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
    const ProviderScope(  // アプリ全体を ProviderScope でラップ
      child: MyApp(),
    ),
  );
}
```

## 基本パターン1: Provider (静的値)

```dart
// 定数・設定値に使う
final appNameProvider = Provider<String>((ref) => '自分株式会社');

// ウィジェット内で使う
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appName = ref.watch(appNameProvider);
    return Text(appName);
  }
}
```

## 基本パターン2: StateProvider (シンプルな状態)

```dart
// カウンター・フラグ・選択値など
final counterProvider = StateProvider<int>((ref) => 0);
final isDarkModeProvider = StateProvider<bool>((ref) => false);

// 更新
ref.read(counterProvider.notifier).state++;
ref.read(isDarkModeProvider.notifier).state = true;
```

## 基本パターン3: FutureProvider (非同期データ)

```dart
// Supabase からデータ取得
final achievementsProvider = FutureProvider<List<Achievement>>((ref) async {
  final data = await supabase.from('development_achievements').select('*').order('completed_at', ascending: false);
  return data.map((e) => Achievement.fromJson(e)).toList();
});

// ウィジェット
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

## 基本パターン4: AsyncNotifier (更新できる非同期状態)

```dart
// コード生成を使う場合 (riverpod_generator)
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

  // データを追加してリストを再取得
  Future<void> addAchievement(String title, String description) async {
    await supabase.from('development_achievements').insert({
      'title': title,
      'description': description,
      'completed_at': DateTime.now().toIso8601String(),
    });
    ref.invalidateSelf(); // キャッシュを無効化 → 再fetch
  }
}
```

## Provider 間の依存関係

```dart
// auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return supabase.auth.onAuthStateChange.map((e) => e.session?.user);
});

// auth に依存する provider
final userProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;

  final data = await supabase.from('profiles').select().eq('id', user.id).single();
  return Profile.fromJson(data);
});
```

`ref.watch()` で他の provider を監視 → 依存する provider が変わると自動再計算。

## テストが書きやすい

```dart
// テスト用 mock
final testAchievements = [
  Achievement(id: '1', title: 'Test Achievement', completedAt: DateTime.now()),
];

testWidgets('shows achievements', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // FutureProvider を mock データで上書き
        achievementsProvider.overrideWith((_) async => testAchievements),
      ],
      child: const MaterialApp(home: AchievementsPage()),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.text('Test Achievement'), findsOneWidget);
});
```

`ProviderScope.overrides` で各テストでモックを差し込める。

## まとめ

Riverpod の選び方:
- 静的値 → `Provider`
- シンプルな変更可能状態 → `StateProvider`
- 非同期取得 (読み取り専用) → `FutureProvider`
- 非同期取得 + 更新 → `AsyncNotifier`
- リアルタイムストリーム → `StreamProvider`

まず `FutureProvider` から始める。複雑になってきたら `AsyncNotifier` に移行する。
