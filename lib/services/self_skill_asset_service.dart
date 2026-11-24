import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/self_skill_asset.dart';

/// スキル資産ポートフォリオデータの永続化抽象 (#1392 / #2770)。
abstract class SelfSkillAssetStorage {
  Future<SelfSkillPortfolioData> load();
  Future<void> save(SelfSkillPortfolioData data);
}

/// SharedPreferences を用いたユーザー別キー分離ストレージ。
class SharedPreferencesSelfSkillAssetStorage implements SelfSkillAssetStorage {
  SharedPreferencesSelfSkillAssetStorage({
    this.userScope = 'local',
    this.onRemoteSync,
  });

  final String userScope;
  final Future<void> Function(SelfSkillPortfolioData data)? onRemoteSync;

  String get _prefsKey => 'self_skill_asset_portfolio_v1_$userScope';

  @override
  Future<SelfSkillPortfolioData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return const SelfSkillPortfolioData();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const SelfSkillPortfolioData();
      }
      final skills = <SelfSkillAsset>[];
      final rawSkills = decoded['skills'];
      if (rawSkills is List) {
        for (final item in rawSkills) {
          if (item is Map) {
            final parsed = SelfSkillAsset.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (parsed != null) {
              skills.add(parsed);
            }
          }
        }
      }
      final targets = <SelfSkillTarget>[];
      final rawTargets = decoded['targets'];
      if (rawTargets is List) {
        for (final item in rawTargets) {
          if (item is Map) {
            final parsed = SelfSkillTarget.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (parsed != null) {
              targets.add(parsed);
            }
          }
        }
      }
      return SelfSkillPortfolioData(
        skills: List<SelfSkillAsset>.unmodifiable(skills),
        targets: List<SelfSkillTarget>.unmodifiable(targets),
      );
    } catch (_) {
      return const SelfSkillPortfolioData();
    }
  }

  @override
  Future<void> save(SelfSkillPortfolioData data) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(<String, dynamic>{
      'skills': data.skills.map((s) => s.toJson()).toList(),
      'targets': data.targets.map((t) => t.toJson()).toList(),
    });
    await prefs.setString(_prefsKey, encoded);
    final remoteSync = onRemoteSync;
    if (remoteSync != null) {
      await remoteSync(data);
    }
  }
}

/// 人的スキル資産ポートフォリオの CRUD・集計・入力検証サービス (#1392 / #2770 / #2730)。
class SelfSkillAssetService {
  SelfSkillAssetService({SelfSkillAssetStorage? storage})
      : _storage = storage ?? SharedPreferencesSelfSkillAssetStorage();

  final SelfSkillAssetStorage _storage;

  static const List<String> defaultCategories = <String>[
    '技術・開発',
    'AI・データ',
    '事業・経営',
    '語学・発信',
    '資格・法務',
  ];

  static final RegExp _targetPeriodPattern = RegExp(
    r'^\d{4}-(0[1-9]|1[0-2]|Q[1-4])$',
  );

