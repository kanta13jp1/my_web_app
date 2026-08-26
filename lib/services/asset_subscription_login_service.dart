import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AssetSubscriptionLoginService {
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });
}

class AssetSubscriptionLoginException implements Exception {
  const AssetSubscriptionLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// サブスク明細画面内の再認証だけを担う小さなサービス。
///
/// 入力されたパスワードは Supabase Auth へ渡すだけで、
/// アプリ独自のローカルストレージやDBには保存しない。
/// 認証後のセッション管理は Supabase SDK に委ねる。
class SupabaseAssetSubscriptionLoginService
    implements AssetSubscriptionLoginService {
  const SupabaseAssetSubscriptionLoginService({SupabaseClient? supabase})
      : _supabase = supabase;

  final SupabaseClient? _supabase;

  SupabaseClient get _client => _supabase ?? Supabase.instance.client;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        throw const AssetSubscriptionLoginException(
          'ログイン状態を確認できませんでした。もう一度お試しください。',
        );
      }
    } on AssetSubscriptionLoginException {
      rethrow;
    } on AuthException catch (error) {
      throw AssetSubscriptionLoginException(_messageForAuthError(error));
    } catch (_) {
      throw const AssetSubscriptionLoginException(
        'ログインできませんでした。通信状況を確認してください。',
      );
    }
  }

  String _messageForAuthError(AuthException error) {
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    final status = error.statusCode?.toString() ?? '';
    if (code == 'invalid_credentials' ||
        code == 'invalid_grant' ||
        message.contains('invalid login credentials')) {
      return 'メールアドレスかパスワードが一致していません。';
    }
    if (code == 'email_not_confirmed') {
      return 'メールアドレスの確認が完了していません。';
    }
    if (code == 'over_request_rate_limit' ||
        status == '429' ||
        message.contains('rate limit')) {
      return 'ログインの試行回数が多すぎます。少し待ってからお試しください。';
    }
    return 'ログインできませんでした。入力内容を確認してください。';
  }
}
