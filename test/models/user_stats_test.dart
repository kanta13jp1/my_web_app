import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_stats.dart';

void main() {
  group('UserStats Model Tests', () {
    test('calculateLevel works correctly', () {
      expect(UserStats.calculateLevel(0), 1);
      expect(UserStats.calculateLevel(99), 1);
      expect(UserStats.calculateLevel(100), 2);
      expect(UserStats.calculateLevel(399), 2);
      expect(UserStats.calculateLevel(400), 3);
      expect(UserStats.calculateLevel(899), 3);
      expect(UserStats.calculateLevel(900), 4);
      expect(UserStats.calculateLevel(1599), 4);
      expect(UserStats.calculateLevel(1600), 5);
    });

    test('pointsForNextLevel calculates correctly', () {
      final stats = UserStats(
        userId: 'test',
        currentLevel: 5,
        totalPoints: 1650,
      );
      expect(
        stats.pointsForNextLevel,
        2500,
      ); // Level 6 needs (6-1)^2 * 100 = 2500
    });

    test('pointsForCurrentLevel calculates correctly', () {
      final stats = UserStats(
        userId: 'test',
        currentLevel: 5,
        totalPoints: 1650,
      );
      expect(
        stats.pointsForCurrentLevel,
        1600,
      ); // Level 5 starts at (5-1)^2 * 100 = 1600
    });

    test('levelProgress calculates correctly', () {
      final stats = UserStats(
        userId: 'test',
        currentLevel: 5,
        totalPoints: 2050,
      ); // 1600 for lv5, 2500 for lv6
      // Progress = (2050 - 1600) / (2500 - 1600) = 450 / 900 = 0.5
      expect(stats.levelProgress, 0.5);
    });

    test('levelProgress handles level 1 correctly', () {
      final stats = UserStats(userId: 'test', currentLevel: 1, totalPoints: 50);
      // Progress = (50 - 0) / (100 - 0) = 0.5
      expect(stats.levelProgress, 0.5);
    });

    test('levelTitle returns correct titles', () {
      expect(UserStats(userId: 't', currentLevel: 1).levelTitle, 'メモ初心者');
      expect(UserStats(userId: 't', currentLevel: 4).levelTitle, 'メモ学習者');
      expect(UserStats(userId: 't', currentLevel: 9).levelTitle, 'メモの使い手');
      expect(UserStats(userId: 't', currentLevel: 14).levelTitle, 'メモマスター');
      expect(UserStats(userId: 't', currentLevel: 19).levelTitle, 'メモの達人');
      expect(UserStats(userId: 't', currentLevel: 25).levelTitle, 'メモの神');
    });

    test('copyWith creates a correct copy', () {
      final original = UserStats(userId: 'original', totalPoints: 100);
      final copied = original.copyWith(totalPoints: 200, currentStreak: 5);

      expect(copied.userId, 'original');
      expect(copied.totalPoints, 200);
      expect(copied.currentStreak, 5);
      expect(copied.notesCreated, original.notesCreated);
    });

    test('Serialization and Deserialization (toJson/fromJson)', () {
      final now = DateTime.now();
      final original = UserStats(
        userId: 'user1',
        totalPoints: 500,
        currentLevel: 3,
        notesCreated: 10,
        currentStreak: 5,
        lastActivityDate: now,
      );
      final json = original.toJson();
      final fromJson = UserStats.fromJson(json);

      expect(fromJson.userId, original.userId);
      expect(fromJson.totalPoints, original.totalPoints);
      expect(fromJson.currentLevel, original.currentLevel);
      expect(
        fromJson.lastActivityDate?.toIso8601String(),
        original.lastActivityDate?.toIso8601String(),
      );
    });
  });

  group('UserAchievement Model Tests', () {
    test('Serialization and Deserialization (toJson/fromJson)', () {
      final now = DateTime.now();
      final original = UserAchievement(
        id: 1,
        userId: 'user1',
        achievementId: 'first_note',
        currentProgress: 1,
        isUnlocked: true,
        unlockedAt: now,
      );
      final json = original.toJson();
      final fromJson = UserAchievement.fromJson(json);

      expect(fromJson.id, original.id);
      expect(fromJson.userId, original.userId);
      expect(fromJson.achievementId, original.achievementId);
      expect(fromJson.isUnlocked, isTrue);
      expect(
        fromJson.unlockedAt?.toIso8601String(),
        original.unlockedAt?.toIso8601String(),
      );
    });

    test('toJson handles null id', () {
      final original = UserAchievement(
        userId: 'user1',
        achievementId: 'first_note',
      );
      final json = original.toJson();

      expect(json.containsKey('id'), isFalse);
    });
  });
}
