import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/account_deletion_request.dart';
import 'package:my_web_app/pages/account_deletion_page.dart';
import 'package:my_web_app/services/account_lifecycle_service.dart';

void main() {
  testWidgets('distinguishes subscription cancellation from account deletion', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeAccountLifecycleGateway()));
    await tester.pumpAndSettle();

    expect(find.text('サブスクリプション解約'), findsOneWidget);
    expect(find.text('退会を申請する'), findsOneWidget);
    expect(find.textContaining('解約だけではアカウントや保存データは削除されません'), findsOneWidget);
    expect(find.textContaining('申請から30日間'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('account-deletion-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('requires exact confirmation and submits a cancellable request', (
    tester,
  ) async {
    final gateway = _FakeAccountLifecycleGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('account-deletion-confirmation')),
      'アカウントを削除する',
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const Key('account-deletion-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-deletion-submit')));
    await tester.pumpAndSettle();
    expect(find.text('退会申請を送信しますか？'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('account-deletion-final-confirm')),
          )
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('退会申請を送信'));
    await tester.pumpAndSettle();

    expect(gateway.requestedConfirmation, 'アカウントを削除する');
    expect(find.text('退会申請を受付済み'), findsOneWidget);
    expect(find.byKey(const Key('account-deletion-cancel')), findsOneWidget);
  });

  testWidgets('cancels a pending deletion request', (tester) async {
    final gateway = _FakeAccountLifecycleGateway(initialRequest: _request());
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-deletion-cancel')));
    await tester.pumpAndSettle();

    expect(gateway.cancelCalls, 1);
    expect(find.text('退会申請を取り消しました。'), findsOneWidget);
    expect(find.text('退会を申請する'), findsOneWidget);
  });

  testWidgets('does not offer cancellation after worker processing starts', (
    tester,
  ) async {
    final gateway = _FakeAccountLifecycleGateway(
      initialRequest: _request(
        status: 'failed',
        attemptCount: 1,
        lastErrorCode: 'storage_deletion_failed',
      ),
    );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('状態: 安全確認・再試行待ち'), findsOneWidget);
    expect(find.byKey(const Key('account-deletion-cancel')), findsNothing);
  });

  testWidgets('shows token drain as an irreversible processing state', (
    tester,
  ) async {
    final gateway = _FakeAccountLifecycleGateway(
      initialRequest: _request(
        status: 'awaiting_token_expiry',
        attemptCount: 1,
      ),
    );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('状態: アクセストークン失効待ち'), findsOneWidget);
    expect(find.byKey(const Key('account-deletion-cancel')), findsNothing);
  });

  testWidgets('renders at a narrow web viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_FakeAccountLifecycleGateway()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('退会・アカウント削除'), findsOneWidget);
  });

  testWidgets('supports password reauthentication for email accounts', (
    tester,
  ) async {
    final gateway = _FakeAccountLifecycleGateway(
      fetchErrorCode: 'reauthentication_required',
    );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    expect(find.text('パスワードで本人確認'), findsOneWidget);
    expect(find.text('Googleで再ログイン'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('account-deletion-reauth-password')),
      'correct horse battery staple',
    );
    await tester.tap(
      find.byKey(const Key('account-deletion-reauth-password-submit')),
    );
    await tester.pumpAndSettle();

    expect(gateway.reauthenticatedPassword, 'correct horse battery staple');
    expect(find.textContaining('本人確認が完了しました'), findsOneWidget);
  });
}

Widget _app(AccountLifecycleGateway gateway) {
  return MaterialApp(
    routes: {
      '/billing': (_) => const Scaffold(body: Text('billing')),
      '/privacy': (_) => const Scaffold(body: Text('privacy')),
    },
    home: AccountDeletionPage(gateway: gateway),
  );
}

class _FakeAccountLifecycleGateway implements AccountLifecycleGateway {
  _FakeAccountLifecycleGateway({
    AccountDeletionRequest? initialRequest,
    this.fetchErrorCode,
  }) : _request = initialRequest;

  AccountDeletionRequest? _request;
  final String? fetchErrorCode;
  String? requestedConfirmation;
  String? reauthenticatedPassword;
  int cancelCalls = 0;

  static const policy = AccountDeletionPolicy(
    version: '2026-08-29.v1',
    graceDays: 30,
    subscriptionCancellationDeletesAccount: false,
    confirmation: 'アカウントを削除する',
  );

  @override
  Future<AccountLifecycleSnapshot> fetchStatus() async {
    if (fetchErrorCode case final code?) {
      throw AccountLifecycleException(code);
    }
    return AccountLifecycleSnapshot(policy: policy, request: _request);
  }

  @override
  Future<AccountLifecycleSnapshot> requestDeletion({
    required String confirmation,
  }) async {
    requestedConfirmation = confirmation;
    _request = _request ?? _requestFixture();
    return AccountLifecycleSnapshot(policy: policy, request: _request);
  }

  @override
  Future<AccountLifecycleSnapshot> cancelDeletion() async {
    cancelCalls += 1;
    _request = null;
    return const AccountLifecycleSnapshot(policy: policy);
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    reauthenticatedPassword = password;
  }

  @override
  Future<bool> reauthenticateWithGoogle() async => true;
}

AccountDeletionRequest _requestFixture() => _request();

AccountDeletionRequest _request({
  String status = 'pending',
  int attemptCount = 0,
  String? lastErrorCode,
}) {
  return AccountDeletionRequest(
    id: 2844,
    status: status,
    policyVersion: '2026-08-29.v1',
    requestedAt: DateTime.utc(2026, 8, 29),
    scheduledFor: DateTime.utc(2026, 9, 28),
    attemptCount: attemptCount,
    lastErrorCode: lastErrorCode,
  );
}
