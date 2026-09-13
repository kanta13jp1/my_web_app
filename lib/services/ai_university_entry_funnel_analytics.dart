import 'package:flutter/foundation.dart';

/// AI大学 エントリ導線〜初回学習〜修了〜継続学習のプライバシー保護ファネル計測 (Issue #5146)。
class AiUniversityEntryFunnelAnalytics {
  final void Function(String eventName, Map<String, dynamic> properties)?
      _onTrack;

  const AiUniversityEntryFunnelAnalytics({
    void Function(String eventName, Map<String, dynamic> properties)? onTrack,
  }) : _onTrack = onTrack;

  static const Set<String> allowedDiscoveryPaths = <String>{
    'recommended_starter',
    'genre_shelf',
    'provider_tab',
    'search',
    'video_lesson',
    'api_lab',
  };

  /// 発見導線（おすすめスターター・ジャンル棚・プロバイダー・検索等）の選択を記録。
  void trackDiscoveryPathSelected({
    required String pathType,
    String? targetProvider,
  }) {
    final normalizedPath =
        allowedDiscoveryPaths.contains(pathType) ? pathType : 'other';
    _track('ai_university_discovery_selected', <String, dynamic>{
      'path_type': normalizedPath,
      if (targetProvider != null) 'target_provider': targetProvider,
    });
  }

  /// 初回・個別レッスンの受講開始を記録。
  void trackLessonStarted({
    required String provider,
    required String category,
    bool isFirstTime = false,
  }) {
    _track('ai_university_lesson_started', <String, dynamic>{
      'provider': provider,
      'category': category,
      'is_first_time': isFirstTime,
    });
  }

  /// レッスン修了イベントを記録。
  void trackLessonCompleted({
    required String provider,
    required String category,
    int? durationSeconds,
  }) {
    final bucketedDuration =
        durationSeconds == null ? null : (durationSeconds / 60).round() * 60;

    _track('ai_university_lesson_completed', <String, dynamic>{
      'provider': provider,
      'category': category,
      if (bucketedDuration != null) 'duration_bucket_seconds': bucketedDuration,
    });
  }

  /// 7日継続学習などのリピート学習実績を記録。
  void trackRepeatLearning({
    required int streakDays,
    required int completedLessonsCount,
  }) {
    _track('ai_university_repeat_learning', <String, dynamic>{
      'streak_days': streakDays,
      'completed_lessons_bucket': (completedLessonsCount / 5).floor() * 5,
    });
  }

  void _track(String eventName, Map<String, dynamic> properties) {
    if (_onTrack != null) {
      _onTrack(eventName, properties);
      return;
    }
    if (kDebugMode) {
      debugPrint('[AiUniversityFunnel] $eventName: $properties');
    }
  }
}
