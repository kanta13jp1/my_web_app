// IQテスト機能のモデルクラス
//
// 設計方針:
// - 問題本体 (IqQuestion) はコード内バンク / 手続き生成で持つ。DB には結果のみ保存する。
//   理由: (1) 正解キーを公開 SELECT 可能なテーブルに置かない (2) トレーニングは
//   無限に問題を生成する必要があり、静的シードでは賄えない。
// - 推定 IQ はあくまで「簡易推定」。臨床的な標準化サンプルによる規準ではない。
//   換算定数は IqCalibration に集約し、根拠が仮定であることを明示する。

/// IQテストの測定領域。
///
/// 「結果の数値をもとに学習する」ための最小単位。総合 IQ ではなく
/// この領域別スコアがトレーニング計画の入力になる。
enum IqCategory {
  logic,
  numerical,
  spatial,
  memory,
  verbal,
}

extension IqCategoryX on IqCategory {
  /// DB / JSON に保存する安定キー。enum の名前変更で壊れないよう明示する。
  String get key {
    switch (this) {
      case IqCategory.logic:
        return 'logic';
      case IqCategory.numerical:
        return 'numerical';
      case IqCategory.spatial:
        return 'spatial';
      case IqCategory.memory:
        return 'memory';
      case IqCategory.verbal:
        return 'verbal';
    }
  }

  String get labelJa {
    switch (this) {
      case IqCategory.logic:
        return '論理推論';
      case IqCategory.numerical:
        return '数的処理';
      case IqCategory.spatial:
        return '空間認識';
      case IqCategory.memory:
        return 'ワーキングメモリ';
      case IqCategory.verbal:
        return '言語理解';
    }
  }

  String get descriptionJa {
    switch (this) {
      case IqCategory.logic:
        return '前提から結論を導く力。条件・対偶・順序の処理。';
      case IqCategory.numerical:
        return '数の規則性を見抜く力。数列・比率・演算の構造把握。';
      case IqCategory.spatial:
        return '図形を頭の中で操作する力。回転・鏡像・パターン補完。';
      case IqCategory.memory:
        return '情報を保持しながら操作する力。数唱・逆唱・対連合。';
      case IqCategory.verbal:
        return '語と語の関係を捉える力。類推・分類・語彙の精度。';
    }
  }

  /// 弱点として検出されたときに提示する、日常での伸ばし方。
  String get trainingHintJa {
    switch (this) {
      case IqCategory.logic:
        return '結論から逆算せず、前提を1つずつ書き出してから判断する癖をつける。';
      case IqCategory.numerical:
        return '差分・比・階差の3つを機械的に試す手順を身体化する。';
      case IqCategory.spatial:
        return '回転は「基準点を1つ決めて追う」。全体を一度に回そうとしない。';
      case IqCategory.memory:
        return '数字はチャンク化 (3-4桁ずつ) して保持する。逆唱で負荷を上げる。';
      case IqCategory.verbal:
        return '関係を言語化する (「AはBの一部」「AはBの原因」) 癖をつける。';
    }
  }

  static IqCategory fromKey(String key) {
    return IqCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => IqCategory.logic,
    );
  }
}

/// 出題ページへ渡すルート引数。
///
/// testId と seed が揃わないと出題を復元できない (選択肢の並びが再現できない)
/// ため、片方だけでは開けないよう1つの型にまとめている。
class IqTestSessionArgs {
  final int testId;
  final int questionSeed;

  const IqTestSessionArgs({
    required this.testId,
    required this.questionSeed,
  });
}

/// ドリルページへ渡すルート引数。
class IqTrainingDrillArgs {
  final int planId;
  final IqCategory category;
  final int level;

  const IqTrainingDrillArgs({
    required this.planId,
    required this.category,
    required this.level,
  });
}

/// 1問。テストバンクの固定問題とトレーニングの生成問題の両方に使う。
class IqQuestion {
  /// 問題の安定識別子。固定問題は `logic-01` 等、生成問題は `gen-numerical-l3-42` 等。
  final String key;
  final IqCategory category;

  /// 難易度 1..5。得点の重みでもある。
  final int difficulty;

  final String prompt;
  final List<String> options;
  final int correctIndex;

  /// 解説。トレーニングでは即時フィードバックとして必ず表示する。
  final String explanation;

