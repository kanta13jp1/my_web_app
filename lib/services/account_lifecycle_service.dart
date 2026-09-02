import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_deletion_request.dart';
import 'supabase_client_provider.dart';

class AccountLifecycleException implements Exception {
  const AccountLifecycleException(this.code, {this.statusCode});

  final String code;
  final int? statusCode;

  @override
  String toString() => code;
}

abstract class AccountLifecycleGateway {
  Future<AccountLifecycleSnapshot> fetchStatus();

  Future<AccountLifecycleSnapshot> requestDeletion({
    required String confirmation,
  });

  Future<AccountLifecycleSnapshot> cancelDeletion();

  Future<void> reauthenticateWithPassword(String password);

  Future<bool> reauthenticateWithGoogle();
}

class AccountLifecycleService implements AccountLifecycleGateway {
  AccountLifecycleService({SupabaseClient? client})
      : _client = client ?? supabase;

  final SupabaseClient _client;

  @override
  Future<AccountLifecycleSnapshot> fetchStatus() async {
    return _invoke('status');
  }

  @override
  Future<AccountLifecycleSnapshot> requestDeletion({
    required String confirmation,
  }) async {
    return _invoke('request_deletion', {'confirmation': confirmation});
  }

  @override
  Future<AccountLifecycleSnapshot> cancelDeletion() async {
    return _invoke('cancel_deletion');
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final email = _client.auth.currentUser?.email?.trim() ?? '';
    if (email.isEmpty) {
      throw const AccountLifecycleException(
        'reauthentication_email_unavailable',
      );
    }

    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException {
      throw const AccountLifecycleException('reauthentication_failed');
    }
  }

  @override
  Future<bool> reauthenticateWithGoogle() {
    final redirect = Uri.base.resolve('/account-deletion').toString();
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirect,
    );
  }

  Future<AccountLifecycleSnapshot> _invoke(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    final response = await _client.functions.invoke(
      'account-lifecycle',
      body: {'action': action, ...body},
    );
    final data = _asMap(response.data);
    if (response.status < 200 ||
        response.status >= 300 ||
        data['success'] == false ||
        data['error'] != null) {
      throw AccountLifecycleException(
        data['error']?.toString() ?? 'account_lifecycle_unavailable',
        statusCode: response.status,
      );
    }
    return AccountLifecycleSnapshot.fromJson(data);
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}
