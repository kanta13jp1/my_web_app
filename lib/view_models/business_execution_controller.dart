import 'package:flutter/foundation.dart';

import '../models/business_execution.dart';
import '../services/business_execution_store.dart';

class BusinessExecutionController extends ChangeNotifier {
  BusinessExecutionController({
    required this.userId,
    required this.currentUserId,
    required this.store,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final String userId;
  final String? Function() currentUserId;
  final BusinessExecutionStore store;
  final DateTime Function() now;
  List<BusinessExecutionPlan> _plans = const [];
  List<BusinessExecutionPlan> get plans => _plans;
  bool loading = true;
  bool saving = false;
  bool refreshing = false;
  bool ready = false;
  String? error;
  String? _raw;
  bool _disposed = false;

  bool get _sameAccount =>
      !_disposed && userId.isNotEmpty && currentUserId() == userId;

  Future<void> load() async {
    if (!_sameAccount || saving || refreshing) return;
    refreshing = true;
    loading = !ready;
    error = null;
    notifyListeners();
    try {
      final raw = await store.read(userId);
      final plans = BusinessExecutionCodec.decode(raw);
      if (!_sameAccount) return;
      _raw = raw;
      _plans = plans;
      ready = true;
    } catch (_) {
      if (!_sameAccount) return;
      error = '記録を読み込めませんでした。保存済みデータは上書きしません。'
          'このブラウザーの保存設定を確認して再読み込みしてください。';
    } finally {
      if (_sameAccount) {
        loading = false;
        refreshing = false;
        notifyListeners();
      }
    }
  }

  Future<bool> add(BusinessExecutionPlan plan) async {
    return _save([..._plans, plan]);
  }

  Future<bool> report(
    String id,
    String day,
    BusinessDailyReport report,
  ) async {
    try {
      if (parseDay(day).isAfter(parseDay(dayKey(now())))) {
        throw const FormatException('未来日の実績は記録できません。');
      }
      if (_plans.any((plan) => plan.id == id && plan.archived)) return false;
      return _save(
        _replace(id, (plan) => plan.withReport(day, report)),
      );
    } on FormatException catch (exception) {
      _showError(exception.message);
      return false;
    }
  }

  Future<bool> reflect(String id, String reflection) async {
    try {
      if (_plans.any((plan) => plan.id == id && plan.archived)) return false;
      return _save(
        _replace(id, (plan) => plan.withReflection(reflection)),
      );
    } on FormatException catch (exception) {
      _showError(exception.message);
      return false;
    }
  }

  Future<bool> setArchived(String id, bool archived) async {
    try {
      return _save(_replace(id, (plan) => plan.withArchived(archived)));
    } on FormatException catch (exception) {
      _showError(exception.message);
      return false;
    }
  }

  List<BusinessExecutionPlan> _replace(
    String id,
    BusinessExecutionPlan Function(BusinessExecutionPlan) update,
  ) {
    if (!_plans.any((plan) => plan.id == id)) {
      throw const FormatException('計画が見つかりません。再読み込みしてください。');
    }
    return _plans.map((plan) => plan.id == id ? update(plan) : plan).toList();
  }

  Future<bool> _save(List<BusinessExecutionPlan> plans) async {
    if (!_sameAccount || !ready || saving || refreshing) return false;
    saving = true;
    error = null;
    notifyListeners();
    try {
      final raw = BusinessExecutionCodec.encode(plans);
      if (!_sameAccount) return false;
      await store.write(userId, _raw, raw, isCurrent: () => _sameAccount);
      if (!_sameAccount) return false;
      final verified = await store.read(userId);
      if (!_sameAccount) return false;
      if (verified != raw) {
        throw StateError('保存後の読み戻しが一致しません。');
      }
      _raw = raw;
      _plans = BusinessExecutionCodec.decode(verified);
      return true;
    } on FormatException catch (exception) {
      _showError(exception.message);
      return false;
    } on UnsupportedError {
      _showError(
          'この環境では安全に保存できません。Web Locksに対応したHTTPSブラウザーを利用してください。入力は残しています。');
      return false;
    } catch (_) {
      _showError(
        '保存を確認できませんでした。入力は残しています。'
        '別タブでの変更や保存容量を確認し、再読み込みで保存結果を確認してください。',
      );
      return false;
    } finally {
      if (_sameAccount) {
        saving = false;
        notifyListeners();
      }
    }
  }

  void _showError(String message) {
    if (_sameAccount) {
      error = message;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
