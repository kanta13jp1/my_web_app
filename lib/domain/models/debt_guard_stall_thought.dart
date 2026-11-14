import 'debt_guard_emotion.dart';
import 'debt_guard_rule.dart';

/// The sentence in the user's head that keeps a required action from starting.
///
/// Each one is a judgement made from the outside, before any work exists to
/// judge. The guard does not argue with the judgement; it postpones it until
/// after a two-minute start, which is the only point where there is evidence.
enum DebtGuardStallThought {
  futile,
  pointless,
  embarrassed,
  perfectionism,
  later,
  tooSmall,
}

extension DebtGuardStallThoughtCopy on DebtGuardStallThought {
  String get wireName => switch (this) {
        DebtGuardStallThought.futile => 'futile',
        DebtGuardStallThought.pointless => 'pointless',
        DebtGuardStallThought.embarrassed => 'embarrassed',
        DebtGuardStallThought.perfectionism => 'perfectionism',
        DebtGuardStallThought.later => 'later',
        DebtGuardStallThought.tooSmall => 'too_small',
      };

  /// The thought in the user's own voice.
  String get label => switch (this) {
        DebtGuardStallThought.futile => 'どうせ無理',
        DebtGuardStallThought.pointless => 'やっても意味がない',
        DebtGuardStallThought.embarrassed => 'いまさら恥ずかしい',
        DebtGuardStallThought.perfectionism => 'ちゃんとできないならやらない',
        DebtGuardStallThought.later => 'あとでやればいい',
        DebtGuardStallThought.tooSmall => 'これくらいでは変わらない',
      };

  /// How to set the judgement aside for two minutes without disputing it.
  String get counter => switch (this) {
        DebtGuardStallThought.futile => '無理かどうかは、2分やってから決めます。'
            'やる前の予想は、やった後の実感とよくずれます。',
        DebtGuardStallThought.pointless => '意味があるかは、終わってから判定します。'
            'いまは判定を保留して、手だけ動かします。',
        DebtGuardStallThought.embarrassed => '見ている人はいません。'
            '下手なままでいいので、2分だけやります。',
        DebtGuardStallThought.perfectionism => '今日は「雑に1つ」で合格です。'
            '仕上げは次の回に回します。',
        DebtGuardStallThought.later => '「あとで」はたいてい来ません。'
            'いまは最初の1動作だけやります。',
        DebtGuardStallThought.tooSmall => '1回では変わりません。変わるのは回数です。'
            '今日の1回を数に入れます。',
      };

  /// Returns null for an unknown value so a newer server vocabulary cannot
  /// break loading of the rest of the event.
  static DebtGuardStallThought? tryFromWireName(String? value) {
    if (value == null) return null;
    for (final thought in DebtGuardStallThought.values) {
      if (thought.wireName == value) return thought;
    }
    return null;
  }
}

/// Outcome counts for one stalling thought inside the insight window.
class DebtGuardStallThoughtTally {
  const DebtGuardStallThoughtTally({
    required this.thought,
    required this.startedCount,
    required this.notStartedCount,
  });

  final DebtGuardStallThought thought;

  /// Times the user had this thought and started anyway.
  final int startedCount;

  /// Times the user had this thought and did not start.
  final int notStartedCount;

  int get totalCount => startedCount + notStartedCount;
}

/// Which thoughts end in not starting, derived from labelled events.
///
/// Reuses [DebtGuardEmotionInsightStatus] so both trends share one meaning of
/// "could not look" versus "looked and found too little".
class DebtGuardStallThoughtInsight {
  const DebtGuardStallThoughtInsight._({
    required this.status,
    required this.windowDays,
    required this.tallies,
    required this.labelledCount,
    required this.notStartedCount,
    required this.stickiest,
    required this.loosest,
  });

  const DebtGuardStallThoughtInsight.unavailable({
    this.windowDays = DebtGuardEmotionInsight.defaultWindowDays,
  })  : status = DebtGuardEmotionInsightStatus.unavailable,
        tallies = const <DebtGuardStallThoughtTally>[],
        labelledCount = 0,
        notStartedCount = 0,
        stickiest = null,
        loosest = null;

