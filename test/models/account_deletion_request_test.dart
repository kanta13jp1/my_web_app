import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/account_deletion_request.dart';

void main() {
  test('parses lifecycle policy and pending request', () {
    final snapshot = AccountLifecycleSnapshot.fromJson({
      'policy': {
        'version': '2026-08-29.v1',
        'grace_days': 30,
        'subscription_cancellation_deletes_account': false,
        'confirmation': 'アカウントを削除する',
      },
      'request': {
        'id': 2844,
        'status': 'pending',
        'policy_version': '2026-08-29.v1',
        'requested_at': '2026-08-29T00:00:00Z',
        'scheduled_for': '2026-09-28T00:00:00Z',
        'attempt_count': 0,
      },
    });

    expect(snapshot.policy.graceDays, 30);
    expect(snapshot.policy.subscriptionCancellationDeletesAccount, isFalse);
    expect(snapshot.request?.id, 2844);
    expect(snapshot.request?.canCancel, isTrue);
    expect(snapshot.request?.scheduledFor, DateTime.utc(2026, 9, 28));
  });

  test('cannot cancel after worker processing has started', () {
    final failed = AccountDeletionRequest.fromJson({
      'id': 2845,
      'status': 'failed',
      'policy_version': '2026-08-29.v1',
      'requested_at': '2026-08-29T00:00:00Z',
      'scheduled_for': '2026-09-28T00:00:00Z',
      'attempt_count': 1,
      'last_error_code': 'storage_deletion_failed',
    });
    final draining = AccountDeletionRequest.fromJson({
      'id': 2846,
      'status': 'awaiting_token_expiry',
      'policy_version': '2026-08-29.v1',
      'requested_at': '2026-08-29T00:00:00Z',
      'scheduled_for': '2026-09-28T00:00:00Z',
      'attempt_count': 1,
    });

    expect(failed.canCancel, isFalse);
    expect(draining.canCancel, isFalse);
    expect(draining.isProcessing, isTrue);
  });
}
