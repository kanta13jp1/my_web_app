/// 相性マッチングモデル
/// MBTI タイプ間の恋愛相性情報を管理
class CompatibilityMatch {
  final String type1;
  final String type2;
  final int compatibilityScore; // 0-100
  final String compatibilityLevel; // 'excellent', 'good', 'fair', 'challenging'
  final String title;
  final String description;
  final List<String> strengths;
  final List<String> challenges;
  final List<String> tips;

  CompatibilityMatch({
    required this.type1,
    required this.type2,
    required this.compatibilityScore,
    required this.compatibilityLevel,
    required this.title,
    required this.description,
    required this.strengths,
    required this.challenges,
    required this.tips,
  });

  factory CompatibilityMatch.fromJson(Map<String, dynamic> json) {
    return CompatibilityMatch(
      type1: json['type1'] as String,
      type2: json['type2'] as String,
      compatibilityScore: json['compatibility_score'] as int,
      compatibilityLevel: json['compatibility_level'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      strengths: (json['strengths'] as List<dynamic>).cast<String>(),
      challenges: (json['challenges'] as List<dynamic>).cast<String>(),
      tips: (json['tips'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type1': type1,
      'type2': type2,
      'compatibility_score': compatibilityScore,
      'compatibility_level': compatibilityLevel,
      'title': title,
      'description': description,
      'strengths': strengths,
      'challenges': challenges,
      'tips': tips,
    };
  }

  /// 相性レベルに基づく色を取得
  String getCompatibilityColor() {
    switch (compatibilityLevel) {
      case 'excellent':
        return '#FF4081'; // ピンク
      case 'good':
        return '#4CAF50'; // グリーン
      case 'fair':
        return '#FFC107'; // イエロー
      case 'challenging':
        return '#9E9E9E'; // グレー
      default:
        return '#9E9E9E';
    }
  }

  /// 相性レベルの日本語表示
  String getCompatibilityLevelJa() {
    switch (compatibilityLevel) {
      case 'excellent':
        return '最高の相性';
      case 'good':
        return '良い相性';
      case 'fair':
        return 'まずまずの相性';
      case 'challenging':
        return 'チャレンジングな相性';
      default:
        return '不明';
    }
  }

  /// 相性レベルの絵文字
  String getCompatibilityEmoji() {
    switch (compatibilityLevel) {
      case 'excellent':
        return '💖';
      case 'good':
        return '💕';
      case 'fair':
        return '💛';
      case 'challenging':
        return '💪';
      default:
        return '❓';
    }
  }
}

/// ユーザー間の相性結果
class UserCompatibilityResult {
  final String userId1;
  final String userId2;
  final String? displayName1;
  final String? displayName2;
  final String? avatarUrl1;
  final String? avatarUrl2;
  final String personalityType1;
  final String personalityType2;
  final CompatibilityMatch compatibilityMatch;
  final DateTime calculatedAt;

  UserCompatibilityResult({
    required this.userId1,
    required this.userId2,
    this.displayName1,
    this.displayName2,
    this.avatarUrl1,
    this.avatarUrl2,
    required this.personalityType1,
    required this.personalityType2,
    required this.compatibilityMatch,
    required this.calculatedAt,
  });
}
