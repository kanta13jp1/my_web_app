import 'package:flutter/foundation.dart';

import '../models/account_deletion_request.dart';
import '../services/account_lifecycle_service.dart';

class AccountDeletionViewModel extends ChangeNotifier {
  AccountDeletionViewModel({required AccountLifecycleGateway gateway})
      : _gateway = gateway;

  final AccountLifecycleGateway _gateway;

  AccountLifecycleSnapshot? _snapshot;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorCode;
  String? _notice;

  AccountLifecycleSnapshot? get snapshot => _snapshot;
  AccountDeletionRequest? get request => _snapshot?.request;
  AccountDeletionPolicy? get policy => _snapshot?.policy;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorCode => _errorCode;
  String? get notice => _notice;

  Future<void> load() async {
    _isLoading = true;
    _errorCode = null;
    notifyListeners();
    try {
      _snapshot = await _gateway.fetchStatus();
    } on AccountLifecycleException catch (error) {
      _errorCode = error.code;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestDeletion(String confirmation) async {
    await _submit(
      () => _gateway.requestDeletion(confirmation: confirmation),
      notice: '退会申請を受け付けました。期限までは取り消せます。',
    );
  }

  Future<void> cancelDeletion() async {
    await _submit(_gateway.cancelDeletion, notice: '退会申請を取り消しました。');
  }

  Future<void> reauthenticate() async {
    _errorCode = null;
    _notice = null;
    notifyListeners();
    final launched = await _gateway.reauthenticate();
    if (!launched) {
      _errorCode = 'reauthentication_launch_failed';
      notifyListeners();
    }
  }

  Future<void> _submit(
    Future<AccountLifecycleSnapshot> Function() action, {
    required String notice,
  }) async {
    _isSubmitting = true;
    _errorCode = null;
    _notice = null;
    notifyListeners();
    try {
      _snapshot = await action();
      _notice = notice;
    } on AccountLifecycleException catch (error) {
      _errorCode = error.code;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
