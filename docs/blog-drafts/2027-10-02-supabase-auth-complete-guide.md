---
title: "Supabase Auth 完全ガイド — Magic Link / OAuth / MFA の実装"
tags: supabase,flutter,個人開発,AI
published: true
---

# Supabase Auth 完全ガイド — Magic Link / OAuth / MFA の実装

「ユーザー登録をどう実装するか」は個人開発の最初の壁。Supabase Auth の3パターンを実装例付きで解説する。

## なぜ Supabase Auth か

```
自前実装のコスト:
  - パスワードハッシュ (bcrypt/Argon2)
  - セッション管理 (JWT + refresh)
  - OAuth フロー実装
  - メール送信 + トークン検証
  - MFA (TOTP + バックアップコード)
  → 最低 2週間 + セキュリティリスク

Supabase Auth:
  → 設定 30分 + 本番品質
```

## Magic Link (メールリンク認証)

```dart
// ログイン: メールを送るだけ
await supabase.auth.signInWithOtp(email: 'user@example.com');

// メールのリンクをクリック → アプリにコールバック
// AndroidManifest.xml / Info.plist にディープリンク設定が必要
```

**Flutter でのディープリンク処理**:

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

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 認証状態の変化を監視
    supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        // ログイン成功 → ホーム画面に遷移
        context.go('/home');
      }
    });
  }
}
```

## OAuth (Google / GitHub / Apple)

```dart
// Google ログイン (Flutter Web)
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'https://your-app.web.app/auth/callback',
);

// GitHub ログイン
await supabase.auth.signInWithOAuth(
  OAuthProvider.github,
  redirectTo: kIsWeb
    ? null  // Web: Supabase が自動処理
    : 'io.your.app://login-callback',  // モバイル: カスタムスキーム
);
```

**Supabase Dashboard 設定**:

```
Authentication → Providers → Google
  Client ID: [Google Cloud Console から取得]
  Client Secret: [Google Cloud Console から取得]
  Redirect URL: https://your-project.supabase.co/auth/v1/callback
```

**ユーザー情報の取得**:

```dart
final user = supabase.auth.currentUser;
final metadata = user?.userMetadata;
print(metadata?['full_name']);  // Google: 名前
print(metadata?['avatar_url']); // Google: アイコン URL
```

## MFA (多要素認証)

```dart
// 1. TOTP (Google Authenticator 等) の設定を開始
final response = await supabase.auth.mfa.enroll(
  factorType: FactorType.totp,
);
final qrCodeUrl = response.totp.qrCode; // QR コードを表示
final secret = response.totp.secret;    // シークレットを表示

// 2. ユーザーが QR コードを読み取り → OTP 入力
final verifyResponse = await supabase.auth.mfa.verify(
  factorId: response.id,
  challengeId: challengeResponse.id,
  code: '123456', // ユーザー入力の OTP
);

// 3. 以後のログインでは OTP も要求
final challengeResponse = await supabase.auth.mfa.challenge(
  factorId: factorId,
);
await supabase.auth.mfa.verify(
  factorId: factorId,
  challengeId: challengeResponse.id,
  code: otpController.text,
);
```

## セッション管理と RLS

```dart
// ログアウト
await supabase.auth.signOut();

// 現在のセッション
final session = supabase.auth.currentSession;
final accessToken = session?.accessToken;

// RLS ポリシーと組み合わせ
// profiles テーブルは自分のデータのみアクセス可
// CREATE POLICY "users can read own profile"
//   ON profiles FOR SELECT
//   USING (auth.uid() = user_id);
```

**Row Level Security との連動**:

```dart
// supabase.from('profiles') は自動で auth.uid() を付与
// → RLS が有効なら他ユーザーのデータは取れない
final myProfile = await supabase
    .from('profiles')
    .select()
    .single(); // 自分のデータだけ返る
```

## まとめ

```
メールリンク → Magic Link (パスワードレス)
SNS連携     → OAuth (Google/GitHub/Apple)
セキュリティ強化 → MFA (TOTP)
データ保護  → RLS (auth.uid() 連動)
```

Supabase Auth は設定だけで本番品質の認証を実現できる。個人開発では Magic Link + Google OAuth から始めて、B2B 展開時に MFA + RLS を強化するのが最もコスパ良い。

