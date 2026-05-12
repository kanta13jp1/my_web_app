---
title: "Supabase Auth MFA 実装ガイド — TOTP・SMS・メール OTP で多要素認証を追加する"
tags: flutter,supabase,個人開発,AI
published: true
---

# Supabase Auth MFA 実装ガイド — TOTP・SMS・メール OTP で多要素認証を追加する

Supabase Auth は MFA (Multi-Factor Authentication) を組み込みでサポートしています。Flutter アプリに TOTP (Google Authenticator 互換) や SMS OTP を追加する方法を解説します。

## MFA の仕組み

1. ユーザーが通常ログイン (email/password)
2. MFA が有効な場合 → Challenge が発行される
3. ユーザーが 2 要素コードを入力
4. 認証完了

## TOTP (時間ベースワンタイムパスワード) の実装

Google Authenticator / Authy 互換。最も安全で推奨。

### Step 1: TOTP の登録

```dart
class MFAService {
  final SupabaseClient _client;
  MFAService(this._client);

  Future<TOTPSetupResult> enrollTOTP() async {
    final response = await _client.auth.mfa.enroll(
      factorType: FactorType.totp,
    );

    return TOTPSetupResult(
      id: response.id,
      // QR コード URI (Google Authenticator でスキャン)
      qrCodeUri: response.totp!.qrCode,
      secret: response.totp!.secret,  // 手動入力用
    );
  }
}
```

```dart
// UI: QR コード表示
class TOTPSetupPage extends StatelessWidget {
  final TOTPSetupResult setup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Text('Google Authenticator でスキャン'),
          QrImageView(data: setup.qrCodeUri, size: 200),
          Text('手動入力: ${setup.secret}', style: const TextStyle(fontFamily: 'monospace')),
          TOTPVerifyForm(factorId: setup.id),
        ],
      ),
    );
  }
}
```

### Step 2: TOTP コード検証 & 有効化

```dart
Future<void> verifyAndActivateTOTP(String factorId, String code) async {
  // Challenge 作成
  final challenge = await _client.auth.mfa.challenge(factorId: factorId);

  // コード検証
  await _client.auth.mfa.verify(
    factorId: factorId,
    challengeId: challenge.id,
    code: code,
  );
  // 成功 = TOTP 有効化完了
}
```

## ログインフローへの MFA 組み込み

```dart
Future<void> signInWithMFA(String email, String password) async {
  // Step 1: 通常ログイン
  final response = await _client.auth.signInWithPassword(
    email: email,
    password: password,
  );

  // MFA が必要か確認
  final factors = await _client.auth.mfa.listFactors();
  final totpFactor = factors.totp.firstOrNull;

  if (totpFactor == null || totpFactor.status != FactorStatus.verified) {
    // MFA 未設定 → ログイン完了
    return;
  }

  // Step 2: MFA Challenge
  final challenge = await _client.auth.mfa.challenge(
    factorId: totpFactor.id,
  );

  // Step 3: UI でコード入力待ち (別画面へ遷移)
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => MFAVerifyPage(
      factorId: totpFactor.id,
      challengeId: challenge.id,
    ),
  ));
}
```

```dart
// MFA 認証画面
class MFAVerifyPage extends StatefulWidget {
  final String factorId;
  final String challengeId;

  @override
  State<MFAVerifyPage> createState() => _MFAVerifyPageState();
}

class _MFAVerifyPageState extends State<MFAVerifyPage> {
  final _codeController = TextEditingController();

  Future<void> _verify() async {
    await supabase.auth.mfa.verify(
      factorId: widget.factorId,
      challengeId: widget.challengeId,
      code: _codeController.text.trim(),
    );
    // 認証完了 → ホームへ
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('2段階認証')),
      body: Column(
        children: [
          const Text('認証アプリの 6 桁コードを入力'),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: '6桁コード'),
          ),
          ElevatedButton(onPressed: _verify, child: const Text('認証')),
        ],
      ),
    );
  }
}
```

## MFA 状態の管理

```dart
// Assurance Level チェック (AAL)
Future<AuthMFAGetAuthenticatorAssuranceLevelResponse> checkAAL() async {
  return _client.auth.mfa.getAuthenticatorAssuranceLevel();
}

// aal1 = パスワードのみ / aal2 = MFA 完了
// 機密画面でチェック
Future<void> checkForSensitivePage() async {
  final aal = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aal.currentLevel != AuthenticatorAssuranceLevels.aal2) {
    // MFA 再認証へ
    Navigator.push(context, MaterialPageRoute(builder: (_) => MFAReauthPage()));
  }
}
```

## RLS での MFA 強制

```sql
-- MFA 完了ユーザーのみアクセス可能
CREATE POLICY "MFA required for sensitive data"
ON sensitive_table
FOR ALL
USING (
  (auth.jwt() ->> 'aal') = 'aal2'
);
```

個人開発アプリに MFA を追加したら、エンタープライズ顧客からの問い合わせが増えました。セキュリティ要件が厳しい法人向けに差別化できます。

---

あなたのアプリは MFA に対応していますか？ぜひコメントで教えてください！
