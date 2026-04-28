---
title: "Supabase Auth 実装ガイド — JWT / Magic Link / OAuth を Flutter で使う"
tags: supabase,flutter,個人開発,postgresql
published: true
---

# Supabase Auth 実装ガイド — JWT / Magic Link / OAuth を Flutter で使う

Supabase Auth は PostgreSQL の RLS と直結しています。「認証 → 認可 → データアクセス」が一つの仕組みで完結する設計が強力です。Flutter での実装パターンを全公開します。

## Supabase Auth の設計思想

```
ユーザー → Supabase Auth → JWT 発行
                          ↓
                   PostgreSQL RLS で自動フィルタ
                   auth.uid() = user_id
```

「認証サービス」と「データベース」が分離していないのが Supabase の強み。JWT が自動的に DB クエリに適用される。

## Flutter のセットアップ

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.0.0
```

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    anonKey: 'your-anon-key',
  );
  runApp(const MyApp());
}

// Supabase クライアントにアクセス
final supabase = Supabase.instance.client;
```

## Magic Link 認証 (メールリンク)

最もシンプルなパスワードレス認証:

```dart
// 送信
await supabase.auth.signInWithOtp(
  email: 'user@example.com',
  emailRedirectTo: 'io.supabase.myapp://login-callback/',
);

// Flutter のディープリンクで受け取る (main.dart)
supabase.auth.onAuthStateChange.listen((data) {
  final AuthChangeEvent event = data.event;
  final Session? session = data.session;

  if (event == AuthChangeEvent.signedIn && session != null) {
    // ログイン成功 → ホーム画面へ
    context.go('/home');
  }
});
```

## メール / パスワード認証

```dart
// 新規登録
final response = await supabase.auth.signUp(
  email: 'user@example.com',
  password: 'secure-password',
);

// ログイン
final response = await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'secure-password',
);

// ログアウト
await supabase.auth.signOut();

// 現在のセッション確認
final session = supabase.auth.currentSession;
final user = supabase.auth.currentUser;
```

## OAuth (Google / GitHub)

```dart
// Google でサインイン
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'io.supabase.myapp://login-callback/',
  authScreenLaunchMode: LaunchMode.externalApplication,
);
```

`redirectTo` はモバイルではカスタム URL スキーム、Web では `window.location.origin` を指定。

## セッション管理: onAuthStateChange

```dart
// ウィジェット初期化時にリッスン
class AuthWrapper extends StatefulWidget {
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        context.go('/home');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
```

## 匿名ガード: 未ログインユーザーをリダイレクト

```dart
// 各ページの initState で確認
@override
void initState() {
  super.initState();
  if (supabase.auth.currentUser == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go('/login');
    });
  }
}
```

または GoRouter の redirect で一元管理:

```dart
GoRouter(
  redirect: (context, state) {
    final isLoggedIn = supabase.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/login';
    
    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/home';
    return null;
  },
  routes: [...],
);
```

## Edge Function での JWT 検証

```typescript
// Edge Function 内でユーザーを取得
async function getAuthenticatedUser(req: Request) {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
  );

  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) throw new Error('Unauthorized');
  return user;
}
```

`SUPABASE_ANON_KEY` + JWT でユーザー認証 → RLS が自動適用。`SUPABASE_SERVICE_ROLE_KEY` は管理操作のみ。

## まとめ

Supabase Auth の実装チェックリスト:
1. `supabase.auth.currentUser` で null チェック → 匿名ガード
2. `onAuthStateChange` で状態変化をリッスン → ルーティング自動化
3. Magic Link / OAuth でパスワードレス → UX 向上
4. RLS と組み合わせる → DB 層でデータアクセス制御
5. EF では ANON_KEY + JWT → Service Role は管理のみ

認証と認可が DB 層で統合されているのが Supabase の最大の強み。Firebase Auth + Firestore の分離したアーキテクチャより、コードがシンプルになります。
