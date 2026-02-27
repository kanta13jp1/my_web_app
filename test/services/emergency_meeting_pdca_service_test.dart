import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/board_meeting.dart';
import 'package:my_web_app/services/emergency_meeting_pdca_service.dart';

void main() {
  group('EmergencyMeetingPdcaMetrics', () {
    test('toJson returns expected metrics keys and values', () {
      final metrics = EmergencyMeetingPdcaMetrics(
        continuationCompletedCount: 2,
        continuationTotalCount: 3,
        continuationCompletionRatePercent: 67,
        continuationQuickStartCount: 4,
        abstinenceViolationCount: 1,
        abstinenceNoViolationDays: 4,
        abstinenceRuleCompletedCount: 2,
        abstinenceRuleTotalCount: 3,
        abstinenceRuleCompletionRatePercent: 67,
        deepWorkSessionCount: 5,
        weeklyPriorityReviewCount: 2,
        accountabilityShareCount: 1,
        abstinenceRecoveryActionCount: 2,
        reminderEnabled: true,
        deterrenceLockEnabledCount: 2,
        activeDeterrenceLocks: const <String>[
          'SNS制限ロック',
          '90分タイムボックス',
        ],
        lastReviewAt: DateTime.parse('2026-02-26T09:00:00.000Z'),
      );

      final json = metrics.toJson();

      expect(json['continuation_completed_count'], 2);
      expect(json['continuation_total_count'], 3);
      expect(json['continuation_completion_rate_percent'], 67);
      expect(json['continuation_quick_start_count'], 4);
      expect(json['abstinence_violation_count'], 1);
      expect(json['abstinence_no_violation_days'], 4);
      expect(json['abstinence_rule_completed_count'], 2);
      expect(json['abstinence_rule_total_count'], 3);
      expect(json['abstinence_rule_completion_rate_percent'], 67);
      expect(json['deep_work_session_count'], 5);
      expect(json['weekly_priority_review_count'], 2);
      expect(json['accountability_share_count'], 1);
      expect(json['abstinence_recovery_action_count'], 2);
      expect(json['reminder_enabled'], isTrue);
      expect(json['deterrence_lock_enabled_count'], 2);
      expect(
        json['active_deterrence_locks'],
        containsAll(<String>['SNS制限ロック', '90分タイムボックス']),
      );
      expect(json['last_review_at'], '2026-02-26T09:00:00.000Z');
    });
  });

  group('EmergencyMeetingCodexFormatter', () {
    test('formatForCodex contains valid JSON payload with next metrics', () {
      final now = DateTime.parse('2026-02-26T08:19:36.162Z');
      final log = BoardMeetingLog(
        id: 'meeting-1',
        userId: 'user-1',
        topic: 'Emergency meeting',
        conclusion: 'Share progress as top priority this week.',
        messages: <BoardMessage>[
          BoardMessage(
            id: 'm-1',
            speakerName: 'AI CFO',
            role: 'CFO',
            content: 'Optimize subscriptions.',
            timestamp: now,
          ),
          BoardMessage(
            id: 'm-2',
            speakerName: 'AI CSO',
            role: 'CSO',
            content: 'Fix weekly review cadence.',
            timestamp: now,
          ),
        ],
        createdAt: now,
      );
      final metrics = EmergencyMeetingPdcaMetrics(
        continuationCompletedCount: 1,
        continuationTotalCount: 3,
        continuationCompletionRatePercent: 33,
        continuationQuickStartCount: 2,
        abstinenceViolationCount: 2,
        abstinenceNoViolationDays: 0,
        abstinenceRuleCompletedCount: 1,
        abstinenceRuleTotalCount: 3,
        abstinenceRuleCompletionRatePercent: 33,
        deepWorkSessionCount: 2,
        weeklyPriorityReviewCount: 1,
        accountabilityShareCount: 4,
        abstinenceRecoveryActionCount: 3,
        reminderEnabled: false,
        deterrenceLockEnabledCount: 1,
        activeDeterrenceLocks: const <String>['週次共有リマインド'],
        lastReviewAt: now,
      );

      final text = EmergencyMeetingCodexFormatter.formatForCodex(
        log: log,
        focusLabel: 'Balanced',
        model: 'gemma-3n-e2b-it',
        continuationPlan: const <String>['Action 1', 'Action 2', 'Action 3'],
        abstinenceRules: const <String>['Rule 1', 'Rule 2', 'Rule 3'],
        riskAlert: 'Decision risk',
        metrics: metrics,
      );

      expect(text, contains('--- Meeting Result JSON ---'));

      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      final payload = jsonDecode(text.substring(jsonStart, jsonEnd + 1))
          as Map<String, dynamic>;

      expect(payload['meeting_id'], 'meeting-1');
      expect(payload['focus'], 'Balanced');
      expect(payload['model'], 'gemma-3n-e2b-it');
      expect(payload['continuation_plan'], hasLength(3));
      expect(payload['abstinence_rules'], hasLength(3));
      expect(payload['next_meeting_metrics'], isA<Map<String, dynamic>>());

      final nextMetrics =
          payload['next_meeting_metrics'] as Map<String, dynamic>;
      expect(nextMetrics['continuation_completion_rate_percent'], 33);
      expect(nextMetrics['continuation_quick_start_count'], 2);
      expect(nextMetrics['abstinence_violation_count'], 2);
      expect(nextMetrics['abstinence_rule_completion_rate_percent'], 33);
      expect(nextMetrics['deep_work_session_count'], 2);
      expect(nextMetrics['weekly_priority_review_count'], 1);
      expect(nextMetrics['accountability_share_count'], 4);
      expect(nextMetrics['abstinence_recovery_action_count'], 3);
      expect(nextMetrics['deterrence_lock_enabled_count'], 1);
      expect(
        nextMetrics['active_deterrence_locks'],
        contains('週次共有リマインド'),
      );
    });
  });
}
