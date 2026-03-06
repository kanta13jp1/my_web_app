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
        continuationTimeBlockReservedCount: 2,
        continuationProgressLogCount: 1,
        abstinenceViolationCount: 1,
        abstinenceNoViolationDays: 4,
        abstinenceRuleCompletedCount: 2,
        abstinenceRuleTotalCount: 3,
        abstinenceRuleCompletionRatePercent: 67,
        abstinenceRecoveredWithin10mCount: 3,
        abstinenceRecoveryWindowMissedCount: 1,
        deepWorkSessionCount: 5,
        weeklyPriorityReviewCount: 2,
        accountabilityShareCount: 1,
        abstinenceRecoveryActionCount: 2,
        reminderEnabled: true,
        deterrenceLockEnabledCount: 2,
        deterrenceStrictModeBlockCount: 4,
        deterrenceLockCoveragePercent: 67,
        abstinenceRecoveryDueAt: DateTime.parse('2026-02-26T09:10:00.000Z'),
        activeDeterrenceLocks: const <String>[
          'SNS lock',
          'Timebox lock',
        ],
        lastReviewAt: DateTime.parse('2026-02-26T09:00:00.000Z'),
      );

      final json = metrics.toJson();

      expect(json['continuation_completed_count'], 2);
      expect(json['continuation_total_count'], 3);
      expect(json['continuation_completion_rate_percent'], 67);
      expect(json['continuation_quick_start_count'], 4);
      expect(json['continuation_time_block_reserved_count'], 2);
      expect(json['continuation_progress_log_count'], 1);
      expect(json['abstinence_violation_count'], 1);
      expect(json['abstinence_no_violation_days'], 4);
      expect(json['abstinence_rule_completed_count'], 2);
      expect(json['abstinence_rule_total_count'], 3);
      expect(json['abstinence_rule_completion_rate_percent'], 67);
      expect(json['abstinence_recovered_within_10m_count'], 3);
      expect(json['abstinence_recovery_window_missed_count'], 1);
      expect(json['deep_work_session_count'], 5);
      expect(json['weekly_priority_review_count'], 2);
      expect(json['accountability_share_count'], 1);
      expect(json['abstinence_recovery_action_count'], 2);
      expect(json['reminder_enabled'], isTrue);
      expect(json['deterrence_lock_enabled_count'], 2);
      expect(json['deterrence_strict_mode_block_count'], 4);
      expect(json['deterrence_lock_coverage_percent'], 67);
      expect(json['abstinence_recovery_due_at'], '2026-02-26T09:10:00.000Z');
      expect(
        json['active_deterrence_locks'],
        containsAll(<String>['SNS lock', 'Timebox lock']),
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
            speakerName: 'AI CMO',
            role: 'CMO',
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
        continuationTimeBlockReservedCount: 1,
        continuationProgressLogCount: 2,
        abstinenceViolationCount: 2,
        abstinenceNoViolationDays: 0,
        abstinenceRuleCompletedCount: 1,
        abstinenceRuleTotalCount: 3,
        abstinenceRuleCompletionRatePercent: 33,
        abstinenceRecoveredWithin10mCount: 2,
        abstinenceRecoveryWindowMissedCount: 3,
        deepWorkSessionCount: 2,
        weeklyPriorityReviewCount: 1,
        accountabilityShareCount: 4,
        abstinenceRecoveryActionCount: 3,
        reminderEnabled: false,
        deterrenceLockEnabledCount: 1,
        deterrenceStrictModeBlockCount: 5,
        deterrenceLockCoveragePercent: 33,
        abstinenceRecoveryDueAt: now.add(const Duration(minutes: 10)),
        activeDeterrenceLocks: const <String>['Subscription lock'],
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
      expect(nextMetrics['continuation_time_block_reserved_count'], 1);
      expect(nextMetrics['continuation_progress_log_count'], 2);
      expect(nextMetrics['abstinence_violation_count'], 2);
      expect(nextMetrics['abstinence_rule_completion_rate_percent'], 33);
      expect(nextMetrics['abstinence_recovered_within_10m_count'], 2);
      expect(nextMetrics['abstinence_recovery_window_missed_count'], 3);
      expect(nextMetrics['deep_work_session_count'], 2);
      expect(nextMetrics['weekly_priority_review_count'], 1);
      expect(nextMetrics['accountability_share_count'], 4);
      expect(nextMetrics['abstinence_recovery_action_count'], 3);
      expect(nextMetrics['deterrence_lock_enabled_count'], 1);
      expect(nextMetrics['deterrence_strict_mode_block_count'], 5);
      expect(nextMetrics['deterrence_lock_coverage_percent'], 33);
      expect(
        nextMetrics['abstinence_recovery_due_at'],
        '2026-02-26T08:29:36.162Z',
      );
      expect(
        nextMetrics['active_deterrence_locks'],
        contains('Subscription lock'),
      );
    });
  });
}
