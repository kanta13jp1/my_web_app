import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/achievement.dart';

void main() {
  group('Achievement', () {
    test('should create an instance with default values', () {
      final achievement = Achievement(
        id: 'test_id',
        title: 'Test Achievement',
        description: 'This is a test achievement.',
        iconCode: 'test_icon',
      );

      expect(achievement.id, 'test_id');
      expect(achievement.title, 'Test Achievement');
      expect(achievement.description, 'This is a test achievement.');
      expect(achievement.iconCode, 'test_icon');
      expect(achievement.icon, isNull);
      expect(achievement.isUnlocked, isFalse);
      expect(achievement.progress, 0.0);
      expect(achievement.pointsReward, 0);
      expect(achievement.currentProgress, 0);
      expect(achievement.targetValue, 100);
      expect(achievement.unlockedAt, isNull);
    });

    test('should create an instance with all fields', () {
      final unlockedDate = DateTime.now();
      final achievement = Achievement(
        id: 'test_id_2',
        title: 'Complete Achievement',
        description: 'This is a complete achievement.',
        iconCode: 'complete_icon',
        icon: 'some_icon_data',
        isUnlocked: true,
        progress: 1.0,
        pointsReward: 50,
        currentProgress: 100,
        targetValue: 100,
        unlockedAt: unlockedDate,
      );

      expect(achievement.id, 'test_id_2');
      expect(achievement.title, 'Complete Achievement');
      expect(achievement.description, 'This is a complete achievement.');
      expect(achievement.iconCode, 'complete_icon');
      expect(achievement.icon, 'some_icon_data');
      expect(achievement.isUnlocked, isTrue);
      expect(achievement.progress, 1.0);
      expect(achievement.pointsReward, 50);
      expect(achievement.currentProgress, 100);
      expect(achievement.targetValue, 100);
      expect(achievement.unlockedAt, unlockedDate);
    });

    test('progressPercentage getter should return the progress value', () {
      final achievement = Achievement(
        id: 'progress_test',
        title: 'Progress Test',
        description: 'Testing progress.',
        iconCode: 'progress_icon',
        progress: 0.75,
      );

      expect(achievement.progressPercentage, 0.75);
    });
  });

  group('AchievementCategory', () {
    test('should create an instance of AchievementCategory', () {
      final achievement = Achievement(
        id: 'test_id',
        title: 'Test Achievement',
        description: 'This is a test achievement.',
        iconCode: 'test_icon',
      );
      final category = AchievementCategory(
        id: 'cat_id',
        name: 'Test Category',
        achievements: [achievement],
      );

      expect(category.id, 'cat_id');
      expect(category.name, 'Test Category');
      expect(category.achievements, [achievement]);
      expect(category.achievements.length, 1);
    });
  });
}
