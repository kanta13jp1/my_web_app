---
title: "Supabase Auth 上級編 — カスタムクレーム・Row Level Security・セッション管理の実装"
tags: flutter,dart,個人開発,AI
published: true
---

# Supabase Auth 上級編 — カスタムクレーム・Row Level Security・セッション管理の実装

Supabase Auth の基本（メール認証・ソーシャルログイン）を使いこなした後は、カスタムクレームとRLSを組み合わせた本番グレードのセキュリティ設計が重要になります。

## JWT カスタムクレーム: app_metadata vs user_metadata

Supabase のJWTには2種類のメタデータフィールドがあります。

| フィールド | 書き込み権限 | 用途 |
|---|---|---|
| `user_metadata` | ユーザー自身 | 表示名・アバターURLなど公開プロフィール |
| `app_metadata` | サービスロール (管理者のみ) | ロール・課金状態・権限フラグ |

`app_metadata` はユーザーが改ざんできないため、権限管理に使うべきフィールドです。

```sql
-- app_metadata でカスタムロールを付与 (サービスロールキーが必要)
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"role": "admin"}'::jsonb
WHERE id = 'user-uuid';
```

```dart
// Flutter でカスタムクレームを読む
final user = supabase.auth.currentUser;
final role = user?.appMetadata['role'] as String?;
if (role == 'admin') {
  // 管理者UIを表示
}
```

## RLS ポリシーで auth.uid() を活用

Row Level Security はSQLレベルでデータアクセスを制御します。`auth.uid()` は現在のJWTから自動的にユーザーIDを取得します。

```sql
-- 自分のデータしか読めない基本ポリシー
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
USING (id = auth.uid());

-- 自分のデータだけ更新可能
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- カスタムクレームを使った管理者ポリシー
CREATE POLICY "Admins can view all users"
ON profiles FOR SELECT
USING (
  auth.jwt() -> 'app_metadata' ->> 'role' = 'admin'
);

-- チームメンバー間でデータ共有するポリシー
CREATE POLICY "Team members can view team posts"
ON posts FOR SELECT
USING (
  team_id IN (
    SELECT team_id FROM team_members
    WHERE user_id = auth.uid()
  )
);
```

## セッション有効期限管理と自動リフレッシュ

Supabase Auth はデフォルトでアクセストークン（1時間）とリフレッシュトークン（60日）を管理します。Flutter SDK はバックグラウンドで自動リフレッシュを行いますが、アプリ再起動時の状態復元に注意が必要です。

```dart
// main.dart での認証状態初期化
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://your-project.supabase.co',
    anonKey: 'your-anon-key',
  );
  runApp(const MyApp());
}

// 認証状態の変化をリアルタイムで監視
class AuthNotifier extends _$AuthNotifier {
  StreamSubscription? _sub;

  @override
  AuthState build() {
    final session = supabase.auth.currentSession;
    _sub = supabase.auth.onAuthStateChange.listen((data) {
      state = data.session != null
          ? AuthState.authenticated(data.session!)
          : const AuthState.unauthenticated();
    });
    ref.onDispose(() => _sub?.cancel());
    return session != null
        ? AuthState.authenticated(session)
        : const AuthState.unauthenticated();
  }
}
```

セッション切れを検出してログインページへリダイレクトする実装:

```dart
// GoRouter でのリダイレクト設定
redirect: (context, state) {
  final authState = ref.read(authNotifierProvider);
  final isLoggedIn = authState is AuthStateAuthenticated;
  final isOnAuthPage = state.matchedLocation == '/login';

  if (!isLoggedIn && !isOnAuthPage) return '/login';
  if (isLoggedIn && isOnAuthPage) return '/home';
  return null;
},
```

## Supabase Admin API でユーザー管理

バックエンドからユーザーを管理するには Edge Function 内でサービスロールクライアントを使います。

```typescript
// supabase/functions/admin-manage-user/index.ts
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const adminClient = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!  // サービスロールキー必須
)

Deno.serve(async (req) => {
  const { userId, role } = await req.json()

  // ユーザーのapp_metadataを更新
  const { error } = await adminClient.auth.admin.updateUserById(userId, {
    app_metadata: { role }
  })

  if (error) return new Response(JSON.stringify({ error: error.message }), {
    status: 400, headers: { 'Content-Type': 'application/json' }
  })

  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## Flutter での認証状態管理パターン

Riverpod と組み合わせた完全な認証フロー:

```dart
// サインイン処理
@riverpod
class SignInNotifier extends _$SignInNotifier {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.yourapp://login-callback',
      );
    });
  }
}
```

## まとめ

- `app_metadata` を権限管理に使い、ユーザーの改ざんを防ぐ
- RLSポリシーで `auth.uid()` と `auth.jwt()` を組み合わせてきめ細かいアクセス制御
- Flutter SDK の自動リフレッシュを活かしつつ、セッション切れを GoRouter で検出
- Admin API の操作は必ず Edge Function 内で行い、サービスロールキーをフロントエンドに露出しない
