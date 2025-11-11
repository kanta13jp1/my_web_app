// 性格診断機能のサービスクラス

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/personality_test.dart';

class PersonalityTestService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 診断を開始
  Future<PersonalityTest> startTest() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase.from('personality_tests').insert({
        'user_id': userId,
        'started_at': DateTime.now().toIso8601String(),
        'is_completed': false,
      }).select().single();

      return PersonalityTest.fromJson(response);
    } catch (e) {
      print('Error starting personality test: $e');
      rethrow;
    }
  }

  /// 質問を取得
  Future<List<PersonalityQuestion>> getQuestions() async {
    try {
      final response = await _supabase
          .from('personality_questions')
          .select()
          .order('order_num', ascending: true);

      return (response as List)
          .map((e) => PersonalityQuestion.fromJson(e))
          .toList();
    } catch (e) {
      print('Error fetching personality questions: $e');
      rethrow;
    }
  }

  /// 回答を保存
  Future<void> saveAnswer({
    required int testId,
    required int questionId,
    required String answer,
  }) async {
    try {
      await _supabase.from('personality_answers').upsert({
        'test_id': testId,
        'question_id': questionId,
        'answer': answer,
        'answered_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving personality answer: $e');
      rethrow;
    }
  }

  /// スコアを計算
  Future<Map<String, int>> calculateScores(int testId) async {
    try {
      // 回答を取得
      final answersResponse = await _supabase
          .from('personality_answers')
          .select('*, personality_questions!inner(*)')
          .eq('test_id', testId);

      final answers = answersResponse as List;

      // 各軸のスコアを計算
      final scores = <String, int>{
        'E/I': 0,
        'N/S': 0,
        'T/F': 0,
        'J/P': 0,
        'A/T': 0,
      };

      for (var answer in answers) {
        final question = answer['personality_questions'];
        final axis = question['axis'] as String;
        final userAnswer = answer['answer'] as String;

        // スコア加算（Aなら+1、Bなら-1）
        final score = (userAnswer == 'A') ? 1 : -1;
        scores[axis] = (scores[axis] ?? 0) + score;
      }

      // スコアを保存
      for (var entry in scores.entries) {
        await _supabase.from('personality_scores').upsert({
          'test_id': testId,
          'axis': entry.key,
          'score': entry.value,
        });
      }

      return scores;
    } catch (e) {
      print('Error calculating personality scores: $e');
      rethrow;
    }
  }

  /// 性格タイプを判定
  String determinePersonalityType(Map<String, int> scores) {
    String type = '';

    // E vs I
    type += (scores['E/I']! > 0) ? 'E' : 'I';

    // N vs S
    type += (scores['N/S']! > 0) ? 'N' : 'S';

    // T vs F
    type += (scores['T/F']! > 0) ? 'T' : 'F';

    // J vs P
    type += (scores['J/P']! > 0) ? 'J' : 'P';

    return type;
  }

  /// 診断を完了
  Future<void> completeTest(int testId, String personalityType) async {
    try {
      await _supabase.from('personality_tests').update({
        'personality_type': personalityType,
        'completed_at': DateTime.now().toIso8601String(),
        'is_completed': true,
      }).eq('id', testId);
    } catch (e) {
      print('Error completing personality test: $e');
      rethrow;
    }
  }

  /// 診断結果を取得
  Future<PersonalityTest> getTestResult(int testId) async {
    try {
      final response = await _supabase
          .from('personality_tests')
          .select()
          .eq('id', testId)
          .single();

      return PersonalityTest.fromJson(response);
    } catch (e) {
      print('Error fetching test result: $e');
      rethrow;
    }
  }

  /// ユーザーの最新診断結果を取得
  Future<PersonalityTest?> getLatestTestResult() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('personality_tests')
          .select()
          .eq('user_id', userId)
          .eq('is_completed', true)
          .order('completed_at', ascending: false)
          .limit(1);

      if (response.isEmpty) return null;

      return PersonalityTest.fromJson(response.first);
    } catch (e) {
      print('Error fetching latest test result: $e');
      rethrow;
    }
  }

  /// 性格タイプの詳細情報を取得
  PersonalityType getPersonalityTypeDetails(String code) {
    // 16タイプの詳細データ（ハードコード）
    final types = _getPersonalityTypes();
    return types.firstWhere(
      (type) => type.code == code,
      orElse: () => types.first,
    );
  }

  /// 16タイプの詳細データ
  List<PersonalityType> _getPersonalityTypes() {
    return [
      PersonalityType(
        code: 'INTJ',
        nameJa: '建築家',
        nameEn: 'Architect',
        description: '戦略的な思考家。論理的で完璧主義。長期的な計画を立てて実行する能力に優れています。',
        strengths: ['戦略的思考', '論理的分析', '長期計画', '独立性', '集中力'],
        weaknesses: ['感情表現が苦手', '頑固', '批判的', '社交性が低い'],
        noteAdvice: [
          '体系的な構造を作りましょう',
          'カテゴリ分けを活用しましょう',
          '目標設定メモを書きましょう',
          '長期計画をビジュアル化しましょう',
        ],
        iconUrl: 'assets/personality_icons/intj.png',
      ),
      PersonalityType(
        code: 'INTP',
        nameJa: '論理学者',
        nameEn: 'Logician',
        description: '分析的で好奇心旺盛。複雑な問題を解決することが好きで、常に新しい知識を求めています。',
        strengths: ['分析力', '論理的思考', '創造性', '柔軟性', '独立性'],
        weaknesses: ['計画性が低い', '社交性が低い', '完璧主義', '感情表現が苦手'],
        noteAdvice: [
          'アイデアメモを自由に書きましょう',
          '理論や概念を整理しましょう',
          '疑問や仮説を記録しましょう',
          '学習ノートを作りましょう',
        ],
        iconUrl: 'assets/personality_icons/intp.png',
      ),
      PersonalityType(
        code: 'ENTJ',
        nameJa: '指揮官',
        nameEn: 'Commander',
        description: 'リーダーシップに優れ、効率的で決断力があります。目標達成に向けて周囲を導く能力を持っています。',
        strengths: ['リーダーシップ', '効率性', '決断力', '戦略的思考', '自信'],
        weaknesses: ['頑固', '感情に鈍感', '批判的', '忍耐力が低い'],
        noteAdvice: [
          'タスク管理を徹底しましょう',
          'チーム目標を明確にしましょう',
          '優先順位をつけましょう',
          'デリゲーションメモを作りましょう',
        ],
        iconUrl: 'assets/personality_icons/entj.png',
      ),
      PersonalityType(
        code: 'ENTP',
        nameJa: '討論者',
        nameEn: 'Debater',
        description: '革新的で議論好き。新しいアイデアや挑戦を楽しみ、知的な刺激を求めています。',
        strengths: ['創造性', '柔軟性', '分析力', 'コミュニケーション', '適応力'],
        weaknesses: ['計画性が低い', '気が散りやすい', '議論好き', '感情に鈍感'],
        noteAdvice: [
          'ブレインストーミングメモを活用しましょう',
          '議論の記録を残しましょう',
          '複数のアイデアを並行して管理しましょう',
          '思考の流れを記録しましょう',
        ],
        iconUrl: 'assets/personality_icons/entp.png',
      ),
      PersonalityType(
        code: 'INFJ',
        nameJa: '提唱者',
        nameEn: 'Advocate',
        description: '理想主義で共感力が高い。深い洞察力を持ち、人々を理解し支援することに情熱を注ぎます。',
        strengths: ['共感力', '洞察力', '理想主義', '創造性', '献身性'],
        weaknesses: ['完璧主義', '敏感', '燃え尽き', '批判を受けやすい'],
        noteAdvice: [
          '感情や直感を記録しましょう',
          '価値観を明確にしましょう',
          '人間関係の気づきを書きましょう',
          '理想と現実のバランスを取りましょう',
        ],
        iconUrl: 'assets/personality_icons/infj.png',
      ),
      PersonalityType(
        code: 'INFP',
        nameJa: '仲介者',
        nameEn: 'Mediator',
        description: '創造的で理想主義。価値観を大切にし、柔軟で適応力があります。',
        strengths: ['創造性', '共感力', '柔軟性', '理想主義', '献身性'],
        weaknesses: ['非現実的', '敏感', '優柔不断', '計画性が低い'],
        noteAdvice: [
          '感情日記を書きましょう',
          '創作メモを自由に書きましょう',
          '価値観を探求しましょう',
          '夢や理想を記録しましょう',
        ],
        iconUrl: 'assets/personality_icons/infp.png',
      ),
      PersonalityType(
        code: 'ENFJ',
        nameJa: '主人公',
        nameEn: 'Protagonist',
        description: 'カリスマ性があり、共感力が高い。リーダーシップを発揮し、人々を鼓舞する能力を持っています。',
        strengths: ['カリスマ', '共感力', 'リーダーシップ', 'コミュニケーション', '献身性'],
        weaknesses: ['自己犠牲', '敏感', '理想主義', '批判を受けやすい'],
        noteAdvice: [
          'チームの目標を共有しましょう',
          '人々の成長を記録しましょう',
          'モチベーションメモを作りましょう',
          'フィードバックを整理しましょう',
        ],
        iconUrl: 'assets/personality_icons/enfj.png',
      ),
      PersonalityType(
        code: 'ENFP',
        nameJa: '広報運動家',
        nameEn: 'Campaigner',
        description: '熱心で創造的、社交的。新しい可能性を探求し、人々とつながることを楽しみます。',
        strengths: ['創造性', '熱意', '社交性', '柔軟性', 'コミュニケーション'],
        weaknesses: ['計画性が低い', '気が散りやすい', '敏感', '完璧主義'],
        noteAdvice: [
          'アイデアを自由に書きましょう',
          '人とのつながりを記録しましょう',
          'インスピレーションメモを作りましょう',
          '複数のプロジェクトを管理しましょう',
        ],
        iconUrl: 'assets/personality_icons/enfp.png',
      ),
      PersonalityType(
        code: 'ISTJ',
        nameJa: '管理者',
        nameEn: 'Logistician',
        description: '実直で責任感が強い。秩序を重視し、計画的に物事を進めることを好みます。',
        strengths: ['責任感', '計画性', '実直', '秩序', '信頼性'],
        weaknesses: ['柔軟性が低い', '変化を嫌う', '感情表現が苦手', '新しいことに消極的'],
        noteAdvice: [
          'チェックリストを活用しましょう',
          '詳細な計画を立てましょう',
          '記録を正確に残しましょう',
          'ルーティンを確立しましょう',
        ],
        iconUrl: 'assets/personality_icons/istj.png',
      ),
      PersonalityType(
        code: 'ISFJ',
        nameJa: '擁護者',
        nameEn: 'Defender',
        description: '献身的で思いやりがあり、実用的。人々を支え、守ることに喜びを感じます。',
        strengths: ['献身性', '思いやり', '実用性', '責任感', '忠実'],
        weaknesses: ['自己主張が苦手', '変化を嫌う', '自己犠牲', '批判を受けやすい'],
        noteAdvice: [
          '他者への配慮を記録しましょう',
          '実用的なTipsを集めましょう',
          '感謝の記録を残しましょう',
          'ルーティンを大切にしましょう',
        ],
        iconUrl: 'assets/personality_icons/isfj.png',
      ),
      PersonalityType(
        code: 'ESTJ',
        nameJa: '幹部',
        nameEn: 'Executive',
        description: '組織的で実用的、伝統を重視。リーダーシップを発揮し、効率的に物事を管理します。',
        strengths: ['組織力', '実用性', 'リーダーシップ', '決断力', '責任感'],
        weaknesses: ['柔軟性が低い', '感情に鈍感', '頑固', '批判的'],
        noteAdvice: [
          'プロジェクト管理を徹底しましょう',
          'タスクを明確にしましょう',
          '進捗を定期的に記録しましょう',
          'チェックリストを活用しましょう',
        ],
        iconUrl: 'assets/personality_icons/estj.png',
      ),
      PersonalityType(
        code: 'ESFJ',
        nameJa: '領事',
        nameEn: 'Consul',
        description: '社交的で協力的、責任感が強い。人々の調和を重視し、支援することを好みます。',
        strengths: ['社交性', '協力性', '責任感', '思いやり', '組織力'],
        weaknesses: ['批判を受けやすい', '変化を嫌う', '自己犠牲', '柔軟性が低い'],
        noteAdvice: [
          '人間関係の記録を残しましょう',
          'イベント計画を立てましょう',
          '感謝の気持ちを書きましょう',
          'チームの調和を大切にしましょう',
        ],
        iconUrl: 'assets/personality_icons/esfj.png',
      ),
      PersonalityType(
        code: 'ISTP',
        nameJa: '巨匠',
        nameEn: 'Virtuoso',
        description: '実践的で柔軟、分析的。問題解決と実験を楽しみ、独立して行動します。',
        strengths: ['実践力', '柔軟性', '分析力', '独立性', '冷静'],
        weaknesses: ['計画性が低い', '感情表現が苦手', '衝動的', '退屈しやすい'],
        noteAdvice: [
          '実験や試行錯誤を記録しましょう',
          '問題解決の手順を残しましょう',
          '学んだスキルをメモしましょう',
          '柔軟に調整できるメモを作りましょう',
        ],
        iconUrl: 'assets/personality_icons/istp.png',
      ),
      PersonalityType(
        code: 'ISFP',
        nameJa: '冒険家',
        nameEn: 'Adventurer',
        description: '芸術的で柔軟、思いやりがある。美しさや調和を大切にし、自分らしく生きることを好みます。',
        strengths: ['創造性', '柔軟性', '思いやり', '芸術性', '適応力'],
        weaknesses: ['計画性が低い', '自己主張が苦手', '敏感', '批判を受けやすい'],
        noteAdvice: [
          '感性や美しさを記録しましょう',
          '創作メモを自由に書きましょう',
          '瞬間の気持ちを大切にしましょう',
          'ビジュアルメモを活用しましょう',
        ],
        iconUrl: 'assets/personality_icons/isfp.png',
      ),
      PersonalityType(
        code: 'ESTP',
        nameJa: '起業家',
        nameEn: 'Entrepreneur',
        description: '行動的で現実的、社交的。リスクを恐れず、その場の状況に素早く対応します。',
        strengths: ['行動力', '適応力', '社交性', '現実的', '柔軟性'],
        weaknesses: ['計画性が低い', '衝動的', '長期的視点が弱い', '退屈しやすい'],
        noteAdvice: [
          'アクションプランを立てましょう',
          '即座の気づきを記録しましょう',
          '短期目標を設定しましょう',
          '柔軟に更新できるメモを作りましょう',
        ],
        iconUrl: 'assets/personality_icons/estp.png',
      ),
      PersonalityType(
        code: 'ESFP',
        nameJa: 'エンターテイナー',
        nameEn: 'Entertainer',
        description: '陽気で社交的、柔軟。人々を楽しませ、今を楽しむことを大切にします。',
        strengths: ['社交性', '陽気', '柔軟性', '適応力', '共感力'],
        weaknesses: ['計画性が低い', '敏感', '批判を受けやすい', '長期的視点が弱い'],
        noteAdvice: [
          '楽しかった思い出を記録しましょう',
          '人とのつながりを大切にしましょう',
          '今を楽しむメモを書きましょう',
          'ポジティブな記録を残しましょう',
        ],
        iconUrl: 'assets/personality_icons/esfp.png',
      ),
    ];
  }
}
