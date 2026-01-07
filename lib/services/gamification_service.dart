import 'package:flutter/foundation.dart';
import '../models/achievement.dart';

class GamificationService extends ChangeNotifier {
  // シングルトンなどの構成が必要であれば適宜調整。現在はProvider利用を想定。

  List<AchievementCategory> get achievementCategories => [
        AchievementCategory(id: '1', name: '一般', achievements: []),
        AchievementCategory(id: '2', name: '断捨離', achievements: []),
      ];

  Future<void> checkAchievements() async {
    // TODO: 実装
    notifyListeners();
  }

  // 統計ページからの呼び出し互換用
  List<Achievement> get recentUnlocked => [];
  int get totalPoints => 0;
}
