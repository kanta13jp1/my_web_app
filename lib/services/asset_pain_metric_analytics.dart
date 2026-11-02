import 'package:flutter/foundation.dart';

/// 資産管理ペインメトリクス（日歩利息流血額・労働消失時間）の表示・行動アトリビューション計測 (Issue #5246)。
class AssetPainMetricAnalytics {
  final void Function(String eventName, Map<String, dynamic> properties)?
      _onTrack;

  const AssetPainMetricAnalytics({
    void Function(String eventName, Map<String, dynamic> properties)? onTrack,
  }) : _onTrack = onTrack;

  /// ペインメトリクスバナー表示イベントを記録 (金額はプライバシー保護のため丸め処理)。
  void trackPainMetricView({
    required double dailyBleed,
    required double lostLaborHours,
    required double stolenFuture,
  }) {
    final roundedBleed = (dailyBleed / 100).round() * 100;
    final bucketedHours = double.parse(lostLaborHours.toStringAsFixed(1));
    final roundedFuture = (stolenFuture / 1000).round() * 1000;

    _track('asset_pain_metric_view', <String, dynamic>{
      'daily_bleed_bucket': roundedBleed,
      'lost_labor_hours_bucket': bucketedHours,
      'stolen_future_bucket': roundedFuture,
      'has_bleed': dailyBleed > 0,
    });
  }

  /// 推奨アクション（返済・振替等）の開始イベントを記録。
  void trackActionStart({
    required String actionType,
    required String targetAccountId,
  }) {
    _track('asset_pain_action_start', <String, dynamic>{
      'action_type': actionType,
      'target_account_id': targetAccountId,
    });
  }

  /// 推奨アクション（返済・振替・解約等）の完了イベントを記録。
  void trackActionComplete({
    required String actionType,
    required String targetAccountId,
    double? reducedBleedAmount,
  }) {
    _track('asset_pain_action_complete', <String, dynamic>{
      'action_type': actionType,
      'target_account_id': targetAccountId,
      'reduced_bleed_bucket': reducedBleedAmount == null
          ? null
          : (reducedBleedAmount / 100).round() * 100,
    });
  }

  void _track(String eventName, Map<String, dynamic> properties) {
    if (_onTrack != null) {
      _onTrack(eventName, properties);
      return;
    }
    if (kDebugMode) {
      debugPrint('[PainAnalytics] $eventName: $properties');
    }
  }
}
