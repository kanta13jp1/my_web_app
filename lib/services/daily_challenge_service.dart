import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_challenge.dart';
import '../utils/app_logger.dart';

class DailyChallengeService {
  final SupabaseClient _supabase;

  DailyChallengeService(this._supabase);

  // Get today's challenges
  Future<List<DailyChallenge>> getTodaysChallenges() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('daily_challenges')
          .select()
          .eq('challenge_date', today)
          .eq('is_active', true);

      return (response as List)
          .map((json) => DailyChallenge.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get today\'s challenges', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Get user's challenge progress
  Future<List<UserChallengeProgress>> getUserChallengeProgress(
      String userId) async {
    try {
      final response = await _supabase
          .from('user_challenge_progress')
          .select()
          .eq('user_id', userId);

      return (response as List)
          .map((json) => UserChallengeProgress.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user challenge progress', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Get combined challenges with progress
  Future<List<Map<String, dynamic>>> getTodaysChallengesWithProgress(
      String userId) async {
    try {
      final challenges = await getTodaysChallenges();
      final progressList = await getUserChallengeProgress(userId);

      // Create a map of challenge_id -> progress
      final progressMap = {
        for (var p in progressList) p.challengeId: p
      };

      return challenges.map((challenge) {
        final progress = progressMap[challenge.id];
        return {
          'challenge': challenge,
          'progress': progress,
          'current_progress': progress?.currentProgress ?? 0,
          'is_completed': progress?.isCompleted ?? false,
          'reward_claimed': progress?.rewardClaimed ?? false,
        };
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to get challenges with progress', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Update challenge progress
  Future<void> updateChallengeProgress(
    String userId,
    int challengeId,
    int progressIncrement,
  ) async {
    try {
      // Get or create progress record
      final existingProgress = await _supabase
          .from('user_challenge_progress')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .maybeSingle();

      if (existingProgress == null) {
        // Create new progress
        await _supabase.from('user_challenge_progress').insert({
          'user_id': userId,
          'challenge_id': challengeId,
          'current_progress': progressIncrement,
          'is_completed': false,
        });
      } else {
        // Update existing progress
        final currentProgress = existingProgress['current_progress'] as int;
        final newProgress = currentProgress + progressIncrement;

        // Get challenge to check target
        final challenge = await _supabase
            .from('daily_challenges')
            .select('target_value')
            .eq('id', challengeId)
            .single();

        final targetValue = challenge['target_value'] as int;
        final isCompleted = newProgress >= targetValue;

        await _supabase
            .from('user_challenge_progress')
            .update({
              'current_progress': newProgress,
              'is_completed': isCompleted,
              'completed_at': isCompleted
                  ? DateTime.now().toIso8601String()
                  : existingProgress['completed_at'],
            })
            .eq('user_id', userId)
            .eq('challenge_id', challengeId);
      }

      AppLogger.info('Challenge progress updated');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update challenge progress', error: e, stackTrace: stackTrace);
    }
  }

  // Claim challenge reward
  Future<bool> claimChallengeReward(String userId, int challengeId) async {
    try {
      // Get progress
      final progress = await _supabase
          .from('user_challenge_progress')
          .select()
          .eq('user_id', userId)
          .eq('challenge_id', challengeId)
          .single();

      if (!(progress['is_completed'] as bool)) {
        AppLogger.warning('Challenge not completed yet');
        return false;
      }

      if (progress['reward_claimed'] as bool) {
        AppLogger.warning('Reward already claimed');
        return false;
      }

      // Get challenge reward points
      final challenge = await _supabase
          .from('daily_challenges')
          .select('reward_points')
          .eq('id', challengeId)
          .single();

      final rewardPoints = challenge['reward_points'] as int;

      // Award points
      final stats = await _supabase
          .from('user_stats')
          .select('total_points')
          .eq('user_id', userId)
          .single();

      final currentPoints = stats['total_points'] as int;
      await _supabase
          .from('user_stats')
          .update({'total_points': currentPoints + rewardPoints})
          .eq('user_id', userId);

      // Mark reward as claimed
      await _supabase
          .from('user_challenge_progress')
          .update({'reward_claimed': true})
          .eq('user_id', userId)
          .eq('challenge_id', challengeId);

      AppLogger.info('Challenge reward claimed: $rewardPoints points');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to claim challenge reward', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Track activity for challenges (called by gamification service)
  Future<void> trackActivityForChallenges(
    String userId,
    String activityType,
    int count,
  ) async {
    try {
      // Get today's challenges of matching type
      final today = DateTime.now().toIso8601String().split('T')[0];
      final challenges = await _supabase
          .from('daily_challenges')
          .select('id')
          .eq('challenge_date', today)
          .eq('challenge_type', activityType)
          .eq('is_active', true);

      // Update progress for each matching challenge
      for (final challenge in challenges) {
        await updateChallengeProgress(
          userId,
          challenge['id'] as int,
          count,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to track activity for challenges', error: e, stackTrace: stackTrace);
    }
  }
}