  /// ワーキングメモリ問題用。設定されている場合、[revealSeconds] 秒だけ
  /// この刺激を提示してから隠し、選択肢を出す。
  final String? memoryStimulus;
  final int? revealSeconds;

  /// 空間問題などで等幅表示したい本文。
  final bool monospacePrompt;

  const IqQuestion({
    required this.key,
    required this.category,
    required this.difficulty,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.memoryStimulus,
    this.revealSeconds,
    this.monospacePrompt = false,
  });

  bool get hasMemoryPhase => memoryStimulus != null && revealSeconds != null;

  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;

  /// 読み上げ用の問題文。図形は言葉に開く。
  String get semanticPrompt =>
      monospacePrompt ? describeGridText(prompt) : prompt;

  /// 読み上げ用の選択肢。
  String semanticOption(int index) =>
      monospacePrompt ? describeGridText(options[index]) : options[index];
}

/// 等幅グリッド (■ / □) を含むテキストを読み上げ可能な説明へ開く。
///
/// スクリーンリーダーは ■ を「黒い四角」等としか読まないため、
/// 空間問題は音声だけでは配置が復元できず解答不能になる。
/// グリッド行だけを検出し「1行目: 塗り、空」の形に置き換える。
/// グリッド以外の行はそのまま残す。
String describeGridText(String text) {
  final lines = text.split('\n');
  final out = <String>[];
  var rowNumber = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    final isGridRow =
        trimmed.isNotEmpty && RegExp(r'^[■□\s]+$').hasMatch(trimmed);

    if (!isGridRow) {
      rowNumber = 0;
      out.add(line);
      continue;
    }

    rowNumber++;
    final cells = trimmed
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty)
        .map((c) => c == '■' ? '塗り' : '空')
        .join('、');
    out.add('$rowNumber行目: $cells');
  }

  return out.join('\n');
}

/// 1問への回答。
class IqAnswerRecord {
  final String questionKey;
  final IqCategory category;
  final int difficulty;

  /// 未回答 (時間切れ) は null。
  final int? selectedIndex;
  final bool isCorrect;
  final int responseMs;

  const IqAnswerRecord({
    required this.questionKey,
    required this.category,
    required this.difficulty,
    required this.selectedIndex,
    required this.isCorrect,
    required this.responseMs,
  });

  Map<String, dynamic> toJson() => {
        'question_key': questionKey,
        'category': category.key,
        'difficulty': difficulty,
        'selected_index': selectedIndex,
        'is_correct': isCorrect,
        'response_ms': responseMs,
      };

  factory IqAnswerRecord.fromJson(Map<String, dynamic> json) {
    return IqAnswerRecord(
      questionKey: json['question_key'] as String,
      category: IqCategoryX.fromKey(json['category'] as String),
      difficulty: json['difficulty'] as int,
      selectedIndex: json['selected_index'] as int?,
      isCorrect: json['is_correct'] as bool,
      responseMs: json['response_ms'] as int? ?? 0,
    );
  }
}

/// 領域別スコア。
class IqCategoryScore {
  final IqCategory category;
  final int correctCount;
  final int questionCount;

  /// 難易度で重み付けした正答率 0.0..1.0。
  final double weightedAccuracy;

  /// 領域別の推定 IQ。設問数が少ないため [standardError] とセットで扱う。
  final int iq;

  /// 推定の標準誤差 (IQ ポイント)。設問数が少ないほど大きい。
  final double standardError;

  const IqCategoryScore({
    required this.category,
    required this.correctCount,
    required this.questionCount,
    required this.weightedAccuracy,
    required this.iq,
    required this.standardError,
  });

  /// 判定に使う標準誤差。
  ///
  /// [standardError] は列欠損時に 0 が入る。0 をそのまま弱点判定の閾値に使うと
  /// 「総合を1ポイントでも下回れば弱点」に退化し、固定閾値だった頃より
  /// 過検出がひどくなる。実際には5問の測定で誤差が 0 になることはないので、
  /// 下限を設けて 0 を弾く。
  static const double minimumStandardError = 3.0;

  double get effectiveStandardError => standardError < minimumStandardError
      ? minimumStandardError
      : standardError;

  /// 95% 信頼区間の下限 / 上限。UI では必ず幅つきで見せる。
  int get iqLower => (iq - 1.96 * effectiveStandardError).round();
  int get iqUpper => (iq + 1.96 * effectiveStandardError).round();

