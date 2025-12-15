import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_stats.dart';
import '../models/achievement.dart';
import '../models/leaderboard_entry.dart';
import '../models/reward.dart';
import '../main.dart';
import '../utils/app_logger.dart';

class GamificationService {
  final SupabaseClient _supabase;

  GamificationService([SupabaseClient? supabaseClient])
      : _supabase = supabaseClient ?? supabase;

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
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error initializing user stats',
        error: e,
        stackTrace: stackTrace,
      );
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
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting user stats',
        error: e,
        stackTrace: stackTrace,
      );
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
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error updating user stats',
        error: e,
        stackTrace: stackTrace,
      );
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
    } catch (e, stackTrace) {
      AppLogger.error('Error adding points', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Award points with optional reason for tracking
  Future<UserStats> awardPoints(
    String userId,
    int points, {
    String? reason,
  }) async {
    try {
      if (reason != null) {
        AppLogger.info('Awarding $points points to user $userId: $reason');
      }
      return await addPoints(userId, points);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error awarding points',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Track activity and update streak (This counts as OUTPUT)
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
        } else if (daysDifference == 1) {
          // Consecutive day
          newStreak = stats.currentStreak + 1;
        } else {
          // Streak broken
          newStreak = 1;
        }
      }

      final statsJson = stats
          .copyWith(
            currentStreak: newStreak,
            longestStreak: newStreak > stats.longestStreak
                ? newStreak
                : stats.longestStreak,
            lastActivityDate: now,
            updatedAt: now,
          )
          .toJson();

      statsJson['last_output_at'] = now.toIso8601String();
      statsJson['current_level'] = UserStats.calculateLevel(stats.totalPoints);

      final response = await _supabase
          .from('user_stats')
          .update(statsJson)
          .eq('user_id', userId)
          .select()
          .single();

      return UserStats.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error tracking activity (output)',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Apply penalty
  Future<void> applyPenalty({
    required String userId,
    required String reason,
    int levelDownAmount = 0,
    int pointDeduction = 0,
    bool resetStreak = false,
  }) async {
    try {
      final stats = await getUserStats(userId);
      if (stats == null) return;

      int newLevel = stats.currentLevel;
      int newPoints = stats.totalPoints;
      int newStreak = stats.currentStreak;

      if (levelDownAmount > 0) {
        newLevel = (newLevel - levelDownAmount).clamp(1, 999);
      }

      if (pointDeduction > 0) {
        newPoints = (newPoints - pointDeduction).clamp(0, 9999999);
      }

      if (resetStreak) {
        newStreak = 0;
      }

      await _supabase.from('penalty_logs').insert({
        'user_id': userId,
        'penalty_type': [
          if (levelDownAmount > 0) 'level_down',
          if (pointDeduction > 0) 'point_loss',
          if (resetStreak) 'streak_reset',
        ].join(','),
        'reason': reason,
        'amount_lost': pointDeduction,
        'created_at': DateTime.now().toIso8601String(),
      });

      await _supabase.from('user_stats').update({
        'current_level': newLevel,
        'total_points': newPoints,
        'current_streak': newStreak,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);

      AppLogger.warning('Penalty applied to user $userId: $reason');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error applying penalty',
        error: e,
        stackTrace: stackTrace,
      );
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
        for (var ua in userAchievements) ua['achievement_id']: ua,
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
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting user achievements',
        error: e,
        stackTrace: stackTrace,
      );
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

      final existing = await _supabase
          .from('user_achievements')
          .select()
          .eq('user_id', userId)
          .eq('achievement_id', achievementId)
          .maybeSingle();

      final isUnlocked = progress >= achievement.targetValue;
      final now = DateTime.now();

      if (existing == null) {
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
        final wasUnlocked = (existing['is_unlocked'] as bool?) ?? false;
        await _supabase
            .from('user_achievements')
            .update({
              'current_progress': progress,
              'is_unlocked': isUnlocked,
              'unlocked_at': isUnlocked && !wasUnlocked
                  ? now.toIso8601String()
                  : (existing['unlocked_at'] as String?),
              'updated_at': now.toIso8601String(),
            })
            .eq('user_id', userId)
            .eq('achievement_id', achievementId);
      }

      if (isUnlocked &&
          (existing == null ||
              !((existing['is_unlocked'] as bool?) ?? false))) {
        await addPoints(userId, achievement.pointsReward);
        return achievement.copyWith(
          isUnlocked: true,
          currentProgress: progress,
          unlockedAt: now,
        );
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error updating achievement progress',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // Check and update achievements based on stats
  Future<List<Achievement>> checkAchievements(String userId) async {
    try {
      final stats = await getUserStats(userId);
      if (stats == null) return [];

      final newlyUnlocked = <Achievement>[];

      // Note achievements
      final noteAchievements = {
        'first_note': 1,
        'note_creator_10': 10,
        'note_creator_50': 50,
        'note_creator_100': 100,
        'note_creator_200': 200,
        'note_creator_500': 500,
        'note_creator_1000': 1000,
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

      // Category achievements
      final categoryAchievements = {
        'first_category': 1,
        'category_master': 5,
        'category_expert': 10,
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

      // Share achievements
      final shareAchievements = {
        'first_share': 1,
        'share_master': 10,
        'share_expert': 50,
        'share_legend': 100,
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

      // Streak achievements
      final streakAchievements = {
        'streak_3': 3,
        'streak_7': 7,
        'streak_30': 30,
        'streak_60': 60,
        'streak_90': 90,
        'streak_365': 365,
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

      // Level achievements
      final levelAchievements = {
        'level_5': 5,
        'level_10': 10,
        'level_20': 20,
        'level_50': 50,
      };

      for (var entry in levelAchievements.entries) {
        if (stats.currentLevel >= entry.value) {
          final achievement = await updateAchievementProgress(
            userId,
            entry.key,
            stats.currentLevel,
          );
          if (achievement != null) newlyUnlocked.add(achievement);
        }
      }

      // Points achievements
      final pointsAchievements = {
        'points_1000': 1000,
        'points_5000': 5000,
        'points_10000': 10000,
      };

      for (var entry in pointsAchievements.entries) {
        if (stats.totalPoints >= entry.value) {
          final achievement = await updateAchievementProgress(
            userId,
            entry.key,
            stats.totalPoints,
          );
          if (achievement != null) newlyUnlocked.add(achievement);
        }
      }

      return newlyUnlocked;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error checking achievements',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Handle note creation
  Future<List<Achievement>> onNoteCreated(String userId) async {
    try {
      final stats = await trackActivity(userId);
      final updatedStats = stats.copyWith(
        notesCreated: stats.notesCreated + 1,
      );
      await updateUserStats(updatedStats);
      await addPoints(userId, 10);
      return await checkAchievements(userId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error handling note creation',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Handle category creation
  Future<List<Achievement>> onCategoryCreated(String userId) async {
    try {
      await trackActivity(userId);
      final stats = await getUserStats(userId);
      if (stats == null) return [];

      final updatedStats = stats.copyWith(
        categoriesCreated: stats.categoriesCreated + 1,
      );
      await updateUserStats(updatedStats);
      await addPoints(userId, 15);
      return await checkAchievements(userId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error handling category creation',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Handle note shared
  Future<List<Achievement>> onNoteShared(String userId) async {
    try {
      await trackActivity(userId);
      final stats = await getUserStats(userId);
      if (stats == null) return [];

      final updatedStats = stats.copyWith(
        notesShared: stats.notesShared + 1,
      );
      await updateUserStats(updatedStats);
      await addPoints(userId, 15);
      return await checkAchievements(userId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error handling note share',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Handle note favorited
  Future<List<Achievement>> onNoteFavorited(String userId) async {
    try {
      await addPoints(userId, 5);
      final achievement =
          await updateAchievementProgress(userId, 'first_favorite', 1);
      return achievement != null ? [achievement] : [];
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error handling note favorite',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Handle reminder set
  Future<List<Achievement>> onReminderSet(String userId) async {
    try {
      await addPoints(userId, 10);
      final achievement =
          await updateAchievementProgress(userId, 'first_reminder', 1);
      return achievement != null ? [achievement] : [];
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error handling reminder set',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Handle attachment added
  Future<List<Achievement>> onAttachmentAdded(String userId) async {
    try {
      await addPoints(userId, 10);
      final achievement =
          await updateAchievementProgress(userId, 'first_attachment', 1);
      return achievement != null ? [achievement] : [];
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error handling attachment added',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Record generic activity log
  Future<void> recordActivity({
    required String userId,
    required String type,
    required String description,
    required DateTime timestamp,
  }) async {
    try {
      await _supabase.from('activities').insert({
        'user_id': userId,
        'type': type,
        'action': description,
        'timestamp': timestamp.toIso8601String(),
      });
      AppLogger.info('Activity recorded: $type for user $userId');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error recording activity $type',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ✅ 修正済み: 匿名ユーザーを除外してリーダーボードを取得
  Future<List<LeaderboardEntry>> getLeaderboard({
    int limit = 100,
    String orderBy = 'total_points',
  }) async {
    try {
      AppLogger.debug(
        'Fetching leaderboard - orderBy: $orderBy, limit: $limit',
      );

      // Viewではなく user_stats と user_profiles を内部結合(!inner)し、
      // 匿名ユーザー(is_anonymous = true)を除外する
      final response = await _supabase
          .from('user_stats')
          .select('*, user_profiles!inner(*)') // !inner で内部結合を指定
          .eq('user_profiles.is_anonymous', false) // 結合先テーブルの条件指定
          .order(orderBy, ascending: false)
          .limit(limit);

      AppLogger.debug(
        'Query successful - response length: ${(response as List).length}',
      );

      final entries = <LeaderboardEntry>[];
      for (int i = 0; i < response.length; i++) {
        // Joinしたデータを、LeaderboardEntry.fromJson が期待するフラットな形に変換
        final data = Map<String, dynamic>.from(response[i]);
        if (data['user_profiles'] != null) {
          final profile = data['user_profiles'] as Map<String, dynamic>;
          data.addAll(profile); // プロフィール情報をルートにマージ
        }
        entries.add(LeaderboardEntry.fromJson(data, i + 1));
      }

      AppLogger.debug('Leaderboard entries created: ${entries.length}');
      return entries;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting leaderboard',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // ✅ 修正済み: 自分のランク取得時も匿名ユーザーを除外してカウント
  Future<int?> getUserRank(
    String userId, {
    String orderBy = 'total_points',
  }) async {
    try {
      AppLogger.debug('Getting user rank for: $userId, orderBy: $orderBy');

      // 匿名以外のユーザーのみを取得してソート
      final userList = await _supabase
          .from('user_stats')
          .select('user_id, $orderBy, user_profiles!inner(is_anonymous)')
          .eq('user_profiles.is_anonymous', false)
          .order(orderBy, ascending: false);

      AppLogger.debug('Total valid users in ranking: ${userList.length}');

      for (int i = 0; i < userList.length; i++) {
        if (userList[i]['user_id'] == userId) {
          AppLogger.debug('User found at rank: ${i + 1}');
          return i + 1;
        }
      }

      AppLogger.warning(
        'User not found in ranking (might be anonymous or no stats)',
      );
      return null;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting user rank',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  // Get user rewards (check unlocked status)
  Future<List<Reward>> getUserRewards(String userId) async {
    try {
      final stats = await getUserStats(userId);
      final achievements = await getUserAchievements(userId);

      if (stats == null) return RewardDefinitions.getDefaultRewards();

      final allRewards = RewardDefinitions.getDefaultRewards();
      final achievementMap = {for (var a in achievements) a.id: a};

      return allRewards.map((reward) {
        bool isUnlocked = false;

        // Check level requirement
        if (reward.requiredLevel > 0 &&
            stats.currentLevel >= reward.requiredLevel) {
          isUnlocked = true;
        }

        // Check achievement requirement
        if (reward.requiredAchievementId != null) {
          final requiredAchievement =
              achievementMap[reward.requiredAchievementId];
          if (requiredAchievement != null && requiredAchievement.isUnlocked) {
            isUnlocked = true;
          } else {
            isUnlocked = false;
          }
        }

        // Check points requirement
        if (reward.requiredPoints != null &&
            stats.totalPoints < reward.requiredPoints!) {
          isUnlocked = false;
        }

        return reward.copyWith(
          isUnlocked: isUnlocked,
          unlockedAt: isUnlocked ? DateTime.now() : null,
        );
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting user rewards',
        error: e,
        stackTrace: stackTrace,
      );
      return RewardDefinitions.getDefaultRewards();
    }
  }

  // Get unlocked themes
  Future<List<Reward>> getUnlockedThemes(String userId) async {
    try {
      final rewards = await getUserRewards(userId);
      return rewards
          .where((r) => r.type == RewardType.theme && r.isUnlocked)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting unlocked themes',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Get unlocked badges
  Future<List<Reward>> getUnlockedBadges(String userId) async {
    try {
      final rewards = await getUserRewards(userId);
      return rewards
          .where((r) => r.type == RewardType.badge && r.isUnlocked)
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error getting unlocked badges',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  // Check if feature is unlocked
  Future<bool> isFeatureUnlocked(String userId, String featureId) async {
    try {
      final rewards = await getUserRewards(userId);
      final feature = rewards.firstWhere(
        (r) => r.id == featureId && r.type == RewardType.feature,
        orElse: () => Reward(
          id: featureId,
          title: '',
          description: '',
          icon: '',
          type: RewardType.feature,
        ),
      );
      return feature.isUnlocked;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error checking feature unlock',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
