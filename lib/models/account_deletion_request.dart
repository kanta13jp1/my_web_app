class AccountDeletionPolicy {
  const AccountDeletionPolicy({
    required this.version,
    required this.graceDays,
    required this.subscriptionCancellationDeletesAccount,
    required this.confirmation,
  });

  final String version;
  final int graceDays;
  final bool subscriptionCancellationDeletesAccount;
  final String confirmation;

  factory AccountDeletionPolicy.fromJson(Map<String, dynamic> json) {
    return AccountDeletionPolicy(
      version: json['version']?.toString() ?? '',
      graceDays: _asInt(json['grace_days'], fallback: 30),
      subscriptionCancellationDeletesAccount:
          json['subscription_cancellation_deletes_account'] == true,
      confirmation: json['confirmation']?.toString() ?? 'アカウントを削除する',
    );
  }
}

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.policyVersion,
    required this.requestedAt,
    required this.scheduledFor,
    this.cancelledAt,
    this.completedAt,
    this.attemptCount = 0,
    this.lastErrorCode,
  });

  final int id;
  final String status;
  final String policyVersion;
  final DateTime requestedAt;
  final DateTime scheduledFor;
  final DateTime? cancelledAt;
  final DateTime? completedAt;
  final int attemptCount;
  final String? lastErrorCode;

  bool get canCancel => status == 'pending' && attemptCount == 0;
  bool get isProcessing =>
      status == 'processing' || status == 'awaiting_token_expiry';

  factory AccountDeletionRequest.fromJson(Map<String, dynamic> json) {
    return AccountDeletionRequest(
      id: _asInt(json['id']),
      status: json['status']?.toString() ?? 'pending',
      policyVersion: json['policy_version']?.toString() ?? '',
      requestedAt: _asDate(json['requested_at']),
      scheduledFor: _asDate(json['scheduled_for']),
      cancelledAt: _asNullableDate(json['cancelled_at']),
      completedAt: _asNullableDate(json['completed_at']),
      attemptCount: _asInt(json['attempt_count']),
      lastErrorCode: json['last_error_code']?.toString(),
    );
  }
}

class AccountLifecycleSnapshot {
  const AccountLifecycleSnapshot({required this.policy, this.request});

  final AccountDeletionPolicy policy;
  final AccountDeletionRequest? request;

  factory AccountLifecycleSnapshot.fromJson(Map<String, dynamic> json) {
    return AccountLifecycleSnapshot(
      policy: AccountDeletionPolicy.fromJson(_asMap(json['policy'])),
      request: json['request'] == null
          ? null
          : AccountDeletionRequest.fromJson(_asMap(json['request'])),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime _asDate(Object? value) {
  return _asNullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? _asNullableDate(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : DateTime.tryParse(text);
}
