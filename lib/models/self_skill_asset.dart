/// スキル評価の由来（自己申告と実証・実績記録を混同しないための区分）(#1392 / #2770)。
enum SkillAssessmentOrigin {
  selfDeclared,
  verifiedRecord,
}

extension SkillAssessmentOriginLabel on SkillAssessmentOrigin {
  String get label {
    switch (this) {
      case SkillAssessmentOrigin.selfDeclared:
        return '自己申告';
      case SkillAssessmentOrigin.verifiedRecord:
        return '実績・資格確認';
    }
  }
}

/// ユーザーが保有する「人的・スキル資産」1件のモデル (#1392 / #2770)。
class SelfSkillAsset {
  const SelfSkillAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.proficiencyLevel,
    this.experienceYears = 0,
    this.origin = SkillAssessmentOrigin.selfDeclared,
    this.note = '',
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final int proficiencyLevel;
  final double experienceYears;
  final SkillAssessmentOrigin origin;
  final String note;
  final DateTime updatedAt;

  SelfSkillAsset copyWith({
    String? id,
    String? name,
    String? category,
    int? proficiencyLevel,
    double? experienceYears,
    SkillAssessmentOrigin? origin,
    String? note,
    DateTime? updatedAt,
  }) {
    return SelfSkillAsset(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      proficiencyLevel: proficiencyLevel ?? this.proficiencyLevel,
      experienceYears: experienceYears ?? this.experienceYears,
      origin: origin ?? this.origin,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'proficiencyLevel': proficiencyLevel,
      'experienceYears': experienceYears,
      'origin': origin.name,
      'note': note,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static SelfSkillAsset? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final category = json['category']?.toString().trim() ?? '';
    final levelRaw = json['proficiencyLevel'];
    final level = levelRaw is num
        ? levelRaw.toInt()
        : int.tryParse(levelRaw?.toString() ?? '');
    if (id.isEmpty || name.isEmpty || level == null || level < 1 || level > 5) {
      return null;
    }
    final expRaw = json['experienceYears'];
    final exp = expRaw is num
        ? expRaw.toDouble()
        : double.tryParse(expRaw?.toString() ?? '') ?? 0.0;
    final originName = json['origin']?.toString() ?? '';
    final origin = SkillAssessmentOrigin.values.firstWhere(
      (v) => v.name == originName,
      orElse: () => SkillAssessmentOrigin.selfDeclared,
    );
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime(2026, 1, 1);
    return SelfSkillAsset(
      id: id,
      name: name,
      category: category.isEmpty ? 'その他' : category,
      proficiencyLevel: level,
      experienceYears: exp < 0 ? 0.0 : exp,
      origin: origin,
      note: json['note']?.toString().trim() ?? '',
      updatedAt: updatedAt,
    );
  }
}

/// 今後獲得したいスキル（新規事業への投資計画）1件のモデル (#1392 / #2770)。
class SelfSkillTarget {
  const SelfSkillTarget({
    required this.id,
    required this.skillName,
    required this.category,
    required this.targetLevel,
    required this.currentProgressPercent,
    required this.targetPeriod,
    this.investmentNote = '',
    required this.createdAt,
  });

  final String id;
  final String skillName;
  final String category;
  final int targetLevel;
  final int currentProgressPercent;
  final String targetPeriod;
  final String investmentNote;
  final DateTime createdAt;

  SelfSkillTarget copyWith({
    String? id,
    String? skillName,
    String? category,
    int? targetLevel,
    int? currentProgressPercent,
    String? targetPeriod,
    String? investmentNote,
    DateTime? createdAt,
  }) {
    return SelfSkillTarget(
      id: id ?? this.id,
      skillName: skillName ?? this.skillName,
      category: category ?? this.category,
      targetLevel: targetLevel ?? this.targetLevel,
      currentProgressPercent:
          currentProgressPercent ?? this.currentProgressPercent,
      targetPeriod: targetPeriod ?? this.targetPeriod,
      investmentNote: investmentNote ?? this.investmentNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'skillName': skillName,
      'category': category,
      'targetLevel': targetLevel,
      'currentProgressPercent': currentProgressPercent,
      'targetPeriod': targetPeriod,
      'investmentNote': investmentNote,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static SelfSkillTarget? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final skillName = json['skillName']?.toString().trim() ?? '';
    final targetPeriod = json['targetPeriod']?.toString().trim() ?? '';
    final targetLevelRaw = json['targetLevel'];
    final targetLevel = targetLevelRaw is num
        ? targetLevelRaw.toInt()
        : int.tryParse(targetLevelRaw?.toString() ?? '');
    final progressRaw = json['currentProgressPercent'];
    final progress = progressRaw is num
        ? progressRaw.toInt()
        : int.tryParse(progressRaw?.toString() ?? '') ?? 0;
    if (id.isEmpty ||
        skillName.isEmpty ||
        targetPeriod.isEmpty ||
        targetLevel == null ||
        targetLevel < 1 ||
        targetLevel > 5) {
      return null;
    }
    return SelfSkillTarget(
      id: id,
      skillName: skillName,
      category: (json['category']?.toString().trim() ?? '').isEmpty
          ? '技術'
          : json['category'].toString().trim(),
      targetLevel: targetLevel,
      currentProgressPercent: progress.clamp(0, 100),
      targetPeriod: targetPeriod,
      investmentNote: json['investmentNote']?.toString().trim() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime(2026, 1, 1),
    );
  }
}

/// レーダーチャート用のカテゴリ/スキル軸ポイント。
class SelfSkillRadarAxisPoint {
  const SelfSkillRadarAxisPoint({
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String label;
  final double value;
  final double maxValue;

  double get normalized =>
      maxValue <= 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
}

/// スキル資産ポートフォリオ全体の状態スナップショット。
class SelfSkillPortfolioData {
  const SelfSkillPortfolioData({
    this.skills = const <SelfSkillAsset>[],
    this.targets = const <SelfSkillTarget>[],
  });

  final List<SelfSkillAsset> skills;
  final List<SelfSkillTarget> targets;
}

/// スキル資産ポートフォリオの決定論的集計サマリ。
class SelfSkillPortfolioSummary {
  const SelfSkillPortfolioSummary({
    required this.totalSkills,
    required this.verifiedSkillsCount,
    required this.selfDeclaredSkillsCount,
    required this.averageProficiency,
    required this.totalTargets,
    required this.averageTargetProgress,
    required this.radarAxes,
  });

  final int totalSkills;
  final int verifiedSkillsCount;
  final int selfDeclaredSkillsCount;
  final double averageProficiency;
  final int totalTargets;
  final double averageTargetProgress;
  final List<SelfSkillRadarAxisPoint> radarAxes;
}
