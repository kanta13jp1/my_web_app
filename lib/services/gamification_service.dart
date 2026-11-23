import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/achievement.dart';
import '../models/chro_achievement_evaluation.dart';
import '../models/user_stats.dart';

typedef ChroAiEvaluator = Future<String?> Function(
    Achievement achievement, UserStats stats);

class _AchievementSpec {
  final String id;
  final String categoryId;
  final String title;
  final String description;
  final String iconCode;
  final int pointsReward;
  final int targetValue;
  final String executiveRole;

  const _AchievementSpec({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.iconCode,
    required this.pointsReward,
    required this.targetValue,
    required this.executiveRole,
  });
}

/// 動的実績解除と CHRO/AI 役員評価を扱うゲーミフィケーションサービス (#1406)。
class GamificationService extends ChangeNotifier {
  static const String _localCacheKey = 'gamification_dynamic_state_v1';

  static const List<_AchievementSpec> _catalog = <_AchievementSpec>[
    _AchievementSpec(
      id: 'first_task_completed',
      categoryId: 'general',
      title: '初タスク達成',
      description: 'タスクを1件完了する',
      iconCode: 'check_circle',
      pointsReward: 50,
      targetValue: 1,
      executiveRole: 'CHRO',
    ),
    _AchievementSpec(
      id: 'five_tasks_completed',
      categoryId: 'organization',
      title: '継続実行リーダー',
      description: 'タスクを累計5件完了する',
      iconCode: 'workspace_premium',
      pointsReward: 150,
      targetValue: 5,
      executiveRole: 'COO',
    ),
    _AchievementSpec(
      id: 'declutter_quest_success',
      categoryId: 'general',
      title: 'リアル断捨離マスター',
      description: 'リアル断捨離クエストを達成する',
      iconCode: 'cleaning_services',
      pointsReward: 120,
      targetValue: 1,
      executiveRole: 'CHRO',
    ),
    _AchievementSpec(
      id: 'first_note_created',
      categoryId: 'notes',
      title: 'ナレッジ初記録',
      description: 'メモを1件以上作成する',
      iconCode: 'edit_note',
      pointsReward: 30,
      targetValue: 1,
      executiveRole: 'CKO',
    ),
    _AchievementSpec(
      id: 'streak_3_days',
      categoryId: 'streak',
      title: '3日連続アクティビティ',
      description: '3日連続で学習・タスクを継続する',
      iconCode: 'local_fire_department',
      pointsReward: 100,
      targetValue: 3,
      executiveRole: 'CHRO',
    ),
    _AchievementSpec(
      id: 'points_milestone_100',
      categoryId: 'sharing',
      title: '100pt 達成評価',
      description: '累計100ポイントを獲得する',
      iconCode: 'stars',
      pointsReward: 80,
      targetValue: 100,
      executiveRole: 'CEO',
    ),
  ];

  final dynamic _client;
  final ChroAiEvaluator? _aiEvaluator;
  final DateTime Function()? _nowProvider;

  bool _initialized = false;
  int _totalPoints = 0;
  int _tasksCompleted = 0;
  int _declutterCompleted = 0;
  int _notesCreated = 0;
  int _categoriesCreated = 0;
  int _notesShared = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  DateTime? _lastActivityDate;

  final Map<String, Achievement> _unlockedById = <String, Achievement>{};
  final List<Achievement> _recentUnlocked = <Achievement>[];
  final List<ChroAchievementEvaluation> _evaluations =
      <ChroAchievementEvaluation>[];

  late AchievementCategory _general;
  late AchievementCategory _notes;
  late AchievementCategory _categories;
  late AchievementCategory _sharing;
  late AchievementCategory _organization;
  late AchievementCategory _streak;

  GamificationService([dynamic client])
      : _client = client,
        _aiEvaluator = null,
        _nowProvider = null {
    _rebuildCategories();
  }

  GamificationService.configured({
    dynamic client,
    ChroAiEvaluator? aiEvaluator,
    DateTime Function()? nowProvider,
  })  : _client = client,
        _aiEvaluator = aiEvaluator,
        _nowProvider = nowProvider {
    _rebuildCategories();
  }

  DateTime _now() => (_nowProvider?.call() ?? DateTime.now()).toUtc();

  AchievementCategory get general => _general;
  AchievementCategory get notes => _notes;
  AchievementCategory get categories => _categories;
  AchievementCategory get sharing => _sharing;
  AchievementCategory get organization => _organization;
  AchievementCategory get streak => _streak;

