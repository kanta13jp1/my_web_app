import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_challenge.dart';
import '../utils/app_logger.dart';

class DailyChallengeService {
  final SupabaseClient _supabase;

  DailyChallengeService(this._supabase);

  /// 今日のチャレンジと進捗状況を取得
  Future<List<Map<String, dynamic>>> getTodaysChallengesWithProgress(String userId) async {
    try {
      final now = DateTime.now();
      // YYYY-MM-DD 形式 (サーバー側の日付判定用)
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // 作成したRPCを呼び出す
      final response = await _supabase.rpc(
        'get_my_daily_challenges',
        params: {'p_date': todayStr},
      );

      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        return {
          'challenge': DailyChallenge.fromJson(item),
          // SQLの戻り値の列名をそのまま使用
          'current_progress': item['current_progress'] as int,
          'is_completed': item['is_completed'] as bool,
          'reward_claimed': item['reward_claimed'] as bool,
        };
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load challenges', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// 報酬を受け取る
  Future<bool> claimChallengeReward(String userId, int challengeId) async {
    try {
      // RPC呼び出し（ポイント付与もサーバー側で行われる）
      final success = await _supabase.rpc(
        'claim_challenge_reward',
        params: {'p_challenge_id': challengeId},
      );
      return success as bool;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to claim reward', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 進捗を更新する（メモ作成、シェア等のアクション時に呼ぶ）
  Future<void> updateProgress(String userId, String type, {int amount = 1}) async {
    try {
      // RPC呼び出し
      await _supabase.rpc(
        'increment_challenge_progress',
        params: {
          'p_user_id': userId,
          'p_challenge_type': type,
          'p_amount': amount,
        },
      );
    } catch (e) {
      // ユーザー操作を妨げないよう、ログ出力のみ
      AppLogger.warning('Failed to update challenge progress: $type', error: e);
    }
  }
  
  // 互換性のためのエイリアス（以前のコードで呼ばれている場合）
  Future<void> trackActivityForChallenges(String userId, String type, int amount) async {
    await updateProgress(userId, type, amount: amount);
  }
}