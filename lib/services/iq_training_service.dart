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
  /// 総合スコアを測定誤差を超えて下回る領域が見つかった。
  weakAreaDetected,

  /// 領域差が測定誤差の範囲内で、弱点を**判別できない**。
  ///
  /// 「差が無い」ではない。5問しかない領域スコアの標準誤差は約 18 IQ あるため、
  /// 見かけの凸凹の多くはノイズで説明がつく。ここを「弱点あり」と言い切ると
  /// 存在しない差に学習時間を割かせることになる。
  withinMeasurementNoise,

  /// 完答率が低く、そもそもスコアを信頼できない。
  lowCompletion,
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
        return '総合スコアを測定誤差より大きく下回る領域が見つかりました。'
            'そこを重点的に鍛えるのが最も伸びしろが大きい配分です。';
      case IqPlanBasis.withinMeasurementNoise:
        return '領域ごとの差は測定誤差 (1領域あたり5問・誤差およそ±18) の範囲内で、'
            'どこが弱点かを判別できません。'
            '見かけ上いちばん低い領域から始めますが、これは暫定です。'
            'トレーニングを重ねるほど実際の得意不得意がはっきりします。';
      case IqPlanBasis.lowCompletion:
        return '未回答が多く、スコアそのものを信頼できません。'
            'まずは最後まで解ける状態で受け直すことをおすすめします。'
            '暫定として見かけ上低い領域を対象にしています。';
    }
  }

  /// この計画が確かな測定にもとづくか。UI は暫定であることを隠さない。
  bool get isProvisional => basis != IqPlanBasis.weakAreaDetected;
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
    final IqPlanBasis basis;
    if (!result.isReliable) {
      // 完答率が低い回は、弱点らしき差が出ていてもそれは未回答の影。
      basis = IqPlanBasis.lowCompletion;
    } else if (weak.isNotEmpty) {
      basis = IqPlanBasis.weakAreaDetected;
    } else {
      basis = IqPlanBasis.withinMeasurementNoise;
    }

    // 弱点を判別できない場合も学習対象は出す (見かけ上低い順)。
    // ただし basis が weakAreaDetected でないことで暫定だと分かるようにする。
    final selected = basis == IqPlanBasis.weakAreaDetected
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
  /// **直近 [window] 件を合算した正答率で1回だけ判定する。**
  /// 旧実装はセッションごとに [nextLevel] を逐次適用しており、8問しかない
  /// 1セッションのばらつきがそのままレベルの上下に化けていた
  /// (真の実力 0.70 でも 44.9% の確率で誤ってレベルが動く実測)。
  /// 合算すれば標本数が window 倍になり、同じ実力での誤判定が大きく減る。
  ///
  /// レベルが変わるのは1段ずつ。合算値が大きく外れていても一気に飛ばさない。
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

    // 直近ウィンドウで実際に出題されたレベルを基準にする。
    // 開始レベルを毎回の起点にすると、実績で上げた分が次回リセットされる。
    final baseLevel = relevant.last.level;

    // **同じレベルで解いた試行だけを合算する。**
    // レベル1の満点とレベル5の全滅を平均すると 0.5 になり、
    // 「どちらの難易度も適正」という誤った結論が出る (実際はどちらも不適正)。
    // 難易度が違う試行は別の母集団なので混ぜてはいけない。
    final sameLevel = relevant.where((s) => s.level == baseLevel).toList();
    final recent = sameLevel.length > window
        ? sameLevel.sublist(sameLevel.length - window)
        : sameLevel;

    var correct = 0;
    var total = 0;
    for (final session in recent) {
      correct += session.correctCount;
      total += session.questionCount;
    }

    // **標本が足りないうちはレベルを動かさない。**
    // 合算方式の狙いは標本を増やすことなのに、最小標本を課さないと
    // 1セッション8問で昇格してしまい、逐次適用と同じノイズに戻る。
    if (total < minQuestionsForLevelChange) return baseLevel;

    return nextLevel(baseLevel, correct / total);
  }

  /// レベルを動かすのに必要な最小試行数 (同一レベルでの合算)。
  ///
  /// 8問 × 3セッション。真の実力 0.70 での誤判定率が実用域に収まる下限。
  static const int minQuestionsForLevelChange = 24;

  /// 判定に使えるだけの試行数が溜まっているか。
  ///
  /// UI が「あと何回で難度が見直されるか」を出すために使う。
  static bool hasEnoughEvidenceForLevelChange(
    List<IqTrainingSession> sessions,
    IqCategory category, {
    int? minQuestions,
  }) {
    final threshold = minQuestions ?? minQuestionsForLevelChange;
    final total = sessions
        .where((s) => s.category == category)
        .fold<int>(0, (sum, s) => sum + s.questionCount);
    return total >= threshold;
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
