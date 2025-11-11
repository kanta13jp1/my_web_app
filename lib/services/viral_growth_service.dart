import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'gamification_service.dart';

/// バイラル成長施策を管理するサービス
class ViralGrowthService {
  final SupabaseClient _supabase;
  final GamificationService _gamificationService;

  ViralGrowthService(this._supabase)
      : _gamificationService = GamificationService(_supabase);

  /// シェア報酬の倍増（通常10pt → キャンペーン中は50pt）
  Future<void> awardShareBonus({
    required String userId,
    required String platform,
    bool isCampaignActive = false,
  }) async {
    try {
      final basePoints = 10;
      final campaignMultiplier = isCampaignActive ? 5 : 1;
      final totalPoints = basePoints * campaignMultiplier;

      await _gamificationService.awardPoints(
        userId,
        totalPoints,
        reason: '${platform}でシェア${isCampaignActive ? '(キャンペーン中×5)' : ''}',
      );

      // シェア統計を更新
      await _incrementShareCount(userId, platform);

      AppLogger.info('Share bonus awarded: $totalPoints points (campaign: $isCampaignActive)');
    } catch (e, stackTrace) {
      AppLogger.error('Error awarding share bonus', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// バイラル報酬：友達が初回メモ作成時に双方にボーナス
  Future<void> awardViralMilestoneBonus({
    required String referrerId,
    required String referredUserId,
    required String milestone,
  }) async {
    try {
      int bonusPoints = 0;

      switch (milestone) {
        case 'first_note':
          bonusPoints = 50; // 友達が初メモ作成
          break;
        case 'ten_notes':
          bonusPoints = 100; // 友達が10メモ達成
          break;
        case 'active_week':
          bonusPoints = 75; // 友達が1週間連続ログイン
          break;
        default:
          bonusPoints = 25;
      }

      // 紹介者にボーナス
      await _gamificationService.awardPoints(
        referrerId,
        bonusPoints,
        reason: '紹介ユーザーマイルストーン: $milestone',
      );

      // 紹介されたユーザーにもボーナス
      await _gamificationService.awardPoints(
        referredUserId,
        bonusPoints ~/ 2,
        reason: 'マイルストーン達成: $milestone',
      );

      AppLogger.info('Viral milestone bonus awarded: $milestone');
    } catch (e, stackTrace) {
      AppLogger.error('Error awarding viral milestone bonus', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// ソーシャルシェアカウントを追加
  Future<void> _incrementShareCount(String userId, String platform) async {
    try {
      await _supabase.rpc('increment_share_count', params: {
        'p_user_id': userId,
        'p_platform': platform,
      });
    } catch (e) {
      // RPC関数が存在しない場合は無視（後で作成予定）
      AppLogger.warning('increment_share_count RPC not available', error: e);
    }
  }

  /// 招待リンク生成（ユニーク追跡用）
  Future<String> generateInviteLink(String userId) async {
    try {
      // 既存の紹介コードを取得
      final response = await _supabase
          .from('referral_codes')
          .select('referral_code')
          .eq('user_id', userId)
          .maybeSingle();

      String referralCode;
      if (response != null) {
        referralCode = response['referral_code'] as String;
      } else {
        // 新規作成（通常は既に存在するはず）
        referralCode = _generateRandomCode();
        await _supabase.from('referral_codes').insert({
          'user_id': userId,
          'referral_code': referralCode,
        });
      }

      // 招待リンクを生成（実際のドメインに置き換えてください）
      final baseUrl = 'https://my-web-app-b67f4.web.app';
      return '$baseUrl?ref=$referralCode';
    } catch (e, stackTrace) {
      AppLogger.error('Error generating invite link', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (index) => chars[(random + index) % chars.length]).join();
  }

  /// シェア可能なメッセージを生成
  String generateShareMessage({
    required int totalNotes,
    required int currentLevel,
    required int currentStreak,
  }) {
    return '''
🎮 マイメモで楽しくメモ習慣！

📝 ${totalNotes}個のメモを作成
🎯 レベル$currentLevel達成
🔥 ${currentStreak}日連続ログイン中

ゲーム感覚でメモが続けられるよ！
あなたも始めてみませんか？
''';
  }

  /// キャンペーン期間かどうかをチェック
  Future<bool> isShareCampaignActive() async {
    try {
      // campaigns テーブルから現在アクティブなシェアキャンペーンを取得
      final response = await _supabase
          .from('campaigns')
          .select()
          .eq('campaign_type', 'share_boost')
          .eq('is_active', true)
          .gte('end_date', DateTime.now().toIso8601String())
          .lte('start_date', DateTime.now().toIso8601String())
          .maybeSingle();

      return response != null;
    } catch (e) {
      // テーブルが存在しない場合はfalseを返す
      AppLogger.warning('campaigns table not available', error: e);
      return false;
    }
  }

  /// 毎日のシェアチャレンジ報酬（追加インセンティブ）
  Future<void> checkDailyShareChallenge(String userId) async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // 今日既にシェアチャレンジをクリアしているかチェック
      final existing = await _supabase
          .from('daily_share_challenges')
          .select()
          .eq('user_id', userId)
          .eq('challenge_date', todayStr)
          .maybeSingle();

      if (existing == null) {
        // 初回シェアなのでボーナス
        await _gamificationService.awardPoints(
          userId,
          30,
          reason: 'デイリーシェアチャレンジ',
        );

        // 記録
        await _supabase.from('daily_share_challenges').insert({
          'user_id': userId,
          'challenge_date': todayStr,
        });
      }
    } catch (e) {
      // テーブルが存在しない場合は無視
      AppLogger.warning('daily_share_challenges table not available', error: e);
    }
  }
}
