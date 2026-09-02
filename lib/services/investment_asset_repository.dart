import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/investment_asset.dart';
import '../models/investment_portfolio_history.dart';

abstract class InvestmentAssetRepository {
  const InvestmentAssetRepository();

  Future<List<InvestmentAsset>> fetchByUser({required String userId});

  Future<List<InvestmentPortfolioHistoryPoint>> fetchPortfolioHistory({
    required String userId,
  });

  Future<InvestmentAsset> create({
    required String userId,
    required InvestmentAssetDraft draft,
  });

  Future<InvestmentAsset> update({
    required String userId,
    required String assetId,
    required InvestmentAssetDraft draft,
  });

  Future<void> delete({required String userId, required String assetId});
}

class SupabaseInvestmentAssetRepository implements InvestmentAssetRepository {
  SupabaseInvestmentAssetRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String tableName = 'investment_assets';
  static const String historyTableName = 'investment_portfolio_history';
  static const int _assetPageSize = 1000;
  static const int _historyPageSize = 1000;
  static const String selectColumns =
      'id,user_id,asset_type,ticker,quantity,buy_price_jpy,buy_date,'
      'current_price_jpy,last_priced_at,created_at,updated_at';

  final SupabaseClient _client;

  @override
  Future<List<InvestmentAsset>> fetchByUser({required String userId}) async {
    final normalizedUserId = _requiredId(userId, 'userId');
    final assets = <InvestmentAsset>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from(tableName)
          .select(selectColumns)
          .eq('user_id', normalizedUserId)
          .order('asset_type', ascending: true)
          .order('ticker', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + _assetPageSize - 1);
      final page = rows as List;
      assets.addAll(
        page.whereType<Map>().map(
              (row) => InvestmentAsset.fromMap(row.cast<String, dynamic>()),
            ),
      );
      if (page.length < _assetPageSize) break;
      offset += page.length;
    }

    return List<InvestmentAsset>.unmodifiable(assets);
  }

  @override
  Future<List<InvestmentPortfolioHistoryPoint>> fetchPortfolioHistory({
    required String userId,
  }) async {
    final normalizedUserId = _requiredId(userId, 'userId');
    final points = <InvestmentPortfolioHistoryPoint>[];
    var offset = 0;
    while (true) {
      final rows = await _client
          .from(historyTableName)
          .select(
            'id,recorded_on,recorded_at,market_value_jpy,acquisition_cost_jpy,'
            'priced_asset_count,unpriced_asset_count',
          )
          .eq('user_id', normalizedUserId)
          .order('recorded_on', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + _historyPageSize - 1);
      final page = rows as List;
      points.addAll(
        page.whereType<Map>().map(
              (row) => InvestmentPortfolioHistoryPoint.fromMap(
                row.cast<String, dynamic>(),
              ),
            ),
      );
      if (page.length < _historyPageSize) break;
      offset += page.length;
    }

    points.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return List<InvestmentPortfolioHistoryPoint>.unmodifiable(points);
  }

  @override
  Future<InvestmentAsset> create({
    required String userId,
    required InvestmentAssetDraft draft,
  }) async {
    final row = await _client
        .from(tableName)
        .insert(draft.toInsertMap(userId: userId))
        .select(selectColumns)
        .single();
    return InvestmentAsset.fromMap(row);
  }

  @override
  Future<InvestmentAsset> update({
    required String userId,
    required String assetId,
    required InvestmentAssetDraft draft,
  }) async {
    final normalizedUserId = _requiredId(userId, 'userId');
    final normalizedAssetId = _requiredId(assetId, 'assetId');
    final row = await _client
        .from(tableName)
        .update(draft.toUpdateMap())
        .eq('id', normalizedAssetId)
        .eq('user_id', normalizedUserId)
        .select(selectColumns)
        .maybeSingle();
    if (row == null) {
      throw StateError('Investment asset not found');
    }
    return InvestmentAsset.fromMap(row);
  }

  @override
  Future<void> delete({required String userId, required String assetId}) async {
    final normalizedUserId = _requiredId(userId, 'userId');
    final normalizedAssetId = _requiredId(assetId, 'assetId');
    await _client
        .from(tableName)
        .delete()
        .eq('id', normalizedAssetId)
        .eq('user_id', normalizedUserId);
  }
}

String _requiredId(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}
