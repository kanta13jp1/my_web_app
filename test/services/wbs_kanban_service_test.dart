import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/wbs_kanban_service.dart';

void main() {
  group('buildWbsKanbanUpdate', () {
    test('maps the four database statuses and the review gate', () {
      expect(
        buildWbsKanbanUpdate(lane: WbsKanbanLane.pending, currentProgress: 42),
        <String, dynamic>{
          'status': 'pending',
          'progress': 0,
          'ai_review_status': 'pending',
        },
      );
      expect(
        buildWbsKanbanUpdate(
          lane: WbsKanbanLane.inProgress,
          currentProgress: 100,
        ),
        <String, dynamic>{
          'status': 'in_progress',
          'progress': 94,
          'ai_review_status': 'pending',
        },
      );
      expect(
        buildWbsKanbanUpdate(lane: WbsKanbanLane.review, currentProgress: 20),
        <String, dynamic>{
          'status': 'in_progress',
          'progress': 100,
          'ai_review_status': 'requested',
        },
      );
      expect(
        buildWbsKanbanUpdate(
          lane: WbsKanbanLane.completed,
          currentProgress: 20,
        ),
        <String, dynamic>{
          'status': 'completed',
          'progress': 100,
          'ai_review_status': 'manual_override',
        },
      );
    });

    test('requires and normalizes a recovery plan for blocked tasks', () {
      final now = DateTime.utc(2026, 8, 28, 6, 30);
      expect(
        () => buildWbsKanbanUpdate(
          lane: WbsKanbanLane.blocked,
          currentProgress: 40,
          recoveryPlan: '   ',
          now: now,
        ),
        throwsArgumentError,
      );

      expect(
        buildWbsKanbanUpdate(
          lane: WbsKanbanLane.blocked,
          currentProgress: 100,
          recoveryPlan: '  依存PRを確認して再開する  ',
          now: now,
        ),
        <String, dynamic>{
          'status': 'blocked',
          'progress': 99,
          'ai_review_status': 'pending',
          'recovery_plan': '依存PRを確認して再開する',
          'recovery_planned_at': '2026-08-28T06:30:00.000Z',
        },
      );
    });

    test('persists a supplied recovery plan on another open lane', () {
      final update = buildWbsKanbanUpdate(
        lane: WbsKanbanLane.inProgress,
        currentProgress: 20,
        recoveryPlan: '  期限を再確認する  ',
        now: DateTime.utc(2026, 8, 28, 7),
      );

      expect(update['recovery_plan'], '期限を再確認する');
      expect(update['recovery_planned_at'], '2026-08-28T07:00:00.000Z');
    });
  });
}
