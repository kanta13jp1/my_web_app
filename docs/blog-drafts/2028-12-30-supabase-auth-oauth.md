---
title: "Supabase Auth 完全ガイド — OAuth・Magic Link・Row Level Security"
tags: supabase,flutter,AI,個人開発
published: true
---

# Supabase Auth 完全ガイド — OAuth・Magic Link・Row Level Security

Supabase の認証システムは多彩な方式をサポートしています。Google OAuth・Magic Link・メール/パスワードの実装から、Row Level Security (RLS) による安全なデータアクセス制御まで解説します。

## Supabase Auth の全体像

```
ユーザー → [OAuth/Magic Link/Email] → Supabase Auth → JWT → RLS → PostgreSQL
```

Supabase Auth は GoTrue をベースにした認証サービス。発行された JWT を使って Supabase のすべてのサービス (DB / Storage / Edge Functions) にアクセスできます。

## Flutter への組み込み

```yaml
# pubspec.yaml
dependencies:
  supabase_flutter: ^2.5.0
  google_sign_in: ^6.2.1
  app_links: ^6.1.0  # Deep Link (Magic Link 用)
```

```dart
// main.dart
await Supabase.initialize(
  url: 'https://xxxx.supabase.co',
  anonKey: 'your-anon-key',
);
```

## Google OAuth

```dart
Future<void> signInWithGoogle() async {
  final googleUser = await GoogleSignIn(
    serverClientId: 'your-web-client-id.apps.googleusercontent.com',
  ).signIn();
  if (googleUser == null) return;

  final googleAuth = await googleUser.authentication;
  await supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: googleAuth.idToken!,
    accessToken: googleAuth.accessToken,
  );
}
```

## Magic Link (メールリンク認証)

パスワード不要で安全。メールアドレスだけでサインイン:

```dart
// Magic Link 送信
await supabase.auth.signInWithOtp(
  email: 'user@example.com',
  emailRedirectTo: 'myapp://auth/callback',
);

// Deep Link で受け取り (app_links)
AppLinks().uriLinkStream.listen((uri) async {
  if (uri.toString().contains('auth/callback')) {
    await supabase.auth.getSessionFromUrl(uri);
  }
});
```

## セッション管理

```dart
// 認証状態の変化を監視
supabase.auth.onAuthStateChange.listen((data) {
  final session = data.session;
  if (session != null) {
    // ログイン済み → ホーム画面へ
    router.go('/home');
  } else {
    // 未ログイン → ログイン画面へ
    router.go('/login');
  }
});

// 現在のユーザー取得
final user = supabase.auth.currentUser;
```

## Row Level Security (RLS) の設定

RLS を使うことで、ユーザーは自分のデータにしかアクセスできなくなります:

```sql
-- RLS を有効化
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- 自分のデータのみ読み取り可
CREATE POLICY "own_notes_select" ON notes
  FOR SELECT USING (auth.uid() = user_id);

-- 自分のデータのみ挿入可
CREATE POLICY "own_notes_insert" ON notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 自分のデータのみ更新・削除可
CREATE POLICY "own_notes_update" ON notes
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "own_notes_delete" ON notes
  FOR DELETE USING (auth.uid() = user_id);
```

## Edge Function での認証確認

```typescript
// supabase/functions/protected-action/index.ts
import { createClient } from 'npm:@supabase/supabase-js@2'

Deno.serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return new Response('Unauthorized', { status: 401 })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) return new Response('Unauthorized', { status: 401 })

  // 認証済みユーザーの処理
  return new Response(JSON.stringify({ userId: user.id }))
})
```

## まとめ

Supabase Auth は OAuth・Magic Link・RLS を組み合わせることで、パスワードレスでセキュアな認証を実現できます。Flutter との連携も `supabase_flutter` パッケージで簡単に実装できます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
