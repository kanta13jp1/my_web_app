import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/debt_guard_emotion.dart';
import 'package:my_web_app/domain/models/debt_guard_rule.dart';
import 'package:my_web_app/domain/models/debt_guard_stall_thought.dart';

void main() {
  final now = DateTime(2026, 11, 11, 21);
  var nextId = 1;

  DebtGuardEvent event(
    DebtGuardEventType type,
    DebtGuardStallThought? thought, {
    DateTime? day,
    int? id,
  }) {
    final date = day ?? DateTime(2026, 11, 11);
    return DebtGuardEvent(
      id: id ?? nextId++,
      ruleId: 'dishes_left_unwashed',
      type: type,
      eventDate: date,
      createdAt: date.add(const Duration(hours: 12)),
      stallThought: thought,
    );
  }

  const started = DebtGuardEventType.requiredActionStarted;
  const notStarted = DebtGuardEventType.violation;

  group('DebtGuardStallThought', () {
    test('wire names round-trip, are unique, and carry copy', () {
      final names = DebtGuardStallThought.values.map((t) => t.wireName).toSet();
      expect(names, hasLength(DebtGuardStallThought.values.length));
      final labels = DebtGuardStallThought.values.map((t) => t.label).toSet();
      expect(labels, hasLength(DebtGuardStallThought.values.length));
      for (final thought in DebtGuardStallThought.values) {
        expect(
          DebtGuardStallThoughtCopy.tryFromWireName(thought.wireName),
          thought,
        );
        expect(thought.counter, isNotEmpty);
      }
    });

    test('unknown or missing wire names become null instead of throwing', () {
      expect(DebtGuardStallThoughtCopy.tryFromWireName(null), isNull);
      expect(DebtGuardStallThoughtCopy.tryFromWireName('cynicism_v2'), isNull);
    });

    test('the database constraints match the client vocabulary and scope', () {
      final sql = File(
        'supabase/migrations/'
        '20261111090000_prison_rule_events_stall_thought.sql',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final block = RegExp(
        r'stall_thought is null or stall_thought in \(([^)]*)\)',
      ).firstMatch(sql);
      expect(block, isNotNull);
      final inSql = RegExp(r"'([a-z_]+)'")
          .allMatches(block!.group(1)!)
          .map((match) => match.group(1)!)
          .toSet();
      expect(
        inSql,
        DebtGuardStallThought.values.map((t) => t.wireName).toSet(),
      );
      expect(
        sql,
        contains("or event_type in ('required_action_started', 'violation')"),
      );
      expect(sql, contains('add column if not exists stall_thought text'));
      expect(sql.toLowerCase(), isNot(contains('grant update')));
      expect(sql.toLowerCase(), isNot(contains('grant delete')));
    });
  });

  group('DebtGuardStallThoughtInsight', () {
    test('unavailable is distinct from an evaluated empty history', () {
      const unavailable = DebtGuardStallThoughtInsight.unavailable();
      final empty = DebtGuardStallThoughtInsight.fromEvents(
        events: const [],
        now: now,
      );

      expect(unavailable.status, DebtGuardEmotionInsightStatus.unavailable);
      expect(empty.status, DebtGuardEmotionInsightStatus.insufficient);
      expect(empty.labelledCount, 0);
    });

    test('is insufficient below the minimum labelled count', () {
      final insight = DebtGuardStallThoughtInsight.fromEvents(
        events: [
          event(notStarted, DebtGuardStallThought.futile),
          event(notStarted, DebtGuardStallThought.futile),
        ],
        now: now,
      );

      expect(insight.status, DebtGuardEmotionInsightStatus.insufficient);
      expect(insight.labelledCount, 2);
      expect(insight.stickiest, isNull);
    });

    test('names the thought that most often ends in not starting', () {
      final insight = DebtGuardStallThoughtInsight.fromEvents(
        events: [
          event(notStarted, DebtGuardStallThought.pointless),
          event(notStarted, DebtGuardStallThought.pointless),
          event(notStarted, DebtGuardStallThought.pointless),
          event(started, DebtGuardStallThought.pointless),
          event(notStarted, DebtGuardStallThought.later),
          event(started, DebtGuardStallThought.later),
          event(started, DebtGuardStallThought.later),
          event(started, DebtGuardStallThought.later),
        ],
        now: now,
      );

      expect(insight.status, DebtGuardEmotionInsightStatus.ready);
      expect(insight.labelledCount, 8);
      expect(insight.notStartedCount, 4);
      expect(insight.stickiest!.thought, DebtGuardStallThought.pointless);
      expect(insight.stickiest!.notStartedCount, 3);
      expect(insight.loosest!.thought, DebtGuardStallThought.later);
      expect(insight.loosest!.startedCount, 3);
      expect(insight.loosest!.totalCount, 4);
    });

    test('a single miss per thought is not presented as a pattern', () {
      final insight = DebtGuardStallThoughtInsight.fromEvents(
        events: [
          event(notStarted, DebtGuardStallThought.futile),
          event(notStarted, DebtGuardStallThought.embarrassed),
          event(notStarted, DebtGuardStallThought.tooSmall),
        ],
        now: now,
      );

      expect(insight.status, DebtGuardEmotionInsightStatus.ready);
      expect(insight.stickiest, isNull);
      expect(insight.loosest, isNull);
    });

    test('ignores unlabelled rows, non-attempt event types and duplicate ids',
        () {
      final insight = DebtGuardStallThoughtInsight.fromEvents(
        events: [
          event(notStarted, null),
          event(DebtGuardEventType.checkIn, DebtGuardStallThought.futile),
          event(DebtGuardEventType.urgeResisted, DebtGuardStallThought.futile),
          event(notStarted, DebtGuardStallThought.later, id: 900),
          event(notStarted, DebtGuardStallThought.later, id: 900),
        ],
        now: now,
      );

      expect(insight.labelledCount, 1);
      expect(insight.tallies.single.thought, DebtGuardStallThought.later);
    });

    test('counts only days inside the window, both ends inclusive', () {
      final firstDay = DebtGuardEmotionInsight.windowStart(now);
      final insight = DebtGuardStallThoughtInsight.fromEvents(
        events: [
          event(notStarted, DebtGuardStallThought.futile, day: firstDay),
          event(notStarted, DebtGuardStallThought.futile),
          event(
            notStarted,
            DebtGuardStallThought.futile,
            day: DateTime(firstDay.year, firstDay.month, firstDay.day - 1),
          ),
          event(
            notStarted,
            DebtGuardStallThought.futile,
            day: DateTime(2026, 11, 12),
          ),
        ],
        now: now,
      );

      expect(insight.labelledCount, 2);
    });
  });
}
