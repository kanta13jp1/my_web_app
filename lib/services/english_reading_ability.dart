import 'package:flutter/material.dart';

import '../models/english_reading_models.dart';

/// 速読の WPM / 実効 WPM / レベル推定を担う純関数群。
///
/// すべて static の純粋関数で副作用なし。同じ計算式を ai-hub
/// `english_reading.submit_attempt` (TypeScript) 側でもサーバ計算しており、
/// クライアントの即時フィードバックとサーバ保存値が一致する。
class EnglishReadingMetrics {
  const EnglishReadingMetrics._();

  /// WPM = 語数 / 経過分。語数・経過が 0 以下なら 0 (ゼロ除算ガード)。
  static int wpm({required int wordCount, required int elapsedMs}) {
    if (wordCount <= 0 || elapsedMs <= 0) return 0;
    final minutes = elapsedMs / 60000.0;
    if (minutes <= 0) return 0;
    final raw = wordCount / minutes;
    return raw.isFinite ? raw.round() : 0;
  }

  /// 実効 WPM = WPM × 理解率。「速く読んでも理解していなければ無意味」を反映。
  /// クイズが無い (total<=0) 場合は WPM をそのまま採用 (RSVP 等)。
  static int effectiveWpm({
    required int wpm,
    required int comprehensionCorrect,
    required int comprehensionTotal,
  }) {
    if (wpm <= 0) return 0;
    if (comprehensionTotal <= 0) return wpm;
    final ratio = (comprehensionCorrect / comprehensionTotal).clamp(0.0, 1.0);
    return (wpm * ratio).round();
  }

  /// 実効 WPM から到達レベルを推定 (目標 WPM 以上を満たす最高レベル)。
  /// 最低レベルの目標にも届かない場合も Level 1 を返す (= 学習開始地点)。
  static EnglishReadingLevel levelForEffectiveWpm(int effectiveWpm) {
    var current = kEnglishReadingLevels.first;
    for (final l in kEnglishReadingLevels) {
      if (effectiveWpm >= l.targetWpm) current = l;
    }
    return current;
  }

  /// 対ネイティブ (300 WPM) 達成率 0.0〜1.0。
  static double nativeRatio(int effectiveWpm) {
    if (effectiveWpm <= 0) return 0;
    return (effectiveWpm / kNativeReadingWpm).clamp(0.0, 1.0);
  }
}

/// WPM 時系列チャート用の 1 点。
@immutable
class EnglishReadingTrendPoint {
  const EnglishReadingTrendPoint({
    required this.time,
    required this.wpm,
    required this.effectiveWpm,
  });

  final DateTime time;
  final int wpm;
  final int effectiveWpm;
}

/// 試行ログ群から算出した「現在の実力」スナップショット。
///
/// 実力指標 (WPM / 理解率 / 推定レベル) は計測モード (`measure`) を優先採用する。
/// 計測モードが無い場合のみ全試行へフォールバックする。
@immutable
class EnglishReadingAbilitySummary {
  const EnglishReadingAbilitySummary({
    required this.totalSessions,
    required this.totalWords,
    required this.latestWpm,
    required this.bestWpm,
    required this.averageWpm,
    required this.latestEffectiveWpm,
    required this.bestEffectiveWpm,
    required this.averageComprehension,
    required this.estimatedLevel,
    required this.nativeRatio,
    required this.clearedLevels,
    required this.trend,
  });

  final int totalSessions;
  final int totalWords;
  final int latestWpm;
  final int bestWpm;
  final int averageWpm;
  final int latestEffectiveWpm;
  final int bestEffectiveWpm;

  /// 平均理解率 0.0〜1.0。
  final double averageComprehension;

  /// 最新の実効 WPM から推定した現在レベル。
  final EnglishReadingLevel estimatedLevel;

  /// 対ネイティブ (300 WPM) 達成率 0.0〜1.0。
  final double nativeRatio;

  /// 「目標 WPM を理解率 75% 以上で達成」したレベル番号の集合。
  final Set<int> clearedLevels;

  /// 時系列 (古い→新しい) の WPM 推移。
  final List<EnglishReadingTrendPoint> trend;

  bool get hasData => totalSessions > 0;

  /// ネイティブ速度 (Level 6 / 300WPM) に到達済みか。
  bool get reachedNative => latestEffectiveWpm >= kNativeReadingWpm;

  factory EnglishReadingAbilitySummary.empty() {
    return EnglishReadingAbilitySummary(
      totalSessions: 0,
      totalWords: 0,
      latestWpm: 0,
      bestWpm: 0,
      averageWpm: 0,
      latestEffectiveWpm: 0,
      bestEffectiveWpm: 0,
      averageComprehension: 0,
      estimatedLevel: kEnglishReadingLevels.first,
      nativeRatio: 0,
      clearedLevels: const <int>{},
      trend: const <EnglishReadingTrendPoint>[],
    );
  }

  factory EnglishReadingAbilitySummary.fromAttempts(
    List<EnglishReadingAttempt> attempts,
  ) {
    if (attempts.isEmpty) return EnglishReadingAbilitySummary.empty();

    final sorted = List<EnglishReadingAttempt>.from(attempts)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final measured =
        sorted.where((a) => a.mode == 'measure').toList(growable: false);
    final basis = measured.isNotEmpty ? measured : sorted;

    final latest = basis.last;

    var bestWpm = 0;
    var bestEff = 0;
    var sumWpm = 0;
    var totalWords = 0;
    final compRatios = <double>[];
    final cleared = <int>{};

    for (final a in basis) {
      if (a.wpm > bestWpm) bestWpm = a.wpm;
      if (a.effectiveWpm > bestEff) bestEff = a.effectiveWpm;
      sumWpm += a.wpm;
      if (a.comprehensionTotal > 0) compRatios.add(a.comprehensionRatio);

      final lvl = englishReadingLevelOf(a.level);
      final passedComprehension =
          a.comprehensionTotal > 0 && a.comprehensionRatio >= 0.75;
      if (passedComprehension && a.wpm >= lvl.targetWpm) {
        cleared.add(a.level);
      }
    }

    // totalWords は訓練含む全試行を合算 (学習量の指標)。
    for (final a in sorted) {
      totalWords += a.wordCount;
    }

    final avgWpm = basis.isEmpty ? 0 : (sumWpm / basis.length).round();
    final avgComp = compRatios.isEmpty
        ? 0.0
        : compRatios.fold<double>(0, (s, v) => s + v) / compRatios.length;

    final trend = basis
        .map(
          (a) => EnglishReadingTrendPoint(
            time: a.createdAt,
            wpm: a.wpm,
            effectiveWpm: a.effectiveWpm,
          ),
        )
        .toList(growable: false);

    return EnglishReadingAbilitySummary(
      totalSessions: sorted.length,
      totalWords: totalWords,
      latestWpm: latest.wpm,
      bestWpm: bestWpm,
      averageWpm: avgWpm,
      latestEffectiveWpm: latest.effectiveWpm,
      bestEffectiveWpm: bestEff,
      averageComprehension: avgComp.clamp(0.0, 1.0),
      estimatedLevel: EnglishReadingMetrics.levelForEffectiveWpm(
        latest.effectiveWpm,
      ),
      nativeRatio: EnglishReadingMetrics.nativeRatio(latest.effectiveWpm),
      clearedLevels: cleared,
      trend: trend,
    );
  }
}
