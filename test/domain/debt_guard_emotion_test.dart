import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/debt_guard_emotion.dart';
import 'package:my_web_app/domain/models/debt_guard_rule.dart';

void main() {
  final now = DateTime(2026, 11, 10, 21);
  var nextId = 1;

  DebtGuardEvent event(
    DebtGuardEventType type,
    DebtGuardEmotion? emotion, {
    DateTime? day,
    int? id,
  }) {
    final date = day ?? DateTime(2026, 11, 10);
    return DebtGuardEvent(
      id: id ?? nextId++,
      ruleId: 'eating_out',
      type: type,
      eventDate: date,
      createdAt: date.add(const Duration(hours: 12)),
      emotion: emotion,
    );
  }

  group('DebtGuardEmotion', () {
    test('wire names round-trip and are unique', () {
      final names = DebtGuardEmotion.values.map((e) => e.wireName).toSet();
      expect(names, hasLength(DebtGuardEmotion.values.length));
      for (final emotion in DebtGuardEmotion.values) {
        expect(DebtGuardEmotionCopy.tryFromWireName(emotion.wireName), emotion);
        expect(emotion.label, isNotEmpty);
        expect(emotion.signal, isNotEmpty);
        expect(emotion.minimumAction, isNotEmpty);
      }
    });

    test('unknown or missing wire names become null instead of throwing', () {
      expect(DebtGuardEmotionCopy.tryFromWireName(null), isNull);
      expect(DebtGuardEmotionCopy.tryFromWireName('rage_from_future'), isNull);
    });

    test(
      'the database check constraint lists exactly the client vocabulary',
      () {
        final sql = File(
          'supabase/migrations/20261110090000_prison_rule_events_emotion.sql',
        ).readAsStringSync().replaceAll('\r\n', '\n');
        final block = RegExp(
          r'emotion is null or emotion in \(([^)]*)\)',
        ).firstMatch(sql);
        expect(block, isNotNull);
        final inSql = RegExp(
          r"'([a-z_]+)'",
        ).allMatches(block!.group(1)!).map((match) => match.group(1)!).toSet();
        expect(inSql, DebtGuardEmotion.values.map((e) => e.wireName).toSet());
        expect(sql, contains("emotion is null or event_type <> 'check_in'"));
        expect(sql, contains('add column if not exists emotion text'));
        expect(sql.toLowerCase(), isNot(contains('grant update')));
        expect(sql.toLowerCase(), isNot(contains('grant delete')));
      },
    );
  });

  group('DebtGuardEmotionInsight', () {
    test('is insufficient below the minimum labelled count', () {
      final insight = DebtGuardEmotionInsight.fromEvents(
        events: [
          event(DebtGuardEventType.violation, DebtGuardEmotion.boredom),
          event(DebtGuardEventType.violation, DebtGuardEmotion.boredom),
        ],
        now: now,
      );

      expect(insight.status, DebtGuardEmotionInsightStatus.insufficient);
      expect(insight.labelledCount, 2);
      expect(insight.riskiest, isNull);
    });

    test('unavailable is distinct from an evaluated empty history', () {
      const unavailable = DebtGuardEmotionInsight.unavailable();
      final empty = DebtGuardEmotionInsight.fromEvents(
        events: const [],
        now: now,
      );

      expect(unavailable.status, DebtGuardEmotionInsightStatus.unavailable);
      expect(empty.status, DebtGuardEmotionInsightStatus.insufficient);
    });

    test('names the emotion that most often precedes a violation', () {
      final insight = DebtGuardEmotionInsight.fromEvents(
        events: [
          event(DebtGuardEventType.violation, DebtGuardEmotion.boredom),
          event(DebtGuardEventType.violation, DebtGuardEmotion.boredom),
          event(DebtGuardEventType.violation, DebtGuardEmotion.boredom),
          event(DebtGuardEventType.violation, DebtGuardEmotion.fatigue),
          event(DebtGuardEventType.urgeResisted, DebtGuardEmotion.irritation),
          event(DebtGuardEventType.urgeResisted, DebtGuardEmotion.irritation),
          event(
            DebtGuardEventType.requiredActionStarted,
            DebtGuardEmotion.irritation,
          ),
          event(DebtGuardEventType.violation, DebtGuardEmotion.irritation),
        ],
        now: now,
      );

      expect(insight.status, DebtGuardEmotionInsightStatus.ready);
      expect(insight.labelledCount, 8);
      expect(insight.violationCount, 5);
      expect(insight.riskiest!.emotion, DebtGuardEmotion.boredom);
      expect(insight.riskiest!.violationCount, 3);
      expect(insight.steadiest!.emotion, DebtGuardEmotion.irritation);
      expect(insight.steadiest!.overcomeCount, 3);
      expect(insight.steadiest!.totalCount, 4);
      expect(insight.tallies.map((tally) => tally.emotion), [
        DebtGuardEmotion.irritation,
        DebtGuardEmotion.boredom,
        DebtGuardEmotion.fatigue,
      ]);
    });

    test('a single violation per emotion is not presented as a pattern', () {
      final insight = DebtGuardEmotionInsight.fromEvents(
        events: [
          event(DebtGuardEventType.violation, DebtGuardEmotion.boredom),
          event(DebtGuardEventType.violation, DebtGuardEmotion.fatigue),
          event(DebtGuardEventType.violation, DebtGuardEmotion.anxiety),
        ],
        now: now,
      );

      expect(insight.status, DebtGuardEmotionInsightStatus.ready);
      expect(insight.riskiest, isNull);
      expect(insight.steadiest, isNull);
    });

    test('ignores unlabelled events, check-ins and duplicate ids', () {
      final insight = DebtGuardEmotionInsight.fromEvents(
        events: [
          event(DebtGuardEventType.violation, null),
          event(DebtGuardEventType.checkIn, DebtGuardEmotion.boredom),
          event(
            DebtGuardEventType.violation,
            DebtGuardEmotion.sadness,
            id: 900,
          ),
          event(
            DebtGuardEventType.violation,
            DebtGuardEmotion.sadness,
            id: 900,
          ),
        ],
        now: now,
      );

      expect(insight.labelledCount, 1);
      expect(insight.tallies.single.emotion, DebtGuardEmotion.sadness);
    });

    test('counts only days inside the window, both ends inclusive', () {
      final firstDay = DebtGuardEmotionInsight.windowStart(now);
      expect(firstDay, DateTime(2026, 10, 14));

      final insight = DebtGuardEmotionInsight.fromEvents(
        events: [
          event(
            DebtGuardEventType.violation,
            DebtGuardEmotion.hunger,
            day: firstDay,
          ),
          event(
            DebtGuardEventType.violation,
            DebtGuardEmotion.hunger,
            day: DateTime(2026, 11, 10),
          ),
          event(
            DebtGuardEventType.violation,
            DebtGuardEmotion.hunger,
            day: DateTime(2026, 10, 13),
          ),
          event(
            DebtGuardEventType.violation,
            DebtGuardEmotion.hunger,
            day: DateTime(2026, 11, 11),
          ),
        ],
        now: now,
      );

      expect(insight.labelledCount, 2);
    });

    test('ties on violation count resolve to the more frequent emotion', () {
      final insight = DebtGuardEmotionInsight.fromEvents(
        events: [
          event(DebtGuardEventType.violation, DebtGuardEmotion.elation),
          event(DebtGuardEventType.violation, DebtGuardEmotion.elation),
          event(DebtGuardEventType.violation, DebtGuardEmotion.anxiety),
          event(DebtGuardEventType.violation, DebtGuardEmotion.anxiety),
          event(DebtGuardEventType.urgeResisted, DebtGuardEmotion.elation),
        ],
        now: now,
      );

      // elation has more records overall, so it sorts first and wins the tie.
      expect(insight.riskiest!.emotion, DebtGuardEmotion.elation);
    });
  });
}