  List<AchievementCategory> get achievementCategories => <AchievementCategory>[
        _general,
        _notes,
        _categories,
        _sharing,
        _organization,
        _streak,
      ];

  List<Achievement> get recentUnlocked =>
      List<Achievement>.unmodifiable(_recentUnlocked);

  List<ChroAchievementEvaluation> get evaluations =>
      List<ChroAchievementEvaluation>.unmodifiable(_evaluations);

  ChroAchievementEvaluation? get latestEvaluation =>
      _evaluations.isEmpty ? null : _evaluations.first;

  int get totalPoints => _totalPoints;
  int get tasksCompleted => _tasksCompleted;
  int get declutterCompleted => _declutterCompleted;

  int _progressForSpec(_AchievementSpec spec) => switch (spec.id) {
        'first_task_completed' => _tasksCompleted,
        'five_tasks_completed' => _tasksCompleted,
        'declutter_quest_success' => _declutterCompleted,
        'first_note_created' => _notesCreated,
        'streak_3_days' => _longestStreak,
        'points_milestone_100' => _totalPoints,
        _ => 0,
      };

  void _rebuildCategories() {
    AchievementCategory buildCat(String id, String name) {
      final list = _catalog.where((spec) => spec.categoryId == id).map((spec) {
        final unlocked = _unlockedById[spec.id];
        if (unlocked != null) {
          return unlocked;
        }
        final current = _progressForSpec(spec);
        final ratio = spec.targetValue > 0
            ? (current / spec.targetValue).clamp(0.0, 1.0)
            : 0.0;
        return Achievement(
          id: spec.id,
          title: spec.title,
          description: spec.description,
          iconCode: spec.iconCode,
          isUnlocked: false,
          progress: ratio,
          pointsReward: spec.pointsReward,
          currentProgress: current,
          targetValue: spec.targetValue,
        );
      }).toList(growable: false);
      return AchievementCategory(id: id, name: name, achievements: list);
    }

    _general = buildCat('general', '一般');
    _notes = buildCat('notes', 'メモ');
    _categories = buildCat('categories', 'カテゴリ');
    _sharing = buildCat('sharing', '共有');
    _organization = buildCat('organization', '組織');
    _streak = buildCat('streak', '継続');
  }

  String _resolveUserId() {
    try {
      final auth = _client?.auth;
      final dynamic user = auth?.currentUser;
      final id = user?.id?.toString();
      if (id != null && id.isNotEmpty) {
        return id;
      }
    } catch (_) {
      // Uninitialized Supabase or Mockito mock without stubs.
    }
    return 'local_ceo';
  }

  UserStats _snapshotStats() => UserStats(
        userId: _resolveUserId(),
        totalPoints: _totalPoints,
        currentLevel: UserStats.calculateLevel(_totalPoints),
        notesCreated: _notesCreated,
        categoriesCreated: _categoriesCreated,
        notesShared: _notesShared,
        currentStreak: _currentStreak,
        longestStreak: _longestStreak,
        lastActivityDate: _lastActivityDate,
      );

  /// 活動実績を記録し、条件を満たした実績を動的に解除する。
  Future<List<Achievement>> recordActivity({
    int tasksCompletedDelta = 0,
    int declutterCompletedDelta = 0,
    int notesCreatedDelta = 0,
    int categoriesCreatedDelta = 0,
    int notesSharedDelta = 0,
    int? streakDays,
    String? contextNote,
  }) async {
    _initialized = true;
    if (tasksCompletedDelta > 0) {
      _tasksCompleted += tasksCompletedDelta;
    }
    if (declutterCompletedDelta > 0) {
      _declutterCompleted += declutterCompletedDelta;
    }
    if (notesCreatedDelta > 0) {
      _notesCreated += notesCreatedDelta;
    }
    if (categoriesCreatedDelta > 0) {
      _categoriesCreated += categoriesCreatedDelta;
    }
    if (notesSharedDelta > 0) {
      _notesShared += notesSharedDelta;
    }
    if (streakDays != null && streakDays >= 0) {
      _currentStreak = streakDays;
      if (streakDays > _longestStreak) {
        _longestStreak = streakDays;
      }
    }
    _lastActivityDate = _now();
    return checkAchievements(contextNote: contextNote);
  }

