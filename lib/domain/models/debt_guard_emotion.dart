import 'debt_guard_rule.dart';

/// The feeling behind an urge, named by the user at the moment of recording.
///
/// The guard treats an emotion as information about an unmet need, not as
/// noise to suppress. Each value therefore carries the need it usually points
/// at and one minimum action that answers that need without spending.
enum DebtGuardEmotion {
  irritation,
  anxiety,
  boredom,
  loneliness,
  fatigue,
  sadness,
  hunger,
  elation,
}

extension DebtGuardEmotionCopy on DebtGuardEmotion {
  String get wireName => switch (this) {
        DebtGuardEmotion.irritation => 'irritation',
        DebtGuardEmotion.anxiety => 'anxiety',
        DebtGuardEmotion.boredom => 'boredom',
        DebtGuardEmotion.loneliness => 'loneliness',
        DebtGuardEmotion.fatigue => 'fatigue',
        DebtGuardEmotion.sadness => 'sadness',
        DebtGuardEmotion.hunger => 'hunger',
        DebtGuardEmotion.elation => 'elation',
      };

  String get label => switch (this) {
        DebtGuardEmotion.irritation => 'イライラ',
        DebtGuardEmotion.anxiety => '不安',
        DebtGuardEmotion.boredom => '退屈',
        DebtGuardEmotion.loneliness => '寂しさ',
        DebtGuardEmotion.fatigue => '疲れ',
        DebtGuardEmotion.sadness => '落ち込み',
        DebtGuardEmotion.hunger => '空腹',
        DebtGuardEmotion.elation => '浮かれ',
      };

  /// What this feeling is usually telling the person.
  String get signal => switch (this) {
        DebtGuardEmotion.irritation => '思いどおりにならないことがあり、発散先を探しています。',
        DebtGuardEmotion.anxiety => '先の見通しが立たず、いますぐ安心できるものを探しています。',
        DebtGuardEmotion.boredom => '刺激が足りず、手近な刺激で埋めようとしています。',
        DebtGuardEmotion.loneliness => '人とのつながりが足りず、代わりになるものを探しています。',
        DebtGuardEmotion.fatigue => '休息が足りず、楽に済ませる方法を探しています。',
        DebtGuardEmotion.sadness => '気持ちが沈み、自分を慰めるものを探しています。',
        DebtGuardEmotion.hunger => '体のエネルギーが足りず、判断が雑になりやすい状態です。',
        DebtGuardEmotion.elation => '気が大きくなり、「今日くらいは」と財布がゆるみやすい状態です。',
      };

  /// One minimum action that answers the need without spending money.
  String get minimumAction => switch (this) {
        DebtGuardEmotion.irritation => 'その場を離れて、5分だけ歩く',
        DebtGuardEmotion.anxiety => '残高と次の支払予定を1分だけ確認して、分かっていることを書く',
        DebtGuardEmotion.boredom => '本を1ページ読むか、物を1つ片付ける',
        DebtGuardEmotion.loneliness => '家族・友人・支援者の誰か1人に短い連絡をする',
        DebtGuardEmotion.fatigue => '横になって10分休む。眠れるなら寝る',
        DebtGuardEmotion.sadness => '温かい飲み物を用意して、いまの気持ちを1行書く',
        DebtGuardEmotion.hunger => '家にあるものを食べて、水を飲む',
        DebtGuardEmotion.elation => '買いたい物をメモして、明日もう一度見る',
      };

  /// Returns null for an unknown value so a newer server vocabulary cannot
  /// break loading of the rest of the event.
  static DebtGuardEmotion? tryFromWireName(String? value) {
    if (value == null) return null;
    for (final emotion in DebtGuardEmotion.values) {
      if (emotion.wireName == value) return emotion;
    }
    return null;
  }
}

/// Outcome counts for one emotion inside the insight window.
class DebtGuardEmotionTally {
  const DebtGuardEmotionTally({
    required this.emotion,
    required this.overcomeCount,
    required this.violationCount,
  });

  final DebtGuardEmotion emotion;

  /// Urges resisted plus required actions started while feeling this way.
  final int overcomeCount;
  final int violationCount;

  int get totalCount => overcomeCount + violationCount;
}

enum DebtGuardEmotionInsightStatus {
  /// The labelled history could not be loaded. Distinct from "no records":
  /// the panel must not claim there is no pattern when it simply did not look.
  unavailable,

  /// Loaded, but too few labelled records to say anything.
  insufficient,

  /// Enough labelled records to show the breakdown.
  ready,
}

/// Which feelings come before violations, derived from labelled events.
class DebtGuardEmotionInsight {
  const DebtGuardEmotionInsight._({
    required this.status,
    required this.windowDays,
    required this.tallies,
    required this.labelledCount,
    required this.violationCount,
    required this.riskiest,
    required this.steadiest,
  });

