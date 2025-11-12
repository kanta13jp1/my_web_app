import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/compatibility_match.dart';

/// MBTI恋愛相性診断サービス
class CompatibilityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 2つのMBTIタイプの相性を計算
  CompatibilityMatch calculateCompatibility(String type1, String type2) {
    // タイプを正規化（大文字に統一）
    type1 = type1.toUpperCase();
    type2 = type2.toUpperCase();

    // 相性スコアを計算
    int score = _calculateCompatibilityScore(type1, type2);

    // 相性レベルを判定
    String level = _getCompatibilityLevel(score);

    // 相性の詳細情報を生成
    Map<String, dynamic> details = _getCompatibilityDetails(type1, type2, score);

    return CompatibilityMatch(
      type1: type1,
      type2: type2,
      compatibilityScore: score,
      compatibilityLevel: level,
      title: details['title'],
      description: details['description'],
      strengths: details['strengths'],
      challenges: details['challenges'],
      tips: details['tips'],
    );
  }

  /// 相性スコアを計算（0-100）
  int _calculateCompatibilityScore(String type1, String type2) {
    // ベーススコア
    int score = 50;

    // 各軸の相性を評価
    // E/I軸
    if (type1[0] == type2[0]) {
      score += 5; // 同じエネルギー方向
    } else {
      score += 15; // 補完的（外向と内向は引き合う）
    }

    // N/S軸
    if (type1[1] == type2[1]) {
      score += 20; // 同じ情報収集方法（非常に重要）
    } else {
      score -= 10; // 異なる情報収集方法は誤解を生む
    }

    // T/F軸
    if (type1[2] == type2[2]) {
      score += 10; // 同じ意思決定方法
    } else {
      score += 8; // 補完的（思考と感情のバランス）
    }

    // J/P軸
    if (type1[3] == type2[3]) {
      score += 5; // 同じライフスタイル
    } else {
      score += 12; // 補完的（計画性と柔軟性のバランス）
    }

    // 特別な高相性ペア（ゴールデンペア）
    List<List<String>> goldenPairs = [
      ['INTJ', 'ENFP'], ['ENFP', 'INTJ'],
      ['INFJ', 'ENTP'], ['ENTP', 'INFJ'],
      ['INTP', 'ENTJ'], ['ENTJ', 'INTP'],
      ['INFP', 'ENFJ'], ['ENFJ', 'INFP'],
      ['ISTJ', 'ESTP'], ['ESTP', 'ISTJ'],
      ['ISFJ', 'ESFP'], ['ESFP', 'ISFJ'],
      ['ESTJ', 'ISTP'], ['ISTP', 'ESTJ'],
      ['ESFJ', 'ISFP'], ['ISFP', 'ESFJ'],
    ];

    if (goldenPairs.any((pair) => pair[0] == type1 && pair[1] == type2)) {
      score += 20; // ゴールデンペアボーナス
    }

    // 同じタイプ
    if (type1 == type2) {
      score = 75; // 理解し合えるが、成長のチャレンジが少ない
    }

    // スコアを0-100の範囲に制限
    return score.clamp(0, 100);
  }

  /// 相性レベルを判定
  String _getCompatibilityLevel(int score) {
    if (score >= 85) return 'excellent';
    if (score >= 70) return 'good';
    if (score >= 55) return 'fair';
    return 'challenging';
  }

  /// 相性の詳細情報を生成
  Map<String, dynamic> _getCompatibilityDetails(
      String type1, String type2, int score) {
    // タイプの組み合わせに基づいた詳細を生成
    bool sameEI = type1[0] == type2[0];
    bool sameNS = type1[1] == type2[1];
    bool sameTF = type1[2] == type2[2];
    bool sameJP = type1[3] == type2[3];

    String title = _getCompatibilityTitle(type1, type2);
    String description = _getCompatibilityDescription(type1, type2, score);
    List<String> strengths = _getCompatibilityStrengths(
        type1, type2, sameEI, sameNS, sameTF, sameJP);
    List<String> challenges = _getCompatibilityChallenges(
        type1, type2, sameEI, sameNS, sameTF, sameJP);
    List<String> tips = _getCompatibilityTips(
        type1, type2, sameEI, sameNS, sameTF, sameJP);

    return {
      'title': title,
      'description': description,
      'strengths': strengths,
      'challenges': challenges,
      'tips': tips,
    };
  }

  /// 相性タイトルを生成
  String _getCompatibilityTitle(String type1, String type2) {
    if (type1 == type2) {
      return '鏡のような関係';
    }

    // ゴールデンペアのタイトル
    Map<String, Map<String, String>> specialTitles = {
      'INTJ': {'ENFP': '戦略家と夢想家', 'ENTP': '建築家と発明家'},
      'INFJ': {'ENTP': '提唱者と討論者', 'ENFP': '理想主義者の共鳴'},
      'INTP': {'ENTJ': '論理学者と指揮官', 'ENFJ': '思想家と教育者'},
      'INFP': {'ENFJ': '仲介者と主人公', 'ENTJ': '理想と実現'},
      'ISTJ': {'ESTP': '管理者と起業家', 'ESFP': '堅実と自由奔放'},
      'ISFJ': {'ESFP': '擁護者とエンターテイナー', 'ESTP': '守護者と冒険家'},
      'ESTJ': {'ISTP': '幹部と巨匠', 'ISFP': '指導者と芸術家'},
      'ESFJ': {'ISFP': '領事と冒険家', 'ISTP': '社交家と職人'},
    };

    if (specialTitles.containsKey(type1) &&
        specialTitles[type1]!.containsKey(type2)) {
      return specialTitles[type1]![type2]!;
    }

    // デフォルトタイトル
    return '$type1 × $type2 の相性';
  }

  /// 相性の説明を生成
  String _getCompatibilityDescription(String type1, String type2, int score) {
    if (score >= 85) {
      return 'お二人は素晴らしい相性です！お互いの違いが魅力となり、成長し合える関係を築けるでしょう。相手の長所を認め合い、短所を補い合うことができる理想的なパートナーシップです。';
    } else if (score >= 70) {
      return 'お二人は良い相性です。共通点も多く、お互いを理解し合える関係です。違いを尊重し合うことで、より深い絆を築くことができるでしょう。';
    } else if (score >= 55) {
      return 'お二人はまずまずの相性です。違いから学び合い、成長できる可能性があります。相手の価値観を理解し、コミュニケーションを大切にすることが重要です。';
    } else {
      return 'お二人はチャレンジングな相性です。価値観や考え方に大きな違いがありますが、それを乗り越えることで強い絆を築けます。お互いの違いを受け入れ、歩み寄る努力が必要です。';
    }
  }

  /// 相性の強みを生成
  List<String> _getCompatibilityStrengths(String type1, String type2,
      bool sameEI, bool sameNS, bool sameTF, bool sameJP) {
    List<String> strengths = [];

    if (!sameEI) {
      strengths.add('外向性と内向性のバランスが良い');
      strengths.add('社交面と内省面で補完し合える');
    } else if (type1[0] == 'E') {
      strengths.add('共にアクティブで社交的な関係');
    } else {
      strengths.add('深い対話と静かな時間を楽しめる');
    }

    if (sameNS) {
      strengths.add('同じ視点で世界を見ることができる');
      strengths.add('会話が弾み、理解し合いやすい');
    }

    if (sameTF) {
      strengths.add('意思決定のアプローチが似ている');
    } else {
      strengths.add('論理と感情のバランスが取れる');
      strengths.add('異なる視点で問題解決できる');
    }

    if (!sameJP) {
      strengths.add('計画性と柔軟性のバランスが良い');
      strengths.add('ライフスタイルで補完し合える');
    }

    return strengths;
  }

  /// 相性の課題を生成
  List<String> _getCompatibilityChallenges(String type1, String type2,
      bool sameEI, bool sameNS, bool sameTF, bool sameJP) {
    List<String> challenges = [];

    if (!sameNS) {
      challenges.add('情報の受け取り方が異なる');
      challenges.add('具体性と抽象性のギャップ');
    }

    if (!sameTF) {
      challenges.add('意思決定の基準が異なる可能性');
    }

    if (!sameJP) {
      challenges.add('スケジュール管理での衝突');
      challenges.add('計画性と spontaneity のバランス調整');
    }

    if (type1 == type2) {
      challenges.add('似すぎて刺激が少ない可能性');
      challenges.add('同じ弱点を持つ可能性');
    }

    if (challenges.isEmpty) {
      challenges.add('お互いの期待値の調整');
      challenges.add('コミュニケーションスタイルの違い');
    }

    return challenges;
  }

  /// 相性を良くするためのアドバイスを生成
  List<String> _getCompatibilityTips(String type1, String type2, bool sameEI,
      bool sameNS, bool sameTF, bool sameJP) {
    List<String> tips = [];

    if (!sameEI) {
      if (type1[0] == 'E') {
        tips.add('相手の一人の時間を尊重しましょう');
      } else {
        tips.add('社交的な活動も一緒に楽しみましょう');
      }
    }

    if (!sameNS) {
      tips.add('具体的な話と抽象的な話のバランスを取りましょう');
      tips.add('相手の情報処理スタイルを理解しましょう');
    }

    if (!sameTF) {
      tips.add('論理と感情の両面から物事を考えましょう');
      tips.add('相手の意思決定プロセスを尊重しましょう');
    }

    if (!sameJP) {
      tips.add('計画と柔軟性のバランスを見つけましょう');
      tips.add('スケジュールについて事前に話し合いましょう');
    }

    tips.add('お互いの違いを受け入れ、学び合いましょう');
    tips.add('定期的にコミュニケーションの時間を持ちましょう');

    return tips;
  }

  /// データベースから相性データを取得（将来的な拡張用）
  Future<CompatibilityMatch?> getCompatibilityFromDatabase(
      String type1, String type2) async {
    try {
      final response = await _supabase
          .from('personality_compatibility')
          .select()
          .or('type1.eq.$type1,type1.eq.$type2')
          .or('type2.eq.$type2,type2.eq.$type1')
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return CompatibilityMatch.fromJson(response);
    } catch (e) {
      print('Error fetching compatibility from database: $e');
      return null;
    }
  }

  /// 相性データをデータベースに保存（将来的な拡張用）
  Future<void> saveCompatibilityToDatabase(CompatibilityMatch match) async {
    try {
      await _supabase.from('personality_compatibility').upsert(match.toJson());
    } catch (e) {
      print('Error saving compatibility to database: $e');
    }
  }

  /// 指定したタイプと最も相性の良いタイプトップ5を取得
  List<Map<String, dynamic>> getTopCompatibleTypes(String myType) {
    List<Map<String, dynamic>> allTypes = [];

    // 全16タイプとの相性を計算
    const types = [
      'INTJ', 'INTP', 'ENTJ', 'ENTP',
      'INFJ', 'INFP', 'ENFJ', 'ENFP',
      'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
      'ISTP', 'ISFP', 'ESTP', 'ESFP'
    ];

    for (String type in types) {
      if (type != myType) {
        CompatibilityMatch match = calculateCompatibility(myType, type);
        allTypes.add({
          'type': type,
          'score': match.compatibilityScore,
          'level': match.compatibilityLevel,
          'title': match.title,
        });
      }
    }

    // スコアでソート
    allTypes.sort((a, b) => b['score'].compareTo(a['score']));

    // トップ5を返す
    return allTypes.take(5).toList();
  }

  /// 自分のタイプと最も相性の悪いタイプを取得
  List<Map<String, dynamic>> getLeastCompatibleTypes(String myType) {
    List<Map<String, dynamic>> allTypes = [];

    const types = [
      'INTJ', 'INTP', 'ENTJ', 'ENTP',
      'INFJ', 'INFP', 'ENFJ', 'ENFP',
      'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
      'ISTP', 'ISFP', 'ESTP', 'ESFP'
    ];

    for (String type in types) {
      if (type != myType) {
        CompatibilityMatch match = calculateCompatibility(myType, type);
        allTypes.add({
          'type': type,
          'score': match.compatibilityScore,
          'level': match.compatibilityLevel,
        });
      }
    }

    // スコアで昇順ソート
    allTypes.sort((a, b) => a['score'].compareTo(b['score']));

    // ワースト3を返す
    return allTypes.take(3).toList();
  }
}
