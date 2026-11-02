import 'package:flutter/foundation.dart';

/// Home 画面における主要導線・追加要望フローのプライバシー保護ファネル計測 (Issue #5166)。
class HomeFunnelAnalytics {
  final void Function(String eventName, Map<String, dynamic> properties)?
      _onTrack;

  const HomeFunnelAnalytics({
    void Function(String eventName, Map<String, dynamic> properties)? onTrack,
  }) : _onTrack = onTrack;

  /// ホームセクション（今日の1件、AI大学、資産管理、メモ等）の表示を記録。
  void trackSectionView({
    required String sectionId,
    bool isExpanded = true,
  }) {
    _track('home_section_view', <String, dynamic>{
      'section_id': sectionId,
      'is_expanded': isExpanded,
    });
  }

  /// ヒーロー導線（ボタン・カードクリック）のアクションを記録。
  void trackHeroActionClicked({
    required String actionId,
    String? destinationRoute,
  }) {
    _track('home_hero_action_clicked', <String, dynamic>{
      'action_id': actionId,
      if (destinationRoute != null) 'destination_route': destinationRoute,
    });
  }

  /// 追加要望・フィードバック導線の開始を記録。
  void trackFeatureRequestStart({
    String? sourceSection,
  }) {
    _track('home_feature_request_start', <String, dynamic>{
      if (sourceSection != null) 'source_section': sourceSection,
    });
  }

  /// 追加要望・フィードバックの送信完了を記録。
  void trackFeatureRequestComplete({
    required bool hasAttachment,
    int? textLengthBucket,
  }) {
    _track('home_feature_request_complete', <String, dynamic>{
      'has_attachment': hasAttachment,
      if (textLengthBucket != null) 'text_length_bucket': textLengthBucket,
    });
  }

  void _track(String eventName, Map<String, dynamic> properties) {
    if (_onTrack != null) {
      _onTrack(eventName, properties);
      return;
    }
    if (kDebugMode) {
      debugPrint('[HomeFunnelAnalytics] $eventName: $properties');
    }
  }
}
