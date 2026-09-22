import 'package:flutter/foundation.dart';

/// ユーザーマニュアル (UserManualPage) における閲覧・セクション遷移・主要タスク導線クリックのプライバシー保護計測 (Issue #5110)。
class UserManualAnalytics {
  final void Function(String eventName, Map<String, dynamic> properties)?
      _onTrack;

  const UserManualAnalytics({
    void Function(String eventName, Map<String, dynamic> properties)? onTrack,
  }) : _onTrack = onTrack;

  /// マニュアル全体の表示を記録。
  void trackManualView({
    String? initialSection,
    String? referralSource,
  }) {
    _track('user_manual_view', <String, dynamic>{
      if (initialSection != null) 'initial_section': initialSection,
      if (referralSource != null) 'referral_source': referralSource,
    });
  }

  /// 目次 (TOC) または特定セクションへのジャンプを記録。
  void trackSectionNavigated({
    required String sectionId,
    required String sectionTitle,
  }) {
    _track('user_manual_section_navigated', <String, dynamic>{
      'section_id': sectionId,
      'section_title': sectionTitle,
    });
  }

  /// マニュアル内の機能直接起動ボタン (Task Start) を記録。
  void trackActionLaunched({
    required String sectionId,
    required String targetRoute,
  }) {
    _track('user_manual_action_launched', <String, dynamic>{
      'section_id': sectionId,
      'target_route': targetRoute,
    });
  }

  void _track(String eventName, Map<String, dynamic> properties) {
    if (_onTrack != null) {
      _onTrack(eventName, properties);
      return;
    }
    if (kDebugMode) {
      debugPrint('[ManualAnalytics] $eventName: $properties');
    }
  }
}
