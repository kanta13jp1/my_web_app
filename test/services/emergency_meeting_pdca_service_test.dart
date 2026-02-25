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
        abstinenceViolationCount: 1,
        abstinenceNoViolationDays: 4,
        reminderEnabled: true,
        activeDeterrenceLocks: const ['衝動買いロック', '新規プロジェクト着手ロック'],
        lastReviewAt: DateTime.parse('2026-02-26T09:00:00.000Z'),
      );

      final json = metrics.toJson();

      expect(json['continuation_completed_count'], 2);
      expect(json['continuation_total_count'], 3);
      expect(json['continuation_completion_rate_percent'], 67);
      expect(json['abstinence_violation_count'], 1);
      expect(json['abstinence_no_violation_days'], 4);
      expect(json['reminder_enabled'], isTrue);
      expect(
        json['active_deterrence_locks'],
        containsAll(<String>['衝動買いロック', '新規プロジェクト着手ロック']),
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
        topic: '緊急役員会議（継続 + 禁欲（両立））',
        conclusion: '今週は進捗共有を最優先で実施。',
        messages: <BoardMessage>[
          BoardMessage(
            id: 'm-1',
            speakerName: 'AI CFO',
            role: 'CFO',
            content: '支出最適化を実行。',
            timestamp: now,
          ),
          BoardMessage(
            id: 'm-2',
            speakerName: 'AI CSO',
            role: 'CSO',
            content: '週次レビューを固定化。',
            timestamp: now,
          ),
        ],
        createdAt: now,
      );
      final metrics = EmergencyMeetingPdcaMetrics(
        continuationCompletedCount: 1,
        continuationTotalCount: 3,
        continuationCompletionRatePercent: 33,
        abstinenceViolationCount: 2,
        abstinenceNoViolationDays: 0,
        reminderEnabled: false,
        activeDeterrenceLocks: const ['サブスク追加ロック'],
        lastReviewAt: now,
      );

      final text = EmergencyMeetingCodexFormatter.formatForCodex(
        log: log,
        focusLabel: '継続 + 禁欲（両立）',
        model: 'gemma-3n-e2b-it',
        continuationPlan: const <String>['行動1', '行動2', '行動3'],
        abstinenceRules: const <String>['禁欲1', '禁欲2', '禁欲3'],
        riskAlert: '遅延リスクあり',
        metrics: metrics,
      );

      expect(text, contains('【緊急役員会議 → Codex 連携データ】'));
      expect(text, contains('--- Meeting Result JSON ---'));

      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      final payload = jsonDecode(text.substring(jsonStart, jsonEnd + 1))
          as Map<String, dynamic>;

      expect(payload['meeting_id'], 'meeting-1');
      expect(payload['focus'], '継続 + 禁欲（両立）');
      expect(payload['model'], 'gemma-3n-e2b-it');
      expect(payload['continuation_plan'], hasLength(3));
      expect(payload['abstinence_rules'], hasLength(3));
      expect(payload['next_meeting_metrics'], isA<Map<String, dynamic>>());

      final nextMetrics =
          payload['next_meeting_metrics'] as Map<String, dynamic>;
      expect(nextMetrics['continuation_completion_rate_percent'], 33);
      expect(nextMetrics['abstinence_violation_count'], 2);
      expect(nextMetrics['active_deterrence_locks'], contains('サブスク追加ロック'));
    });
  });
}
