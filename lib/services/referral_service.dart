import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/referral_code.dart';
import '../utils/app_logger.dart';

class ReferralService {
  final SupabaseClient _supabase;

  ReferralService(this._supabase);

  // Get user's referral code
  Future<ReferralCode?> getUserReferralCode(String userId) async {
    try {
      final response = await _supabase
          .from('referral_codes')
          .select()
          .eq('user_id', userId)
          .single();

      return ReferralCode.fromJson(response);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user referral code', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // Validate referral code
  Future<bool> validateReferralCode(String code) async {
    try {
      final response = await _supabase
          .from('referral_codes')
          .select('id')
          .eq('referral_code', code.toUpperCase())
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to validate referral code', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Apply referral code (called during signup)
  Future<bool> applyReferralCode(String referredUserId, String code) async {
    try {
      AppLogger.info('Applying referral code: $code for user: $referredUserId');

      // Get referrer info
      final referrerResponse = await _supabase
          .from('referral_codes')
          .select('user_id, id')
          .eq('referral_code', code.toUpperCase())
          .maybeSingle();

      if (referrerResponse == null) {
        AppLogger.warning('Invalid referral code: $code');
        return false;
      }

      final referrerUserId = referrerResponse['user_id'] as String;

      // Check if user has already been referred
      final existingReferral = await _supabase
          .from('referrals')
          .select('id')
          .eq('referred_user_id', referredUserId)
          .maybeSingle();

      if (existingReferral != null) {
        AppLogger.warning('User already has a referral');
        return false;
      }

      // Cannot refer yourself
      if (referrerUserId == referredUserId) {
        AppLogger.warning('Cannot use your own referral code');
        return false;
      }

      // Create referral record
      await _supabase.from('referrals').insert({
        'referrer_user_id': referrerUserId,
        'referred_user_id': referredUserId,
        'referral_code': code.toUpperCase(),
        'bonus_points': 100, // Base bonus
        'status': 'pending',
      });

      // Update referral code stats
      await _supabase
          .from('referral_codes')
          .update({'total_referrals': referrerResponse['id']})
          .eq('user_id', referrerUserId);

      AppLogger.info('Referral code applied successfully');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to apply referral code', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Complete referral (when referred user completes onboarding)
  Future<void> completeReferral(String referredUserId) async {
    try {
      // Get referral info
      final referralResponse = await _supabase
          .from('referrals')
          .select('referrer_user_id, bonus_points')
          .eq('referred_user_id', referredUserId)
          .eq('status', 'pending')
          .maybeSingle();

      if (referralResponse == null) {
        return;
      }

      final referrerUserId = referralResponse['referrer_user_id'] as String;
      final bonusPoints = referralResponse['bonus_points'] as int;

      // Mark referral as completed
      await _supabase
          .from('referrals')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('referred_user_id', referredUserId);

      // Award bonus points to referrer
      final statsResponse = await _supabase
          .from('user_stats')
          .select('total_points')
          .eq('user_id', referrerUserId)
          .single();

      final currentPoints = statsResponse['total_points'] as int;
      final newPoints = currentPoints + bonusPoints;

      await _supabase
          .from('user_stats')
          .update({'total_points': newPoints})
          .eq('user_id', referrerUserId);

      // Update referral code stats
      final codeResponse = await _supabase
          .from('referral_codes')
          .select('successful_referrals, bonus_points_earned')
          .eq('user_id', referrerUserId)
          .single();

      await _supabase
          .from('referral_codes')
          .update({
            'successful_referrals':
                (codeResponse['successful_referrals'] as int) + 1,
            'bonus_points_earned':
                (codeResponse['bonus_points_earned'] as int) + bonusPoints,
          })
          .eq('user_id', referrerUserId);

      AppLogger.info('Referral completed successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to complete referral', error: e, stackTrace: stackTrace);
    }
  }

  // Get referral leaderboard
  Future<List<Map<String, dynamic>>> getReferralLeaderboard({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('referral_codes')
          .select('user_id, referral_code, successful_referrals, bonus_points_earned')
          .order('successful_referrals', ascending: false)
          .order('bonus_points_earned', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get referral leaderboard', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Get user's referrals
  Future<List<Map<String, dynamic>>> getUserReferrals(String userId) async {
    try {
      final response = await _supabase
          .from('referrals')
          .select('referred_user_id, status, bonus_points, created_at, completed_at')
          .eq('referrer_user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user referrals', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  // Generate shareable referral link
  String generateReferralLink(String referralCode, String baseUrl) {
    return '$baseUrl/signup?ref=$referralCode';
  }
}
