import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/alt_supply_models.dart';

/// Supabase `app-hub` repository for alternative supply & import risk (#2756).
class SupabaseAltSupplyRepository implements AltSupplyRepository {
  SupabaseAltSupplyRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  String _requireUserId(final SupabaseClient client) {
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw StateError('代替供給・輸入シナリオ監視を利用するにはログインが必要です。');
    }
    return userId;
  }

  Map<String, Object?> _decodeMap(final Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is Map<Object?, Object?>) {
      return decoded.map<String, Object?>(
        (final Object? k, final Object? v) => MapEntry(k.toString(), v),
      );
    }
    return const <String, Object?>{};
  }

  double _toDouble(final Object? raw, final double fallback) {
    if (raw is num && raw.isFinite) return raw.toDouble();
    final parsed = double.tryParse((raw ?? '').toString());
    return parsed != null && parsed.isFinite ? parsed : fallback;
  }

  AltSupplyScenario _mapScenario(final Map<String, Object?> row) {
    final target = _toDouble(
      row['stockpile_target_10k_t'],
      kDefaultStockpileTarget10kT,
    );
    final procurement = _toDouble(row['domestic_procurement_10k_t'], 0);
    final threshold = _toDouble(
      row['stockpile_threshold_10k_t'],
      kDefaultProcurementThreshold10kT,
    );
    final totalTarget = _toDouble(
      row['total_production_target_10k_t'],
      kDefaultTotalProductionTarget10kT,
    );
    final currentProd = _toDouble(row['current_production_10k_t'], totalTarget);
    final maQuota = _toDouble(
      row['ma_import_quota_10k_t'],
      kDefaultMaImportQuota10kT,
    );

    final metrics = AltSupplyMetrics.evaluate(
      stockpileTarget10kT: target,
      domesticProcurement10kT: procurement,
      stockpileThreshold10kT: threshold,
      totalProductionTarget10kT: totalTarget,
      currentProduction10kT: currentProd,
      maImportQuota10kT: maQuota,
    );

    return AltSupplyScenario(
      id: (row['id'] ?? '').toString(),
      title: (row['title'] ?? '需給・輸入リスクシナリオ').toString(),
      sourceKind: AltSupplySourceKind.fromWire(row['source_kind']?.toString()),
      sourceRef: (row['source_ref'] ?? '').toString(),
      stockpileTarget10kT: target,
      domesticProcurement10kT: procurement,
      stockpileThreshold10kT: threshold,
      totalProductionTarget10kT: totalTarget,
      currentProduction10kT: currentProd,
      maImportQuota10kT: maQuota,
      metrics: metrics,
      notes: (row['notes'] ?? '').toString(),
      updatedAt: DateTime.tryParse((row['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  List<AltSupplyScenario> _mapScenarioList(final Object? rawList) {
    if (rawList is! List<Object?>) {
      return const <AltSupplyScenario>[];
    }
    return rawList
        .whereType<Map<Object?, Object?>>()
        .map(
          (final Map<Object?, Object?> item) => _mapScenario(
            item.map<String, Object?>(
              (final Object? k, final Object? v) => MapEntry(k.toString(), v),
            ),
          ),
        )
        .toList(growable: false);
  }

  String _formatFunctionError(final FunctionException error) {
    if (error.status == 401) {
      return '認証の有効期限が切れています。再ログイン後に再試行してください。';
    }
    final details = error.details;
    if (details is Map<Object?, Object?> && details['error'] != null) {
      return details['error'].toString();
    }
    if (details != null && details.toString().trim().isNotEmpty) {
      return details.toString();
    }
    return error.reasonPhrase ?? '代替供給監視 API でエラーが発生しました (${error.status})';
  }

  @override
  Future<List<AltSupplyScenario>> listScenarios() async {
    final client = _resolvedClient;
    _requireUserId(client);
    try {
      final response = await client.functions.invoke(
        'app-hub',
        body: const <String, Object?>{'action': 'alt_supply.list'},
      );
      if (response.status >= 400) {
        throw StateError('シナリオ一覧の取得に失敗しました (${response.status})');
      }
      final data = _decodeMap(response.data);
      return _mapScenarioList(data['scenarios']);
    } on FunctionException catch (error) {
      throw StateError(_formatFunctionError(error));
    }
  }

  @override
  Future<List<AltSupplyScenario>> seedDefaults() async {
    final client = _resolvedClient;
    _requireUserId(client);
    try {
      final response = await client.functions.invoke(
        'app-hub',
        body: const <String, Object?>{'action': 'alt_supply.seed_defaults'},
      );
      if (response.status >= 400) {
        throw StateError('初期シナリオ投入に失敗しました (${response.status})');
      }
      final data = _decodeMap(response.data);
      return _mapScenarioList(data['scenarios']);
    } on FunctionException catch (error) {
      throw StateError(_formatFunctionError(error));
    }
  }

  @override
  Future<AltSupplyScenario> createScenario({
    required final String title,
    required final double stockpileTarget10kT,
    required final double domesticProcurement10kT,
    required final double stockpileThreshold10kT,
    required final double totalProductionTarget10kT,
    required final double currentProduction10kT,
    required final double maImportQuota10kT,
    final AltSupplySourceKind sourceKind = AltSupplySourceKind.manual,
    final String sourceRef = '',
    final String notes = '',
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    try {
      final response = await client.functions.invoke(
        'app-hub',
        body: <String, Object?>{
          'action': 'alt_supply.create',
          'title': title.trim(),
          'source_kind': sourceKind.wireValue,
          'source_ref': sourceRef.trim(),
          'stockpile_target_10k_t': stockpileTarget10kT,
          'domestic_procurement_10k_t': domesticProcurement10kT,
          'stockpile_threshold_10k_t': stockpileThreshold10kT,
          'total_production_target_10k_t': totalProductionTarget10kT,
          'current_production_10k_t': currentProduction10kT,
          'ma_import_quota_10k_t': maImportQuota10kT,
          'notes': notes.trim(),
        },
      );
      if (response.status >= 400) {
        throw StateError('シナリオの作成に失敗しました (${response.status})');
      }
      final data = _decodeMap(response.data);
      final rawScenario = data['scenario'];
      if (rawScenario is Map<Object?, Object?>) {
        return _mapScenario(
          rawScenario.map<String, Object?>(
            (final Object? k, final Object? v) => MapEntry(k.toString(), v),
          ),
        );
      }
      throw StateError('シナリオ作成レスポンスが不正です。');
    } on FunctionException catch (error) {
      throw StateError(_formatFunctionError(error));
    }
  }

  @override
  Future<AltSupplyScenario> updateScenario({
    required final String id,
    required final String title,
    required final double stockpileTarget10kT,
    required final double domesticProcurement10kT,
    required final double stockpileThreshold10kT,
    required final double totalProductionTarget10kT,
    required final double currentProduction10kT,
    required final double maImportQuota10kT,
    final AltSupplySourceKind sourceKind = AltSupplySourceKind.manual,
    final String sourceRef = '',
    final String notes = '',
  }) async {
    final client = _resolvedClient;
    _requireUserId(client);
    try {
      final response = await client.functions.invoke(
        'app-hub',
        body: <String, Object?>{
          'action': 'alt_supply.update',
          'id': id.trim(),
          'title': title.trim(),
          'source_kind': sourceKind.wireValue,
          'source_ref': sourceRef.trim(),
          'stockpile_target_10k_t': stockpileTarget10kT,
          'domestic_procurement_10k_t': domesticProcurement10kT,
          'stockpile_threshold_10k_t': stockpileThreshold10kT,
          'total_production_target_10k_t': totalProductionTarget10kT,
          'current_production_10k_t': currentProduction10kT,
          'ma_import_quota_10k_t': maImportQuota10kT,
          'notes': notes.trim(),
        },
      );
      if (response.status >= 400) {
        throw StateError('シナリオの更新に失敗しました (${response.status})');
      }
      final data = _decodeMap(response.data);
      final rawScenario = data['scenario'];
      if (rawScenario is Map<Object?, Object?>) {
        return _mapScenario(
          rawScenario.map<String, Object?>(
            (final Object? k, final Object? v) => MapEntry(k.toString(), v),
          ),
        );
      }
      throw StateError('シナリオ更新レスポンスが不正です。');
    } on FunctionException catch (error) {
      throw StateError(_formatFunctionError(error));
    }
  }
}