  /// 条件を満たした未解除実績を判定し、AI 役員評価とポイント報酬を付与する。
  Future<List<Achievement>> checkAchievements({String? contextNote}) async {
    final newlyUnlocked = <Achievement>[];
    final evalTime = _now();

    for (final spec in _catalog) {
      if (_unlockedById.containsKey(spec.id)) {
        continue;
      }
      final current = _progressForSpec(spec);
      if (current < spec.targetValue) {
        continue;
      }

      _initialized = true;
      _totalPoints += spec.pointsReward;
      final unlocked = Achievement(
        id: spec.id,
        title: spec.title,
        description: spec.description,
        iconCode: spec.iconCode,
        isUnlocked: true,
        progress: 1.0,
        pointsReward: spec.pointsReward,
        currentProgress: spec.targetValue,
        targetValue: spec.targetValue,
        unlockedAt: evalTime,
      );
      _unlockedById[spec.id] = unlocked;
      _recentUnlocked.insert(0, unlocked);
      newlyUnlocked.add(unlocked);

      final statsSnapshot = _snapshotStats();
      final generated = await _generateExecutiveEvaluation(
        spec: spec,
        achievement: unlocked,
        stats: statsSnapshot,
        contextNote: contextNote,
      );
      _evaluations.insert(0, generated);
    }

    _rebuildCategories();
    if (newlyUnlocked.isNotEmpty) {
      await _persistLocalState();
    }
    notifyListeners();
    return newlyUnlocked;
  }

  Future<ChroAchievementEvaluation> _generateExecutiveEvaluation({
    required _AchievementSpec spec,
    required Achievement achievement,
    required UserStats stats,
    String? contextNote,
  }) async {
    final evalTime = achievement.unlockedAt ?? _now();
    String? aiMessage;
    var source = 'local_fallback';

    if (_aiEvaluator != null) {
      try {
        final candidate = await _aiEvaluator(achievement, stats);
        if (candidate != null && candidate.trim().isNotEmpty) {
          aiMessage = candidate.trim();
          source = 'ai_evaluator';
        }
      } catch (_) {
        // Fail open to deterministic CHRO evaluation message.
      }
    } else if (_client != null) {
      try {
        final dynamic response = await _client.functions.invoke(
          'analyze_note_text',
          body: <String, dynamic>{
            'mode': 'chro_achievement_evaluation',
            'achievement_id': spec.id,
            'achievement_title': spec.title,
            'executive_role': spec.executiveRole,
            'total_points': stats.totalPoints,
            'level': stats.currentLevel,
            if (contextNote != null && contextNote.trim().isNotEmpty)
              'context': contextNote.trim(),
          },
        );
        final dynamic data = response?.data;
        if (data is Map<String, dynamic>) {
          final text =
              (data['evaluation'] ?? data['message'] ?? data['summary'] ?? '')
                  .toString()
                  .trim();
          if (text.isNotEmpty) {
            aiMessage = text;
            source = 'edge_function';
          }
        }
      } catch (_) {
        // Unstubbed mock or offline EF falls back cleanly.
      }
    }

    final fallback = _buildFallbackPraise(
      spec: spec,
      stats: stats,
      contextNote: contextNote,
    );

    return ChroAchievementEvaluation(
      id: '${spec.id}_${evalTime.millisecondsSinceEpoch}',
      achievementId: spec.id,
      achievementTitle: spec.title,
      executiveRole: spec.executiveRole,
      message: aiMessage ?? fallback,
      pointsAwarded: spec.pointsReward,
      evaluatedAt: evalTime,
      source: source,
    );
  }

  String _buildFallbackPraise({
    required _AchievementSpec spec,
    required UserStats stats,
    String? contextNote,
  }) {
    final noteSuffix = (contextNote != null && contextNote.trim().isNotEmpty)
        ? '（「${contextNote.trim()}」）'
        : '';
    return '${spec.executiveRole}評価: 「${spec.title}」の達成$noteSuffixを称賛します。'
        ' +${spec.pointsReward}pt を付与し、累計 ${stats.totalPoints}pt '
        '(Lv.${stats.currentLevel} ${stats.levelTitle}) に到達しました。';
  }

  // ポイント付与は名前付き引数 reason を維持
  Future<void> awardPoints(int points, {String? reason}) async {
    debugPrint('Awarded $points points. Reason: $reason');
    if (points > 0) {
      _initialized = true;
      _totalPoints += points;
      _lastActivityDate = _now();
      await checkAchievements(contextNote: reason);
      return;
    }
    notifyListeners();
  }

  Future<UserStats?> getUserStats() async {
    if (!_initialized) {
      return null;
    }
    return _snapshotStats();
  }

