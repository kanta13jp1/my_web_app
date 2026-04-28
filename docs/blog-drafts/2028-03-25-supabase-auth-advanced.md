---
title: "Supabase Auth 高度活用 — OAuth / Magic Link / MFA / RLS 連携"
tags: supabase,AI,個人開発,programming
published: true
---

# Supabase Auth 高度活用 — OAuth / Magic Link / MFA / RLS 連携

`.signInWithPassword()` の先にある認証パターンを整理する。

## OAuth (Google / GitHub) の実装

```dart
// Google OAuth (PKCE flow — Supabase Flutter SDK v2)
Future<void> signInWithGoogle() async {
  await supabase.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: kIsWeb
        ? null  // Web: current origin
        : 'io.supabase.myapp://login-callback',
    authScreenLaunchMode: LaunchMode.externalApplication,
  );
}

// Supabase Dashboard 設定:
// Authentication > Providers > Google
// → Client ID / Secret (Google Cloud Console から取得)
// → Redirect URL に `https://<project>.supabase.co/auth/v1/callback` を登録
```

**Flutter Deep Link 設定** (`android/app/src/main/AndroidManifest.xml`):

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="io.supabase.myapp" android:host="login-callback" />
</intent-filter>
```

## Magic Link (パスワードレス認証)

```dart
// Magic Link 送信
await supabase.auth.signInWithOtp(
  email: email,
  emailRedirectTo: 'io.supabase.myapp://login-callback',
);

// リンクをタップ後、onAuthStateChange で session を受け取る
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedIn) {
    Navigator.pushReplacementNamed(context, '/home');
  }
});
```

Supabase Dashboard > Authentication > Email Templates でメール文面をカスタマイズ可能。
Magic Link の有効期限は デフォルト 1 時間 (設定変更可)。

## MFA (多要素認証) — TOTP

```dart
// MFA 登録フロー
final response = await supabase.auth.mfa.enroll(
  factorType: FactorType.totp,
  issuer: 'MyApp',
);

// QR コードを表示 (Google Authenticator / Authy 対応)
final qrCode = response.totp?.qrCode;   // base64 encoded PNG
final secret = response.totp?.secret;   // 手動入力用

// 6桁コードで検証
final challengeResponse = await supabase.auth.mfa.challenge(
  factorId: response.id,
);
await supabase.auth.mfa.verify(
  factorId: response.id,
  challengeId: challengeResponse.id,
  code: userInputCode, // TOTP 6桁
);
```

## Auth と RLS の連携

```sql
-- auth.uid() で現在ログイン中ユーザーの ID を取得
CREATE POLICY "users can only see own tasks"
ON tasks
FOR SELECT
USING (user_id = auth.uid());

-- auth.jwt() でカスタムクレームを取得 (Premium 判定など)
CREATE POLICY "premium users can use advanced features"
ON ai_results
FOR INSERT
WITH CHECK (
  (auth.jwt() -> 'user_metadata' ->> 'plan') = 'premium'
);
```

**Flutter で user_metadata を更新**:

```dart
await supabase.auth.updateUser(
  UserAttributes(
    data: {'plan': 'premium', 'onboarded': true},
  ),
);
```

## セッション管理のベストプラクティス

```dart
// アプリ起動時に session を復元
Future<void> initAuth() async {
  final session = supabase.auth.currentSession;
  if (session == null) {
    // 未ログイン → ログイン画面へ
    return;
  }

  // Token が期限切れ間近なら自動更新 (SDK が自動処理するが明示も可)
  if (session.isExpired) {
    await supabase.auth.refreshSession();
  }
}

// サインアウト
await supabase.auth.signOut();
```

## まとめ

```
OAuth          → Google/GitHub (PKCE flow / Deep Link)
Magic Link     → パスワードレス (onAuthStateChange でセッション受取)
MFA (TOTP)     → enroll → challenge → verify の 3ステップ
RLS 連携       → auth.uid() / auth.jwt() でポリシー設定
```

Supabase Auth は Postgres と直結しているため、RLS を活用するとバックエンド実装が激減する。