  /// 弱点判定の唯一の実装。
  ///
  /// **測定誤差を上回る差だけ**を弱点とする。5問しかない領域スコアの標準誤差は
  /// 約 18 IQ あり、固定閾値 5 は誤差の 0.27 SE にすぎなかった
  /// (= ノイズを弱点と呼んでいた)。全領域が誤差内なら空リストを返し、
  /// 「差が無い」ではなく「差を判別できない」ことを呼び出し側で表現する。
  ///
  /// 同じ式を複数のクラスに写すと片側だけ直したときに静かに乖離するため、
  /// ここを唯一の真実として全呼び出し元がこれを使う。
  static List<IqCategoryScore> selectWeak(
    List<IqCategoryScore> scores,
    int referenceIq, {
    double sigmaThreshold = 1.0,
  }) {
    final weak = scores
        .where(
          (s) =>
              (referenceIq - s.iq) > sigmaThreshold * s.effectiveStandardError,
        )
        .toList()
      ..sort((a, b) => a.iq.compareTo(b.iq));
    return weak;
  }

  /// [selectWeak] と対称の強み判定。
  static List<IqCategoryScore> selectStrong(
    List<IqCategoryScore> scores,
    int referenceIq, {
    double sigmaThreshold = 1.0,
  }) {
    final strong = scores
        .where(
          (s) =>
              (s.iq - referenceIq) > sigmaThreshold * s.effectiveStandardError,
        )
        .toList()
      ..sort((a, b) => b.iq.compareTo(a.iq));
    return strong;
  }

  Map<String, dynamic> toJson() => {
        'category': category.key,
        'correct_count': correctCount,
        'question_count': questionCount,
        'weighted_accuracy': weightedAccuracy,
        'category_iq': iq,
        'standard_error': standardError,
      };

