import 'package:flutter/foundation.dart';
import '../models/achievement.dart';
import '../models/user_stats.dart';

class GamificationService extends ChangeNotifier {
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

  // 修正: ポイント付与は「名前付き引数 reason」を使用
  Future<void> awardPoints(int points, {String? reason}) async {
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
