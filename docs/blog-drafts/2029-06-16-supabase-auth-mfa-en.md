---
title: "Supabase Auth MFA Guide — Adding TOTP and OTP to Flutter Apps"
tags: supabase,flutter,webdev,indiedev
published: true
---

# Supabase Auth MFA Guide — Adding TOTP and OTP to Flutter Apps

Supabase Auth has built-in MFA support. Here's how to add TOTP (Google Authenticator compatible) to your Flutter app — covering enrollment, verification, and RLS enforcement.

## How MFA Works

1. User signs in (email + password) — AAL1
2. If MFA is enrolled → Challenge issued
3. User enters 6-digit code
4. Auth upgraded to AAL2

## TOTP Enrollment

```dart
class MFAService {
  final SupabaseClient _client;
  MFAService(this._client);

  Future<TOTPSetupResult> enrollTOTP() async {
    final response = await _client.auth.mfa.enroll(factorType: FactorType.totp);
    return TOTPSetupResult(
      id: response.id,
      qrCodeUri: response.totp!.qrCode,
      secret: response.totp!.secret,
    );
  }
}
```

```dart
// QR code display
QrImageView(data: setup.qrCodeUri, size: 200)
Text('Manual: ${setup.secret}', style: const TextStyle(fontFamily: 'monospace'))
```

## Verify and Activate TOTP

```dart
Future<void> verifyAndActivate(String factorId, String code) async {
  final challenge = await _client.auth.mfa.challenge(factorId: factorId);
  await _client.auth.mfa.verify(
    factorId: factorId,
    challengeId: challenge.id,
    code: code,
  );
}
```

## MFA Login Flow

```dart
Future<void> signInWithMFA(String email, String password) async {
  await _client.auth.signInWithPassword(email: email, password: password);

  final factors = await _client.auth.mfa.listFactors();
  final totp = factors.totp.firstOrNull;

  if (totp == null || totp.status != FactorStatus.verified) return;

  final challenge = await _client.auth.mfa.challenge(factorId: totp.id);

  Navigator.push(context, MaterialPageRoute(
    builder: (_) => MFAVerifyPage(factorId: totp.id, challengeId: challenge.id),
  ));
}
```

```dart
class MFAVerifyPage extends StatefulWidget {
  final String factorId;
  final String challengeId;

  @override
  State<MFAVerifyPage> createState() => _MFAVerifyPageState();
}

class _MFAVerifyPageState extends State<MFAVerifyPage> {
  final _ctrl = TextEditingController();

  Future<void> _verify() async {
    await supabase.auth.mfa.verify(
      factorId: widget.factorId,
      challengeId: widget.challengeId,
      code: _ctrl.text.trim(),
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Two-Factor Auth')),
    body: Column(children: [
      const Text('Enter the 6-digit code from your authenticator app'),
      TextField(controller: _ctrl, keyboardType: TextInputType.number, maxLength: 6),
      ElevatedButton(onPressed: _verify, child: const Text('Verify')),
    ]),
  );
}
```

## AAL (Assurance Level) Checks

```dart
// Check if user has completed MFA (aal2)
final aal = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
if (aal.currentLevel != AuthenticatorAssuranceLevels.aal2) {
  // Redirect to MFA re-auth
}
```

## Enforce MFA in RLS

```sql
-- Only allow aal2 users to access sensitive data
CREATE POLICY "require_mfa"
ON sensitive_table FOR ALL
USING ((auth.jwt() ->> 'aal') = 'aal2');
```

## Business Impact

Adding MFA opened the door to enterprise customers who require it as a compliance checkbox. It's a feature that costs ~4 hours to implement but unlocks a whole segment of paying users.

---

Is MFA on your roadmap? What's your biggest hurdle implementing it? Drop a comment.
