import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/asset_anomaly_detection.dart';

abstract class AssetAnomalyDetectionRepository {
  const AssetAnomalyDetectionRepository();

  Future<List<AssetAnomalyDetection>> fetchActive({
    required String userId,
    int limit = 50,
  });

  Future<void> dismiss({
    required String userId,
    required String detectionId,
    required DateTime dismissedAt,
  });
}

class AssetAnomalyDetectionRepositoryException implements Exception {
  const AssetAnomalyDetectionRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseAssetAnomalyDetectionRepository
    implements AssetAnomalyDetectionRepository {
  SupabaseAssetAnomalyDetectionRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String tableName = 'anomaly_detections';
  static const String selectColumns =
      'id,target_month,category,expected,actual,delta,severity,'
      'ai_explanation,detected_at';

  final SupabaseClient _client;

  @override
  Future<List<AssetAnomalyDetection>> fetchActive({
    required String userId,
    int limit = 50,
  }) async {
    final normalizedUserId = _requiredId(userId, 'userId');
    final safeLimit = limit.clamp(1, 100);
    try {
      final rows = await _client
          .from(tableName)
          .select(selectColumns)
          .eq('user_id', normalizedUserId)
          .isFilter('dismissed_at', null)
          .order('detected_at', ascending: false)
          .order('id', ascending: true)
          .range(0, safeLimit - 1);
      return List<AssetAnomalyDetection>.unmodifiable(
        rows.whereType<Map>().map(
              (row) => AssetAnomalyDetection.fromMap(
                row.cast<String, dynamic>(),
              ),
            ),
      );
    } on PostgrestException catch (error) {
      throw AssetAnomalyDetectionRepositoryException(error.message);
    }
  }

  @override
  Future<void> dismiss({
    required String userId,
    required String detectionId,
    required DateTime dismissedAt,
  }) async {
    final normalizedUserId = _requiredId(userId, 'userId');
    final normalizedDetectionId = _requiredId(detectionId, 'detectionId');
    try {
      final rows = await _client
          .from(tableName)
          .update({'dismissed_at': dismissedAt.toUtc().toIso8601String()})
          .eq('id', normalizedDetectionId)
          .eq('user_id', normalizedUserId)
          .isFilter('dismissed_at', null)
          .select('id');
      if (rows.isEmpty) {
        throw const AssetAnomalyDetectionRepositoryException(
          'Anomaly detection not found or already dismissed',
        );
      }
    } on PostgrestException catch (error) {
      throw AssetAnomalyDetectionRepositoryException(error.message);
    }
  }
}

String _requiredId(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}
