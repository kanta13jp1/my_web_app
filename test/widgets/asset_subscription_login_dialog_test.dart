import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_subscription_login_service.dart';
import 'package:my_web_app/widgets/asset_subscription_login_dialog.dart';

void main() {
  testWidgets('signs in inside the dialog and returns success', (tester) async {
    final service = _FakeLoginService();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                builder: (_) =>
                    AssetSubscriptionLoginDialog(loginService: service),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('subscription_login_email')),
      'owner@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('subscription_login_password')),
      'secret-password',
    );
    await tester.tap(find.byKey(const Key('subscription_login_submit')));
    await tester.pumpAndSettle();

    expect(service.email, 'owner@example.com');
    expect(service.password, 'secret-password');
    expect(result, isTrue);
    expect(find.text('ログインして解析を続ける'), findsNothing);
  });

  testWidgets('keeps the dialog open and shows a login error', (tester) async {
    final service = _FakeLoginService(
      error: const AssetSubscriptionLoginException('認証情報が一致しません。'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetSubscriptionLoginDialog(loginService: service),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('subscription_login_email')),
      'owner@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('subscription_login_password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('subscription_login_submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subscription_login_error')), findsOneWidget);
    expect(find.text('認証情報が一致しません。'), findsOneWidget);
  });
}

class _FakeLoginService implements AssetSubscriptionLoginService {
  _FakeLoginService({this.error});

  final AssetSubscriptionLoginException? error;
  String? email;
  String? password;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    this.email = email;
    this.password = password;
    if (error != null) throw error!;
  }
}