  const DebtGuardEmotionInsight.unavailable({
    this.windowDays = defaultWindowDays,
  })  : status = DebtGuardEmotionInsightStatus.unavailable,
        tallies = const <DebtGuardEmotionTally>[],
        labelledCount = 0,
        violationCount = 0,
        riskiest = null,
        steadiest = null;

  static const defaultWindowDays = 28;

  /// Below this many labelled records the breakdown is not shown.
  static const minimumLabelledCount = 3;

  /// An emotion needs this many violations before it is named as a trigger,
  /// so a single bad day is not presented as a pattern.
  static const minimumPatternCount = 2;

  factory DebtGuardEmotionInsight.fromEvents({
    required Iterable<DebtGuardEvent> events,
    required DateTime now,
    int windowDays = defaultWindowDays,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = windowStart(now, windowDays: windowDays);
    final overcome = <DebtGuardEmotion, int>{};
    final violated = <DebtGuardEmotion, int>{};
    final seenIds = <int>{};

    for (final event in events) {
      final emotion = event.emotion;
      if (emotion == null) continue;
      if (!seenIds.add(event.id)) continue;
      final day = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      );
      if (day.isBefore(firstDay) || day.isAfter(today)) continue;
      switch (event.type) {
        case DebtGuardEventType.violation:
          violated[emotion] = (violated[emotion] ?? 0) + 1;
        case DebtGuardEventType.urgeResisted:
        case DebtGuardEventType.requiredActionStarted:
          overcome[emotion] = (overcome[emotion] ?? 0) + 1;
        case DebtGuardEventType.checkIn:
          // A routine check-in is not an urge.
          break;
      }
    }

    final tallies = <DebtGuardEmotionTally>[
      for (final emotion in DebtGuardEmotion.values)
        if ((overcome[emotion] ?? 0) + (violated[emotion] ?? 0) > 0)
          DebtGuardEmotionTally(
            emotion: emotion,
            overcomeCount: overcome[emotion] ?? 0,
            violationCount: violated[emotion] ?? 0,
          ),
    ]..sort((a, b) {
        final byTotal = b.totalCount.compareTo(a.totalCount);
        if (byTotal != 0) return byTotal;
        return a.emotion.index.compareTo(b.emotion.index);
      });

    final labelledCount = tallies.fold<int>(
      0,
      (sum, tally) => sum + tally.totalCount,
    );
    final violationCount = tallies.fold<int>(
      0,
      (sum, tally) => sum + tally.violationCount,
    );

    if (labelledCount < minimumLabelledCount) {
      return DebtGuardEmotionInsight._(
        status: DebtGuardEmotionInsightStatus.insufficient,
        windowDays: windowDays,
        tallies: List.unmodifiable(tallies),
        labelledCount: labelledCount,
        violationCount: violationCount,
        riskiest: null,
        steadiest: null,
      );
    }

    DebtGuardEmotionTally? riskiest;
    for (final tally in tallies) {
      if (tally.violationCount < minimumPatternCount) continue;
      if (riskiest == null || tally.violationCount > riskiest.violationCount) {
        riskiest = tally;
      }
    }

    DebtGuardEmotionTally? steadiest;
    for (final tally in tallies) {
      if (tally.overcomeCount < minimumPatternCount) continue;
      if (tally.overcomeCount <= tally.violationCount) continue;
      if (identical(tally, riskiest)) continue;
      if (steadiest == null || tally.overcomeCount > steadiest.overcomeCount) {
        steadiest = tally;
      }
    }

    return DebtGuardEmotionInsight._(
      status: DebtGuardEmotionInsightStatus.ready,
      windowDays: windowDays,
      tallies: List.unmodifiable(tallies),
      labelledCount: labelledCount,
      violationCount: violationCount,
      riskiest: riskiest,
      steadiest: steadiest,
    );
  }

  final DebtGuardEmotionInsightStatus status;
  final int windowDays;

  /// Emotions with at least one labelled record, most frequent first.
  final List<DebtGuardEmotionTally> tallies;
  final int labelledCount;
  final int violationCount;

  /// The emotion that most often precedes a violation, if any repeats.
  final DebtGuardEmotionTally? riskiest;

  /// The emotion the user most reliably gets through, if any repeats.
  final DebtGuardEmotionTally? steadiest;

  /// The first day (local midnight) included in a window ending at [now].
  static DateTime windowStart(
    DateTime now, {
    int windowDays = defaultWindowDays,
  }) {
    // Calendar arithmetic, not a Duration, so a DST shift cannot move the day.
    return DateTime(now.year, now.month, now.day - (windowDays - 1));
  }
}