  Future<void> initializeUserStats() async {
    _initialized = true;
    await restoreFromLocalCache();
    _rebuildCategories();
    notifyListeners();
  }

  Future<List<Achievement>> getUserAchievements() async =>
      List<Achievement>.unmodifiable(_unlockedById.values);

  /// CHRO オフィス画面向けの統合評価サマリーを構築する。
  ChroEvaluationSummary buildChroSummary() {
    final level = UserStats.calculateLevel(_totalPoints);
    final stats = UserStats(
      userId: _resolveUserId(),
      totalPoints: _totalPoints,
      currentLevel: level,
      notesCreated: _notesCreated,
      categoriesCreated: _categoriesCreated,
      notesShared: _notesShared,
      currentStreak: _currentStreak,
      longestStreak: _longestStreak,
    );
    final unlockedCount = _unlockedById.length;
    final latest = latestEvaluation;

    String nextGoal = 'すべての実績を達成しました。高い生産性を維持しましょう。';
    for (final spec in _catalog) {
      if (!_unlockedById.containsKey(spec.id)) {
        final progress = _progressForSpec(spec);
        nextGoal =
            '${spec.title} ($progress/${spec.targetValue}) — ${spec.description}';
        break;
      }
    }

    final headline = latest != null
        ? latest.message
        : unlockedCount == 0
            ? 'CHRO評価待機中: タスク完了やリアル断捨離クエストを達成すると個別評価が生成されます。'
            : '累計 $_totalPoints pt / 解除実績 $unlockedCount/${_catalog.length} 件を達成しています。';

    return ChroEvaluationSummary(
      totalPoints: _totalPoints,
      currentLevel: level,
      levelTitle: stats.levelTitle,
      unlockedCount: unlockedCount,
      totalCatalogCount: _catalog.length,
      latestEvaluation: latest,
      headline: headline,
      nextRecommendedGoal: nextGoal,
    );
  }

  Future<void> _persistLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'totalPoints': _totalPoints,
        'tasksCompleted': _tasksCompleted,
        'declutterCompleted': _declutterCompleted,
        'notesCreated': _notesCreated,
        'categoriesCreated': _categoriesCreated,
        'notesShared': _notesShared,
        'currentStreak': _currentStreak,
        'longestStreak': _longestStreak,
        'unlockedIds': _unlockedById.keys.toList(),
        'evaluations': _evaluations.map((e) => e.toJson()).toList(),
      };
      await prefs.setString(_localCacheKey, jsonEncode(payload));
    } catch (_) {
      // SharedPreferences unavailable in pure unit test environments.
    }
  }

  Future<void> restoreFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localCacheKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      _totalPoints = (decoded['totalPoints'] as num?)?.toInt() ?? _totalPoints;
      _tasksCompleted =
          (decoded['tasksCompleted'] as num?)?.toInt() ?? _tasksCompleted;
      _declutterCompleted = (decoded['declutterCompleted'] as num?)?.toInt() ??
          _declutterCompleted;
      _notesCreated =
          (decoded['notesCreated'] as num?)?.toInt() ?? _notesCreated;
      _categoriesCreated =
          (decoded['categoriesCreated'] as num?)?.toInt() ?? _categoriesCreated;
      _notesShared = (decoded['notesShared'] as num?)?.toInt() ?? _notesShared;
      _currentStreak =
          (decoded['currentStreak'] as num?)?.toInt() ?? _currentStreak;
      _longestStreak =
          (decoded['longestStreak'] as num?)?.toInt() ?? _longestStreak;

      final unlockedIds =
          (decoded['unlockedIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toSet();
      for (final spec in _catalog) {
        if (unlockedIds.contains(spec.id) &&
            !_unlockedById.containsKey(spec.id)) {
          _unlockedById[spec.id] = Achievement(
            id: spec.id,
            title: spec.title,
            description: spec.description,
            iconCode: spec.iconCode,
            isUnlocked: true,
            progress: 1.0,
            pointsReward: spec.pointsReward,
            currentProgress: spec.targetValue,
            targetValue: spec.targetValue,
          );
        }
      }

      final evalList = decoded['evaluations'] as List<dynamic>?;
      if (evalList != null && evalList.isNotEmpty) {
        _evaluations
          ..clear()
          ..addAll(
            evalList
                .whereType<Map<String, dynamic>>()
                .map(ChroAchievementEvaluation.fromJson),
          );
      }
      _rebuildCategories();
    } catch (_) {
      // Ignore cache decode errors cleanly.
    }
  }
}
