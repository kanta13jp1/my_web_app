---
title: "Flutter 状態管理ライブラリ比較 2024 — Riverpod・Bloc・Provider・GetX の選び方"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter 状態管理ライブラリ比較 2024 — Riverpod・Bloc・Provider・GetX の選び方

Flutter アプリを本番運用していると、必ず直面するのが「どの状態管理ライブラリを選ぶか」という問題です。本記事では、現在主流の 4 つのライブラリを実務視点で比較し、プロジェクト規模・チーム構成・Supabase との相性も含めて選び方を解説します。

## 4 ライブラリ機能比較表

| 項目 | Riverpod 2.0 | Bloc | Provider | GetX |
|------|------------|------|----------|------|
| 学習コスト | 中 | 高 | 低 | 低〜中 |
| テスト容易性 | ◎ | ◎ | ○ | △ |
| ボイラープレート | 少ない | 多い | 少ない | 少ない |
| コンパイル安全性 | ◎ | ○ | △ | △ |
| コミュニティ規模 | 大 | 大 | 大（legacy） | 中 |
| 型安全な非同期 | ◎（AsyncValue） | ○ | △ | △ |
| DevTools 対応 | ◎ | ◎ | ○ | △ |

## Riverpod 2.0 がおすすめな理由

Riverpod 2.0 は `@riverpod` アノテーションによるコード生成が安定し、`AsyncNotifier` で非同期状態を型安全に扱えます。Supabase のリアルタイムストリームとの相性も抜群です。

```dart
// Supabase からユーザー一覧を取得する Provider
@riverpod
Future<List<UserProfile>> userProfiles(UserProfilesRef ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final response = await supabase
      .from('profiles')
      .select()
      .order('created_at', ascending: false);
  return response.map((json) => UserProfile.fromJson(json)).toList();
}

// Widget での使用
class UserListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userProfilesProvider);
    return usersAsync.when(
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (ctx, i) => UserTile(user: users[i]),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => ErrorWidget(e.toString()),
    );
  }
}
```

`ref.invalidate()` でキャッシュを手動でリフレッシュでき、Supabase の INSERT/UPDATE/DELETE 後に即座に画面を更新するパターンが直感的に書けます。

## Bloc が向くケース

Bloc は **大規模チーム・厳格なイベント駆動アーキテクチャ** に向いています。Event → State の流れが明示的であり、コードレビューで意図が伝わりやすいのが強みです。

```dart
// Event
abstract class AuthEvent {}
class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested({required this.email, required this.password});
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._supabase) : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _supabase.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      emit(AuthSuccess());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }
}
```

5 名以上のチームで、各機能をフィーチャーブランチで並行開発する場合、Bloc の明示的な構造はコンフリクトを減らしてくれます。

## GetX のリスク

GetX は「軽量・少ない記述量」が魅力ですが、以下のリスクがあります。

- **巨大な API 設計**: 状態管理・ルーティング・DI が一体化しており、部分的採用が難しい
- **依存注入の混在**: `Get.find()` がグローバル状態になりやすく、テストでのモック差し替えが煩雑
- **メンテナンス不安**: コミュニティの断片化や、Flutter 本体のアップデートへの追随遅延のリスク

個人開発の小規模プロトタイプなら許容できますが、長期運用するプロダクトには避けたほうが無難です。

## Provider から Riverpod への移行パターン

`ChangeNotifierProvider` を使っている場合、段階的に移行できます。

```dart
// Before: Provider
class UserNotifier extends ChangeNotifier {
  UserProfile? _user;
  UserProfile? get user => _user;

  Future<void> loadUser(String id) async {
    _user = await supabase.from('profiles').select().eq('id', id).single();
    notifyListeners();
  }
}

// After: Riverpod (AsyncNotifier)
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  FutureOr<UserProfile?> build(String id) async {
    return ref.watch(supabaseClientProvider)
        .from('profiles')
        .select()
        .eq('id', id)
        .single()
        .then((json) => UserProfile.fromJson(json));
  }
}
```

移行は「新規機能は Riverpod / 既存機能は Provider のまま」という並行期間を設けると安全です。`ProviderScope` と `MultiProvider` は共存できます。

## Supabase との相性まとめ

Supabase の `stream()` を使ったリアルタイム更新は、Riverpod の `StreamProvider` が最も自然に統合できます。Bloc も `StreamSubscription` を `on<>` ハンドラで管理できますが記述量が増えます。

個人開発・中規模チームなら **Riverpod 2.0 一択**。5 名以上の大規模チームで厳格な設計が必要なら **Bloc** を検討してください。

---

*このシリーズは Flutter × Supabase × インディー開発をテーマに毎週更新しています。*