  factory IqCategoryScore.fromJson(Map<String, dynamic> json) {
    return IqCategoryScore(
      category: IqCategoryX.fromKey(json['category'] as String),
      correctCount: json['correct_count'] as int,
      questionCount: json['question_count'] as int,
      weightedAccuracy: (json['weighted_accuracy'] as num).toDouble(),
      iq: json['category_iq'] as int,
      standardError: (json['standard_error'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// テスト1回分の結果。
class IqTestResult {
  final int id;
  final String userId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final bool isCompleted;

  /// 総合推定 IQ。
  final int totalIq;

  /// 同年代比パーセンタイル 0..100 (正規分布仮定)。
  final double percentile;

  final double weightedAccuracy;
  final int correctCount;
  final int questionCount;

  /// 実際に着手した問題数 (未回答を除く)。
  ///
  /// [questionCount] だけでは「3問解いて時間切れ」と「25問解いて低得点」を
  /// 区別できない。列を持たない古い結果では null になり [questionCount] に
  /// フォールバックする。
  final int? attemptedCount;
  final int durationSeconds;

  /// 出題時の選択肢シャッフルに使ったシード。
  /// これがあれば結果画面で当時と同一の問題・選択肢順を再構成できる。
  final int? questionSeed;
  final List<IqCategoryScore> categoryScores;

  const IqTestResult({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.completedAt,
    required this.isCompleted,
    required this.totalIq,
    required this.percentile,
    required this.weightedAccuracy,
    required this.correctCount,
    required this.questionCount,
    required this.durationSeconds,
    required this.categoryScores,
    this.attemptedCount,
    this.questionSeed,
  });

  IqCategoryScore? scoreFor(IqCategory category) {
    for (final s in categoryScores) {
      if (s.category == category) return s;
    }
    return null;
  }

  /// 総合値より明確に低い領域 = トレーニング対象。
  /// 判定の実体は [IqCategoryScore.selectWeak] に一本化してある。
  List<IqCategoryScore> weakAreas({double sigmaThreshold = 1.0}) =>
      IqCategoryScore.selectWeak(
        categoryScores,
        totalIq,
        sigmaThreshold: sigmaThreshold,
      );

  /// 相対的に強い領域。判定基準は [weakAreas] と対称。
  List<IqCategoryScore> strongAreas({double sigmaThreshold = 1.0}) =>
      IqCategoryScore.selectStrong(
        categoryScores,
        totalIq,
        sigmaThreshold: sigmaThreshold,
      );

  /// 完答率 0.0..1.0。不明な場合は 1.0 とみなす (旧データ互換)。
  double get completionRate {
    if (questionCount == 0) return 0;
    return (attemptedCount ?? questionCount) / questionCount;
  }

  /// スコアを額面どおり読んでよいか。
  ///
  /// 閾値 0.8 = 25問中5問までの未着手は許容する。
  /// 0.9 だと3問スキップで「測れていない」と出てしまい、警告が日常化して
  /// 本当に測れていない回 (半分以上未着手など) を見落とす。
  bool get isReliable => completionRate >= reliableCompletionRate;

  static const double reliableCompletionRate = 0.8;

  factory IqTestResult.fromJson(
    Map<String, dynamic> json, {
    List<IqCategoryScore> categoryScores = const [],
  }) {
    return IqTestResult(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      totalIq: json['total_iq'] as int? ?? 100,
      percentile: (json['percentile'] as num?)?.toDouble() ?? 50,
      weightedAccuracy: (json['weighted_accuracy'] as num?)?.toDouble() ?? 0,
      correctCount: json['correct_count'] as int? ?? 0,
      questionCount: json['question_count'] as int? ?? 0,
      attemptedCount: json['attempted_count'] as int?,
      questionSeed: json['question_seed'] as int?,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      categoryScores: categoryScores,
    );
  }
}

/// テスト結果から生成される学習計画。
class IqTrainingPlan {
  final int id;
  final String userId;

  /// 元になったテスト。どの数値から作られた計画かを常に辿れるようにする。
  final int sourceTestId;
  final int baselineIq;

  /// 対象領域と、その領域の開始レベル (1..5)。
  final List<IqTrainingTarget> targets;
  final DateTime createdAt;
  final bool isActive;

  const IqTrainingPlan({
    required this.id,
    required this.userId,
    required this.sourceTestId,
    required this.baselineIq,
    required this.targets,
    required this.createdAt,
    required this.isActive,
  });

  IqTrainingTarget? targetFor(IqCategory category) {
    for (final t in targets) {
      if (t.category == category) return t;
    }
    return null;
  }

  factory IqTrainingPlan.fromJson(Map<String, dynamic> json) {
    final rawTargets = (json['targets'] as List?) ?? const [];
    return IqTrainingPlan(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      sourceTestId: json['source_test_id'] as int,
      baselineIq: json['baseline_iq'] as int? ?? 100,
      targets: rawTargets
          .map((e) => IqTrainingTarget.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// 学習計画の1領域分。
class IqTrainingTarget {
  final IqCategory category;

  /// テスト時点の領域別 IQ。
  final int baselineIq;

  /// 開始難易度 1..5。測定値から決まる = 「数値をもとにした学習」の実体。
  final int startLevel;

  /// この領域に割り当てる週あたりのセッション数。弱いほど多い。
  final int weeklySessions;

  const IqTrainingTarget({
    required this.category,
    required this.baselineIq,
    required this.startLevel,
    required this.weeklySessions,
  });

  Map<String, dynamic> toJson() => {
        'category': category.key,
        'baseline_iq': baselineIq,
        'start_level': startLevel,
        'weekly_sessions': weeklySessions,
      };

  factory IqTrainingTarget.fromJson(Map<String, dynamic> json) {
    return IqTrainingTarget(
      category: IqCategoryX.fromKey(json['category'] as String),
      baselineIq: json['baseline_iq'] as int? ?? 100,
      startLevel: json['start_level'] as int? ?? 3,
      weeklySessions: json['weekly_sessions'] as int? ?? 3,
    );
  }
}

/// トレーニング1回分の記録。
class IqTrainingSession {
  final int id;
  final int planId;
  final String userId;
  final IqCategory category;
  final int level;
  final int correctCount;
  final int questionCount;
  final int durationSeconds;
  final DateTime completedAt;

  const IqTrainingSession({
    required this.id,
    required this.planId,
    required this.userId,
    required this.category,
    required this.level,
    required this.correctCount,
    required this.questionCount,
    required this.durationSeconds,
    required this.completedAt,
  });

  double get accuracy => questionCount == 0 ? 0 : correctCount / questionCount;

  factory IqTrainingSession.fromJson(Map<String, dynamic> json) {
    return IqTrainingSession(
      id: json['id'] as int,
      planId: json['plan_id'] as int,
      userId: json['user_id'] as String,
      category: IqCategoryX.fromKey(json['category'] as String),
      level: json['level'] as int,
      correctCount: json['correct_count'] as int,
      questionCount: json['question_count'] as int,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }
}
