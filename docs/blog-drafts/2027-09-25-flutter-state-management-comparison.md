---
title: "Flutter 状態管理比較 — Provider / Riverpod / Bloc の選び方"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter 状態管理比較 — Provider / Riverpod / Bloc の選び方

「どれを使えばいいか分からない」を終わりにする。3つの実装例と判断基準を提示する。

## 状態管理が必要になる瞬間

```dart
// ❌ NG: setState で複数ウィジェット間共有は壊れる
class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? username; // この値を別ページでも使いたい → setState では無理

  @override
  Widget build(BuildContext context) { ... }
}
```

**判断基準**:

```
1ウィジェット内の状態 → setState で十分
複数ウィジェット間共有 → 状態管理ライブラリ必要
```

## Provider: シンプルな依存注入

```dart
// 1. ChangeNotifier でモデルを定義
class UserModel extends ChangeNotifier {
  String? _username;
  String? get username => _username;

  Future<void> loadUser(String id) async {
    final res = await supabase.from('profiles').select().eq('id', id).single();
    _username = res['username'] as String;
    notifyListeners(); // ウィジェットに更新を通知
  }
}

// 2. 上位で提供
ChangeNotifierProvider(
  create: (_) => UserModel(),
  child: MaterialApp(home: ProfilePage()),
)

// 3. ウィジェットで消費
class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel>();
    return Text(user.username ?? 'Loading...');
  }
}
```

**Provider の弱点**:

```
- context が必要 → テストしにくい
- 依存関係が増えると MultiProvider が肥大化
- 非同期状態 (loading/error/data) を手動管理
```

## Riverpod: Provider の進化版

```dart
// 1. Provider 定義 (グローバル / context 不要)
@riverpod
Future<Profile> userProfile(UserProfileRef ref, String userId) async {
  return supabase
      .from('profiles')
      .select()
      .eq('id', userId)
      .single()
      .then((r) => Profile.fromJson(r));
}

// 2. Widget で消費 (ConsumerWidget)
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

**Riverpod の強み**:

```dart
// 依存関係の自動解決
@riverpod
Future<List<Post>> userPosts(UserPostsRef ref) async {
  final profile = await ref.watch(userProfileProvider('user-123').future);
  return fetchPosts(profile.id); // profile が更新されたら自動再実行
}

// テストでの Provider Override
final container = ProviderContainer(
  overrides: [
    userProfileProvider('test-id').overrideWith(
      (ref) => Future.value(Profile(id: 'test-id', username: 'test')),
    ),
  ],
);
```

## Bloc: 大規模アプリ向けイベント駆動

```dart
// 1. Event 定義
abstract class UserEvent {}
class LoadUser extends UserEvent {
  final String id;
  LoadUser(this.id);
}

// 2. State 定義
abstract class UserState {}
class UserLoading extends UserState {}
class UserLoaded extends UserState {
  final Profile profile;
  UserLoaded(this.profile);
}
class UserError extends UserState {
  final String message;
  UserError(this.message);
}

// 3. Bloc 実装
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc() : super(UserLoading()) {
    on<LoadUser>((event, emit) async {
      emit(UserLoading());
      try {
        final profile = await fetchProfile(event.id);
        emit(UserLoaded(profile));
      } catch (e) {
        emit(UserError(e.toString()));
      }
    });
  }
}

// 4. Widget
BlocBuilder<UserBloc, UserState>(
  builder: (context, state) {
    if (state is UserLoading) return const CircularProgressIndicator();
    if (state is UserError) return Text(state.message);
    if (state is UserLoaded) return Text(state.profile.username);
    return const SizedBox();
  },
)
```

## 選び方まとめ

```
小規模 (1-3 画面) / 初学者 → Provider
中規模 / テスタビリティ重視 → Riverpod (推奨)
大規模チーム / 複雑なビジネスロジック → Bloc
```

**個人開発での推奨**:

```
Riverpod + code_gen (@riverpod) が最もコスパ良い。
- 非同期状態 (AsyncValue) を自動ハンドリング
- Provider 間の依存関係を ref.watch で宣言的に管理
- テストで ProviderContainer override → モック不要
```

個人開発は「移行コストより開発速度」が最優先。Riverpod で始めて、チームが必要になったら Bloc へ移行するのがリスク最小のパス。

