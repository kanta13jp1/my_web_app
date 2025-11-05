import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_stats.dart';
import '../models/achievement.dart';

class GamificationService {
  final SupabaseClient _supabase;

  GamificationService(this._supabase);

  // Initialize user stats for a new user
  Future<UserStats> initializeUserStats(String userId) async {
    try {
      // Check if stats already exist
      final existing = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return UserStats.fromJson(existing);
      }

      // Create new stats
      final stats = UserStats(userId: userId);
      final response = await _supabase
          .from('user_stats')
          .insert(stats.toJson())
          .select()
          .single();

      return UserStats.fromJson(response);
    } catch (e) {
      print('Error initializing user stats: $e');
      rethrow;
    }
  }

  // Get user stats
  Future<UserStats?> getUserStats(String userId) async {
    try {
      final response = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserStats.fromJson(response);
    } catch (e) {
      print('Error getting user stats: $e');
      return null;
    }
  }

  // Update user stats
  Future<UserStats> updateUserStats(UserStats stats) async {
    try {
      final response = await _supabase
          .from('user_stats')
          .update({
            ...stats.toJson(),
            'current_level': UserStats.calculateLevel(stats.totalPoints),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', stats.userId)
          .select()
          .single();

      return UserStats.fromJson(response);
    } catch (e) {
      print('Error updating user stats: $e');
      rethrow;
    }
  }

  // Add points and update level
  Future<UserStats> addPoints(String userId, int points) async {
    try {
      final stats = await getUserStats(userId);
      if (stats == null) {
        throw Exception('User stats not found');
      }

      final newTotalPoints = stats.totalPoints + points;
      final newLevel = UserStats.calculateLevel(newTotalPoints);

      final updatedStats = stats.copyWith(
        totalPoints: newTotalPoints,
        currentLevel: newLevel,
        updatedAt: DateTime.now(),
      );

      return await updateUserStats(updatedStats);
    } catch (e) {
      print('Error adding points: $e');
      rethrow;
    }
  }

  // Track activity and update streak
  Future<UserStats> trackActivity(String userId) async {
    try {
      final stats = await getUserStats(userId);
      if (stats == null) {
        throw Exception('User stats not found');
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastActivity = stats.lastActivityDate;

      int newStreak = stats.currentStreak;

      if (lastActivity == null) {
        // First activity
        newStreak = 1;
      } else {
        final lastActivityDay = DateTime(
          lastActivity.year,
          lastActivity.month,
          lastActivity.day,
        );
        final daysDifference = today.difference(lastActivityDay).inDays;

        if (daysDifference == 0) {
          // Same day, no change to streak
          return stats;
        } else if (daysDifference == 1) {
          // Consecutive day
          newStreak = stats.currentStreak + 1;
        } else {
          // Streak broken
          newStreak = 1;
        }
      }

      final updatedStats = stats.copyWith(
        currentStreak: newStreak,
        longestStreak:
            newStreak > stats.longestStreak ? newStreak : stats.longestStreak,
        lastActivityDate: now,
        updatedAt: now,
      );

      return await updateUserStats(updatedStats);
    } catch (e) {
      print('Error tracking activity: $e');
      rethrow;
    }
  }

  // Get user achievements
  Future<List<Achievement>> getUserAchievements(String userId) async {
    try {
      final userAchievements = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId);

      final allAchievements = AchievementDefinitions.getDefaultAchievements();
      final userAchievementMap = {
        for (var ua in userAchievements) ua['achievement_id']: ua
      };

      return allAchievements.map((achievement) {
        final userAchievement = userAchievementMap[achievement.id];
        if (userAchievement != null) {
          return achievement.copyWith(
            isUnlocked: userAchievement['is_unlocked'] ?? false,
            currentProgress: userAchievement['current_progress'] ?? 0,
            unlockedAt: userAchievement['unlocked_at'] != null
                ? DateTime.parse(userAchievement['unlocked_at'])
                : null,
          );
        }
        return achievement;
      }).toList();
    } catch (e) {
      print('Error getting user achievements: $e');
      return AchievementDefinitions.getDefaultAchievements();
    }
  }

  // Update achievement progress
  Future<Achievement?> updateAchievementProgress(
    String userId,
    String achievementId,
    int progress,
  ) async {
    try {
      final achievements = AchievementDefinitions.getDefaultAchievements();
      final achievement = achievements.firstWhere(
        (a) => a.id == achievementId,
        orElse: () => throw Exception('Achievement not found'),
      );

      // Check if achievement exists in database
      final existing = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .maybeSingle();

      final isUnlocked = progress >= achievement.targetValue;
      final now = DateTime.now();

      if (existing == null) {
        // Create new achievement record
        await _supabase.from('user_achievements').insert({
          'user_id': userId,
          'achievement_id': achievementId,
          'current_progress': progress,
          'is_unlocked': isUnlocked,
          'unlocked_at': isUnlocked ? now.toIso8601String() : null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      } else {
        // Update existing record
        final wasUnlocked = existing['is_unlocked'] ?? false;
        await _supabase
            .from('user_achievements')
            .update({
              'current_progress': progress,
              'is_unlocked': isUnlocked,
              'unlocked_at': isUnlocked && !wasUnlocked
                  ? now.toIso8601String()
                  : existing['unlocked_at'],
              'updated_at': now.toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('achievement_id', achievementId);
      }

      // If newly unlocked, award points
      if (isUnlocked && (existing == null || !(existing['is_unlocked'] ?? false))) {
        await addPoints(userId, achievement.pointsReward);
        return achievement.copyWith(
          isUnlocked: true,
          currentProgress: progress,
          unlockedAt: now,
        );
      }

      return null; // Not newly unlocked
    } catch (e) {
      print('Error updating achievement progress: $e');
      return null;
    }
  }

  // Check and update achievements based on stats
  Future<List<Achievement>> checkAchievements(String userId) async {
    try {
      final stats = await getUserStats(userId);
      if (stats == null) return [];

      final newlyUnlocked = <Achievement>[];

      // Check notes achievements
      final noteAchievements = {
        'first_note': 1,
        'note_creator_10': 10,
        'note_creator_50': 50,
        'note_creator_100': 100,
      };

      for (var entry in noteAchievements.entries) {
        if (stats.notesCreated >= entry.value) {
          final achievement = await updateAchievementProgress(
            userId,
            entry.key,
            stats.notesCreated,
          );
          if (achievement != null) newlyUnlocked.add(achievement);
        }
      }

      // Check category achievements
      final categoryAchievements = {
        'first_category': 1,
        'category_master': 5,
      };

      for (var entry in categoryAchievements.entries) {
        if (stats.categoriesCreated >= entry.value) {
          final achievement = await updateAchievementProgress(
            userId,
            entry.key,
            stats.categoriesCreated,
          );
          if (achievement != null) newlyUnlocked.add(achievement);
        }
      }

      // Check sharing achievements
      final shareAchievements = {
        'first_share': 1,
        'share_master': 10,
      };

      for (var entry in shareAchievements.entries) {
        if (stats.notesShared >= entry.value) {
          final achievement = await updateAchievementProgress(
            userId,
            entry.key,
            stats.notesShared,
          );
          if (achievement != null) newlyUnlocked.add(achievement);
        }
      }

      // Check streak achievements
      final streakAchievements = {
        'streak_3': 3,
        'streak_7': 7,
        'streak_30': 30,
      };

      for (var entry in streakAchievements.entries) {
        if (stats.currentStreak >= entry.value) {
          final achievement = await updateAchievementProgress(
            userId,
            entry.key,
            stats.currentStreak,
          );
          if (achievement != null) newlyUnlocked.add(achievement);
        }
      }

      return newlyUnlocked;
    } catch (e) {
      print('Error checking achievements: $e');
      return [];
    }
  }

  // Handle note creation event
  Future<List<Achievement>> onNoteCreated(String userId) async {
    try {
      // Track activity and update streak
      final stats = await trackActivity(userId);

      // Increment notes created
      final updatedStats = stats.copyWith(
        notesCreated: stats.notesCreated + 1,
      );
      await updateUserStats(updatedStats);

      // Award points for creating a note
      await addPoints(userId, 10);

      // Check for newly unlocked achievements
      return await checkAchievements(userId);
    } catch (e) {
      print('Error handling note creation: $e');
      return [];
    }
  }

  // Handle category creation event
  Future<List<Achievement>> onCategoryCreated(String userId) async {
    try {
      final stats = await getUserStats(userId);
      if (stats == null) return [];

      final updatedStats = stats.copyWith(
        categoriesCreated: stats.categoriesCreated + 1,
      );
      await updateUserStats(updatedStats);

      // Award points for creating a category
      await addPoints(userId, 15);

      return await checkAchievements(userId);
    } catch (e) {
      print('Error handling category creation: $e');
      return [];
    }
  }

  // Handle share creation event
  Future<List<Achievement>> onNoteShared(String userId) async {
    try {
      final stats = await getUserStats(userId);
      if (stats == null) return [];

      final updatedStats = stats.copyWith(
        notesShared: stats.notesShared + 1,
      );
      await updateUserStats(updatedStats);

      // Award points for sharing a note
      await addPoints(userId, 15);

      return await checkAchievements(userId);
    } catch (e) {
      print('Error handling note share: $e');
      return [];
    }
  }

  // Handle favorite event
  Future<Achievement?> onNoteFavorited(String userId) async {
    try {
      await addPoints(userId, 5);
      return await updateAchievementProgress(userId, 'first_favorite', 1);
    } catch (e) {
      print('Error handling note favorite: $e');
      return null;
    }
  }

  // Handle reminder event
  Future<Achievement?> onReminderSet(String userId) async {
    try {
      await addPoints(userId, 10);
      return await updateAchievementProgress(userId, 'first_reminder', 1);
    } catch (e) {
      print('Error handling reminder set: $e');
      return null;
    }
  }

  // Handle attachment event
  Future<Achievement?> onAttachmentAdded(String userId) async {
    try {
      await addPoints(userId, 10);
      return await updateAchievementProgress(userId, 'first_attachment', 1);
    } catch (e) {
      print('Error handling attachment added: $e');
      return null;
    }
  }
}
