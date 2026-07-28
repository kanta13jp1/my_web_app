// IQトレーニングのサービスクラス。
//
// この機能の核: 「テスト結果の数値」→「学習計画」の変換。
// 変換規則は静的メソッドに切り出してあり、Supabase なしで検証できる。
//
// 数値が計画に効く経路は2つ:
//   1. 領域別IQ → 開始レベル (levelForIq)  … 何をどの難度から始めるか
//   2. 総合IQとの差 → 週あたり回数 (weeklySessionsForGap) … どれだけ配分するか
// さらに実施後は正答率でレベルを上下させる (nextLevel)。

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/iq_test.dart';

/// なぜこの領域が学習対象に選ばれたか。
///
/// 「弱点あり」と「弱点なし (均等)」を同じ空リストで表現すると
/// 未評価と区別できなくなるため、理由を明示的に持たせる。
enum IqPlanBasis {
  /// 総合スコアを明確に下回る領域が見つかった。
  weakAreaDetected,

  /// 領域差が小さく、弱点と言える領域がない。相対的な下位を底上げ対象にする。
  balancedProfile,
}

/// DB へ書く前の計画案。
class IqTrainingPlanDraft {
  final IqPlanBasis basis;
  final int baselineIq;
  final List<IqTrainingTarget> targets;

  const IqTrainingPlanDraft({
    required this.basis,
    required this.baselineIq,
    required this.targets,
  });

  String get basisMessageJa {
    switch (basis) {
      case IqPlanBasis.weakAreaDetected:
        return '総合スコアを明確に下回る領域が見つかりました。'
            'そこを重点的に鍛えるのが最も伸びしろが大きい配分です。';
      case IqPlanBasis.balancedProfile:
        return '領域ごとの差が小さく、はっきりした弱点はありません。'
            '相対的に低い領域を底上げしつつ、全体の難度を上げていきます。';
    }
  }
}

class IqTrainingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('IQトレーニングの利用にはログインが必要です');
    }
    return user.id;
  }

  // =====================================================================
  // 純粋ロジック: 数値 → 計画
  // =====================================================================

  /// 領域別IQから開始レベル (1..5) を決める。
  ///
  /// 境界は偏差IQの慣用的な区切り (1SD = 15) に合わせている。
  static int levelForIq(int categoryIq) {
    if (categoryIq >= 130) return 5;
    if (categoryIq >= 115) return 4;
    if (categoryIq >= 100) return 3;
    if (categoryIq >= 85) return 2;
    return 1;
  }

  /// 総合IQとの差から週あたりのセッション数を決める。差が大きいほど多く配分する。
  static int weeklySessionsForGap(int gap) {
    if (gap >= 15) return 5;
    if (gap >= 10) return 4;
    if (gap >= 5) return 3;
    return 2;
  }

  /// セッションの正答率から次回レベルを決める。
  ///
  /// 「少し難しい」帯 (正答率 60〜85%) に留め続けるのが学習効率が高いので、
  /// 上振れしたら上げ、崩れたら下げる。
  static int nextLevel(int currentLevel, double accuracy) {
    if (accuracy >= 0.85) return (currentLevel + 1).clamp(1, 5);
    if (accuracy <= 0.50) return (currentLevel - 1).clamp(1, 5);
    return currentLevel.clamp(1, 5);
  }

  /// テスト結果から学習計画案を作る。
  ///
  /// 弱点領域があればそれを対象にし、なければ相対的な下位2領域を対象にする。
  /// どちらの経路を通ったかは [IqTrainingPlanDraft.basis] で区別できる。
  static IqTrainingPlanDraft buildPlanDraft(
    IqTestResult result, {
    int maxTargets = 3,
  }) {
    final weak = result.weakAreas();
    final basis = weak.isNotEmpty
        ? IqPlanBasis.weakAreaDetected
        : IqPlanBasis.balancedProfile;

    // 弱点がない場合も学習対象は出す (相対的に低い順)。
    final selected = weak.isNotEmpty
        ? weak.take(maxTargets).toList()
        : (List<IqCategoryScore>.from(result.categoryScores)
              ..sort((a, b) => a.iq.compareTo(b.iq)))
            .take(2)
            .toList();

    final targets = selected.map((score) {
      return IqTrainingTarget(
        category: score.category,
        baselineIq: score.iq,
        startLevel: levelForIq(score.iq),
        weeklySessions: weeklySessionsForGap(result.totalIq - score.iq),
      );
    }).toList();

    return IqTrainingPlanDraft(
      basis: basis,
      baselineIq: result.totalIq,
      targets: targets,
    );
  }

  /// 直近セッションの実績から、その領域の現在レベルを求める。
  ///
  /// 計画の開始レベルを起点に、セッションを古い順に適用していく。
  /// 1回のブレで大きく振れないよう、直近 [window] 件だけを見る。
  static int currentLevelFor({
    required IqTrainingTarget target,
    required List<IqTrainingSession> sessions,
    int window = 5,
  }) {
    final relevant = sessions
        .where((s) => s.category == target.category && s.questionCount > 0)
        .toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    if (relevant.isEmpty) return target.startLevel;

    final recent = relevant.length > window
        ? relevant.sublist(relevant.length - window)
        : relevant;

    var level = target.startLevel;
    for (final session in recent) {
      level = nextLevel(level, session.accuracy);
    }
    return level;
  }

  // =====================================================================
  // I/O
  // =====================================================================

  /// テスト結果から計画を作成して保存する。
  ///
  /// 既存の有効な計画は非有効化し、常に「最新のテスト結果に基づく計画が1つ」を保つ。
  Future<IqTrainingPlan> createPlanFromResult(IqTestResult result) async {
    try {
      final draft = buildPlanDraft(result);
      final userId = _userId;

      await _supabase
          .from('iq_training_plans')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('is_active', true);

      final response = await _supabase
          .from('iq_training_plans')
          .insert({
            'user_id': userId,
            'source_test_id': result.id,
            'baseline_iq': draft.baselineIq,
            'targets': [for (final t in draft.targets) t.toJson()],
            'is_active': true,
          })
          .select()
          .single();

      return IqTrainingPlan.fromJson(response);
    } catch (e) {
      debugPrint('Error creating IQ training plan: $e');
      rethrow;
    }
  }

  /// 有効な計画を取得する。なければ null。
  Future<IqTrainingPlan?> getActivePlan() async {
    try {
      final rows = await _supabase
          .from('iq_training_plans')
          .select()
          .eq('user_id', _userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(1);

      if ((rows as List).isEmpty) return null;
      return IqTrainingPlan.fromJson(rows.first);
    } catch (e) {
      debugPrint('Error fetching active IQ training plan: $e');
      rethrow;
    }
  }

  /// 計画に紐づくセッション履歴を取得する。
  Future<List<IqTrainingSession>> getSessions(
    int planId, {
    int limit = 200,
  }) async {
    try {
      final rows = await _supabase
          .from('iq_training_sessions')
          .select()
          .eq('plan_id', planId)
          .order('completed_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((e) => IqTrainingSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching IQ training sessions: $e');
      rethrow;
    }
  }

  /// セッション結果を記録する。
  Future<IqTrainingSession> recordSession({
    required int planId,
    required IqCategory category,
    required int level,
    required int correctCount,
    required int questionCount,
    required int durationSeconds,
  }) async {
    try {
      final response = await _supabase
          .from('iq_training_sessions')
          .insert({
            'plan_id': planId,
            'user_id': _userId,
            'category': category.key,
            'level': level,
            'correct_count': correctCount,
            'question_count': questionCount,
            'duration_seconds': durationSeconds,
            'completed_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return IqTrainingSession.fromJson(response);
    } catch (e) {
      debugPrint('Error recording IQ training session: $e');
      rethrow;
    }
  }

  /// 再テストを勧めるべきか。
  ///
  /// 学習効果の測定には一定量の実施が要る。少ない回数での再テストは
  /// ノイズしか拾わないため、閾値を明示する。
  static bool shouldRetest(List<IqTrainingSession> sessions) {
    return sessions.length >= 12;
  }

  /// 再テストまでに必要な残りセッション数。
  static int sessionsUntilRetest(List<IqTrainingSession> sessions) {
    const required = 12;
    final remaining = required - sessions.length;
    return remaining < 0 ? 0 : remaining;
  }
}