  /// スキル名（必須・2〜40文字）を検証する (#2730)。
  static String? validateSkillName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'スキル名を入力してください。';
    }
    if (trimmed.length < 2) {
      return 'スキル名は2文字以上で入力してください。';
    }
    if (trimmed.length > 40) {
      return 'スキル名は40文字以内で入力してください。';
    }
    return null;
  }

  /// 習熟度レベル（1〜5の整数）を検証する (#2730)。
  static String? validateProficiencyLevel(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 1 || parsed > 5) {
      return '習熟度は 1〜5 の整数で入力してください。';
    }
    return null;
  }

  /// 経験年数（0以上60以下の数値）を検証する (#2730)。
  static String? validateExperienceYears(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < 0 || parsed > 60) {
      return '経験年数は 0〜60 の数値で入力してください。';
    }
    return null;
  }

  /// 目標達成時期（例: `2026-12` または `2026-Q4`）を検証する (#2730)。
  static String? validateTargetPeriod(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '目標時期（例: 2026-12 または 2026-Q4）を入力してください。';
    }
    if (!_targetPeriodPattern.hasMatch(trimmed)) {
      return 'YYYY-MM または YYYY-Q1〜Q4 形式で入力してください。';
    }
    return null;
  }

  /// 進捗率（0〜100の整数）を検証する (#2730)。
  static String? validateProgressPercent(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 0 || parsed > 100) {
      return '進捗率は 0〜100 の整数で入力してください。';
    }
    return null;
  }

  Future<SelfSkillPortfolioData> load() => _storage.load();

  Future<SelfSkillPortfolioData> upsertSkill(
    SelfSkillAsset skill, {
    SelfSkillPortfolioData? currentData,
  }) async {
    final data = currentData ?? await _storage.load();
    final updatedSkills = List<SelfSkillAsset>.from(data.skills);
    final idx = updatedSkills.indexWhere((item) => item.id == skill.id);
    if (idx >= 0) {
      updatedSkills[idx] = skill;
    } else {
      updatedSkills.add(skill);
    }
    final next = SelfSkillPortfolioData(
      skills: List<SelfSkillAsset>.unmodifiable(updatedSkills),
      targets: data.targets,
    );
    await _storage.save(next);
    return next;
  }

  Future<SelfSkillPortfolioData> deleteSkill(
    String skillId, {
    SelfSkillPortfolioData? currentData,
  }) async {
    final data = currentData ?? await _storage.load();
    final updatedSkills =
        data.skills.where((item) => item.id != skillId).toList(growable: false);
    final next = SelfSkillPortfolioData(
      skills: List<SelfSkillAsset>.unmodifiable(updatedSkills),
      targets: data.targets,
    );
    await _storage.save(next);
    return next;
  }

  Future<SelfSkillPortfolioData> upsertTarget(
    SelfSkillTarget target, {
    SelfSkillPortfolioData? currentData,
  }) async {
    final data = currentData ?? await _storage.load();
    final updatedTargets = List<SelfSkillTarget>.from(data.targets);
    final idx = updatedTargets.indexWhere((item) => item.id == target.id);
    if (idx >= 0) {
      updatedTargets[idx] = target;
    } else {
      updatedTargets.add(target);
    }
    final next = SelfSkillPortfolioData(
      skills: data.skills,
      targets: List<SelfSkillTarget>.unmodifiable(updatedTargets),
    );
    await _storage.save(next);
    return next;
  }

  Future<SelfSkillPortfolioData> deleteTarget(
    String targetId, {
    SelfSkillPortfolioData? currentData,
  }) async {
    final data = currentData ?? await _storage.load();
    final updatedTargets = data.targets
        .where((item) => item.id != targetId)
        .toList(growable: false);
    final next = SelfSkillPortfolioData(
      skills: data.skills,
      targets: List<SelfSkillTarget>.unmodifiable(updatedTargets),
    );
    await _storage.save(next);
    return next;
  }

  /// ポートフォリオ全体とレーダーチャート軸を集計する（純関数）。
  static SelfSkillPortfolioSummary summarize(SelfSkillPortfolioData data) {
    final skills = data.skills;
    final targets = data.targets;

    final verifiedCount = skills
        .where((s) => s.origin == SkillAssessmentOrigin.verifiedRecord)
        .length;
    final selfCount = skills.length - verifiedCount;
    final avgProficiency = skills.isEmpty
        ? 0.0
        : skills.map((s) => s.proficiencyLevel).reduce((a, b) => a + b) /
            skills.length;
    final avgTargetProgress = targets.isEmpty
        ? 0.0
        : targets.map((t) => t.currentProgressPercent).reduce((a, b) => a + b) /
            targets.length;

    // レーダーチャート軸を構築：スキルが3件以上ある場合、カテゴリ別平均で3軸以上作れるか判定し、
    // カテゴリが3未満ならスキル個別軸へフォールバックして必ず多角形を描画できるようにする。
    final categoryGroups = <String, List<int>>{};
    for (final skill in skills) {
      categoryGroups.putIfAbsent(skill.category, () => <int>[]).add(
            skill.proficiencyLevel,
          );
    }
    final axes = <SelfSkillRadarAxisPoint>[];
    if (categoryGroups.length >= 3) {
      for (final entry in categoryGroups.entries.take(6)) {
        final avg =
            entry.value.reduce((a, b) => a + b) / entry.value.length.toDouble();
        axes.add(
          SelfSkillRadarAxisPoint(
            label: entry.key,
            value: avg,
            maxValue: 5.0,
          ),
        );
      }
    } else {
      for (final skill in skills.take(6)) {
        axes.add(
          SelfSkillRadarAxisPoint(
            label: skill.name,
            value: skill.proficiencyLevel.toDouble(),
            maxValue: 5.0,
          ),
        );
      }
    }

    return SelfSkillPortfolioSummary(
      totalSkills: skills.length,
      verifiedSkillsCount: verifiedCount,
      selfDeclaredSkillsCount: selfCount,
      averageProficiency: avgProficiency,
      totalTargets: targets.length,
      averageTargetProgress: avgTargetProgress,
      radarAxes: List<SelfSkillRadarAxisPoint>.unmodifiable(axes),
    );
  }
}
