import 'package:flutter/foundation.dart';
import '../models/achievement.dart';
import '../models/user_stats.dart';

class GamificationService extends ChangeNotifier {
  // コンストラクタ: 任意の引数を受け取れるようにして、旧コードの `GamificationService(context)` 等に対応
  GamificationService([dynamic _]);

  // --- カテゴリデータ (スタブ) ---
  final AchievementCategory _general =
      AchievementCategory(id: 'general', name: '一般', achievements: []);
  final AchievementCategory _notes =
      AchievementCategory(id: 'notes', name: 'メモ', achievements: []);
  final AchievementCategory _categories =
      AchievementCategory(id: 'categories', name: 'カテゴリ', achievements: []);
  final AchievementCategory _sharing =
      AchievementCategory(id: 'sharing', name: '共有', achievements: []);
  final AchievementCategory _organization =
      AchievementCategory(id: 'organization', name: '組織', achievements: []);
  final AchievementCategory _streak =
      AchievementCategory(id: 'streak', name: '継続', achievements: []);

  AchievementCategory get general => _general;
  AchievementCategory get notes => _notes;
  AchievementCategory get categories => _categories;
  AchievementCategory get sharing => _sharing;
  AchievementCategory get organization => _organization;
  AchievementCategory get streak => _streak;

  List<AchievementCategory> get achievementCategories =>
      [_general, _notes, _categories, _sharing, _organization, _streak];

  List<Achievement> get recentUnlocked => [];
  int get totalPoints => 0;

  Future<void> checkAchievements() async {
    notifyListeners();
  }

  // 柔軟なポイント付与メソッド: (int, [String]) でも (String, [String]) でも動くようにする
  Future<void> awardPoints(dynamic arg1, [dynamic arg2]) async {
    int points = 0;
    String reason = '';

    if (arg1 is int) {
      points = arg1;
      if (arg2 is String) reason = arg2;
    } else if (arg1 is String) {
      // 文字列("ACTION_NAME")が渡された場合の互換処理
      points = 10;
      reason = arg1;
    }

    debugPrint('Awarded $points points. Reason: $reason');
    notifyListeners();
  }

  Future<UserStats?> getUserStats() async {
    return null;
  }

  Future<void> initializeUserStats() async {}
  Future<List<Achievement>> getUserAchievements() async {
    return [];
  }
}
