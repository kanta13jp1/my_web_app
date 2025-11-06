import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

class DailyLoginService {
  final SupabaseClient _supabase;

  DailyLoginService(this._supabase);

  // Calculate bonus points based on consecutive days
  int _calculateBonusPoints(int consecutiveDays) {
    if (consecutiveDays <= 3) return 10;
    if (consecutiveDays <= 7) return 20;
    if (consecutiveDays <= 14) return 30;
    if (consecutiveDays <= 30) return 50;
    return 100; // 30+ days
  }

  // Check and award daily login bonus
  Future<Map<String, dynamic>?> checkDailyLoginBonus(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Check if already claimed today
      final todayLogin = await _supabase
          .from('daily_login_rewards')
          .select()
          .eq('user_id', userId)
          .eq('login_date', today)
          .maybeSingle();

      if (todayLogin != null) {
        AppLogger.info('Daily login bonus already claimed today');
        return {
          'already_claimed': true,
          'consecutive_days': todayLogin['consecutive_days'],
          'bonus_points': todayLogin['bonus_points'],
        };
      }

      // Get yesterday's login
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];

      final yesterdayLogin = await _supabase
          .from('daily_login_rewards')
          .select()
          .eq('user_id', userId)
          .eq('login_date', yesterday)
          .maybeSingle();

      // Calculate consecutive days
      int consecutiveDays = 1;
      if (yesterdayLogin != null) {
        consecutiveDays = (yesterdayLogin['consecutive_days'] as int) + 1;
      }

      // Calculate bonus points
      final bonusPoints = _calculateBonusPoints(consecutiveDays);

      // Record login
      await _supabase.from('daily_login_rewards').insert({
        'user_id': userId,
        'login_date': today,
        'consecutive_days': consecutiveDays,
        'bonus_points': bonusPoints,
      });

      // Award points
      final stats = await _supabase
          .from('user_stats')
          .select('total_points')
          .eq('user_id', userId)
          .single();

      final currentPoints = stats['total_points'] as int;
      await _supabase
          .from('user_stats')
          .update({'total_points': currentPoints + bonusPoints})
          .eq('user_id', userId);

      AppLogger.info(
          'Daily login bonus awarded: $bonusPoints points (Day $consecutiveDays)');

      return {
        'already_claimed': false,
        'consecutive_days': consecutiveDays,
        'bonus_points': bonusPoints,
        'is_new_bonus': true,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check daily login bonus', e, stackTrace);
      return null;
    }
  }

  // Get user's login streak
  Future<int> getUserLoginStreak(String userId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final todayLogin = await _supabase
          .from('daily_login_rewards')
          .select('consecutive_days')
          .eq('user_id', userId)
          .eq('login_date', today)
          .maybeSingle();

      if (todayLogin != null) {
        return todayLogin['consecutive_days'] as int;
      }

      // Check yesterday
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];

      final yesterdayLogin = await _supabase
          .from('daily_login_rewards')
          .select('consecutive_days')
          .eq('user_id', userId)
          .eq('login_date', yesterday)
          .maybeSingle();

      return yesterdayLogin?['consecutive_days'] as int? ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user login streak', e, stackTrace);
      return 0;
    }
  }

  // Get user's total login days
  Future<int> getUserTotalLoginDays(String userId) async {
    try {
      final response = await _supabase
          .from('daily_login_rewards')
          .select('id')
          .eq('user_id', userId);

      return (response as List).length;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user total login days', e, stackTrace);
      return 0;
    }
  }

  // Get user's login history
  Future<List<Map<String, dynamic>>> getUserLoginHistory(
    String userId, {
    int limit = 30,
  }) async {
    try {
      final response = await _supabase
          .from('daily_login_rewards')
          .select()
          .eq('user_id', userId)
          .order('login_date', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user login history', e, stackTrace);
      return [];
    }
  }
}
