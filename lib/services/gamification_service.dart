import 'package:flutter/foundation.dart';
import '../models/achievement.dart';
import '../models/user_stats.dart';

class GamificationService extends ChangeNotifier {
  // Provider経由でのアクセスを想定

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

  // ゲッター (StatsPage等で使用)
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

  // --- メソッド実装 ---

  Future<void> checkAchievements() async {
    // TODO: 実装
    notifyListeners();
  }

  // ポイント付与 (多くのサービスから呼ばれる)
  Future<void> awardPoints(int points, {String? reason}) async {
    debugPrint('Awarded $points points for $reason');
    notifyListeners();
  }

  // 統計データ取得 (StatsPageで使用)
  Future<UserStats?> getUserStats() async {
    // スタブ: 実際のDB取得ロジックは別途実装
    return null;
  }

  Future<void> initializeUserStats() async {
    // 初期化処理
  }

  Future<List<Achievement>> getUserAchievements() async {
    return [];
  }
}
