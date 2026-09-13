import 'package:flutter/foundation.dart';

/// 競合比較一覧 (CompetitorBrowsePage) における検索・絞り込み・カード遷移のプライバシー保護計測 (Issue #5158)。
class CompetitorBrowseAnalytics {
  final void Function(String eventName, Map<String, dynamic> properties)?
      _onTrack;

  const CompetitorBrowseAnalytics({
    void Function(String eventName, Map<String, dynamic> properties)? onTrack,
  }) : _onTrack = onTrack;

  /// 競合一覧画面の表示を記録。
  void trackBrowseView({
    required int totalCompetitorsCount,
    String? initialCategory,
  }) {
    _track('competitor_browse_view', <String, dynamic>{
      'total_competitors_count': totalCompetitorsCount,
      if (initialCategory != null) 'category': initialCategory,
    });
  }

  /// 検索実行イベントを記録 (検索文字列の長さバケットと結果件数を保存)。
  void trackSearchUsed({
    required String query,
    required int resultsCount,
  }) {
    _track('competitor_search_used', <String, dynamic>{
      'query_length_bucket': (query.trim().length / 5).ceil() * 5,
      'results_count': resultsCount,
      'is_zero_result': resultsCount == 0,
    });
  }

  /// フィルター変更イベントを記録 (カテゴリ・価格帯・国内展開等)。
  void trackFilterChanged({
    required String filterType,
    required String filterValue,
    required int filteredResultsCount,
  }) {
    _track('competitor_filter_changed', <String, dynamic>{
      'filter_type': filterType,
      'filter_value': filterValue,
      'filtered_results_count': filteredResultsCount,
    });
  }

  /// 競合詳細・比較カード (/vs-*) への遷移を記録。
  void trackCompetitorCardClicked({
    required String competitorKey,
    required String destinationRoute,
  }) {
    _track('competitor_card_clicked', <String, dynamic>{
      'competitor_key': competitorKey,
      'destination_route': destinationRoute,
    });
  }

  void _track(String eventName, Map<String, dynamic> properties) {
    if (_onTrack != null) {
      _onTrack(eventName, properties);
      return;
    }
    if (kDebugMode) {
      debugPrint('[CompetitorAnalytics] $eventName: $properties');
    }
  }
}