  factory DebtGuardStallThoughtInsight.fromEvents({
    required Iterable<DebtGuardEvent> events,
    required DateTime now,
    int windowDays = DebtGuardEmotionInsight.defaultWindowDays,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DebtGuardEmotionInsight.windowStart(
      now,
      windowDays: windowDays,
    );
    final started = <DebtGuardStallThought, int>{};
    final notStarted = <DebtGuardStallThought, int>{};
    final seenIds = <int>{};

    for (final event in events) {
      final thought = event.stallThought;
      if (thought == null) continue;
      if (!seenIds.add(event.id)) continue;
      final day = DateTime(
        event.eventDate.year,
        event.eventDate.month,
        event.eventDate.day,
      );
      if (day.isBefore(firstDay) || day.isAfter(today)) continue;
      switch (event.type) {
        case DebtGuardEventType.requiredActionStarted:
          started[thought] = (started[thought] ?? 0) + 1;
        case DebtGuardEventType.violation:
          notStarted[thought] = (notStarted[thought] ?? 0) + 1;
        case DebtGuardEventType.checkIn:
        case DebtGuardEventType.urgeResisted:
          // Not an attempt to start a required action.
          break;
      }
    }

    final tallies = <DebtGuardStallThoughtTally>[
      for (final thought in DebtGuardStallThought.values)
        if ((started[thought] ?? 0) + (notStarted[thought] ?? 0) > 0)
          DebtGuardStallThoughtTally(
            thought: thought,
            startedCount: started[thought] ?? 0,
            notStartedCount: notStarted[thought] ?? 0,
          ),
    ]..sort((a, b) {
        final byTotal = b.totalCount.compareTo(a.totalCount);
        if (byTotal != 0) return byTotal;
        return a.thought.index.compareTo(b.thought.index);
      });

    final labelledCount =
        tallies.fold<int>(0, (sum, tally) => sum + tally.totalCount);
    final notStartedCount =
        tallies.fold<int>(0, (sum, tally) => sum + tally.notStartedCount);

    if (labelledCount < DebtGuardEmotionInsight.minimumLabelledCount) {
      return DebtGuardStallThoughtInsight._(
        status: DebtGuardEmotionInsightStatus.insufficient,
        windowDays: windowDays,
        tallies: List.unmodifiable(tallies),
        labelledCount: labelledCount,
        notStartedCount: notStartedCount,
        stickiest: null,
        loosest: null,
      );
    }

    const minimum = DebtGuardEmotionInsight.minimumPatternCount;
    DebtGuardStallThoughtTally? stickiest;
    for (final tally in tallies) {
      if (tally.notStartedCount < minimum) continue;
      if (stickiest == null ||
          tally.notStartedCount > stickiest.notStartedCount) {
        stickiest = tally;
      }
    }

    DebtGuardStallThoughtTally? loosest;
    for (final tally in tallies) {
      if (tally.startedCount < minimum) continue;
      if (tally.startedCount <= tally.notStartedCount) continue;
      if (identical(tally, stickiest)) continue;
      if (loosest == null || tally.startedCount > loosest.startedCount) {
        loosest = tally;
      }
    }

    return DebtGuardStallThoughtInsight._(
      status: DebtGuardEmotionInsightStatus.ready,
      windowDays: windowDays,
      tallies: List.unmodifiable(tallies),
      labelledCount: labelledCount,
      notStartedCount: notStartedCount,
      stickiest: stickiest,
      loosest: loosest,
    );
  }

  final DebtGuardEmotionInsightStatus status;
  final int windowDays;

  /// Thoughts with at least one labelled record, most frequent first.
  final List<DebtGuardStallThoughtTally> tallies;
  final int labelledCount;
  final int notStartedCount;

  /// The thought that most often ends in not starting, if any repeats.
  final DebtGuardStallThoughtTally? stickiest;

  /// The thought the user most reliably starts in spite of, if any repeats.
  final DebtGuardStallThoughtTally? loosest;
}
