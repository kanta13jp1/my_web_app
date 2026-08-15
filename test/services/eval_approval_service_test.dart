import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/eval_approval_service.dart';

void main() {
  group('EvalApprovalRequest', () {
    test('parses options, background work, and downstream execution', () {
      final request = EvalApprovalRequest.fromJson({
        'id': 'approval-1',
        'status': 'approved',
        'created_at': '2026-07-17T09:00:00Z',
        'selected_option_id': 'option-b',
        'review_note': 'Risk is acceptable.',
        'preview': {
          'title': 'Release timing',
          'summary': 'Choose the deployment window.',
          'options': [
            {
              'id': 'option-a',
              'label': 'Today',
              'summary': 'Ship immediately.',
            },
            {
              'id': 'option-b',
              'label': 'Tomorrow',
              'summary': 'Use the staffed window.',
              'recommended': true,
            },
          ],
          'background_steps': [
            {'label': 'Risk review', 'status': 'completed'},
            {'label': 'CEO decision', 'status': 'running'},
          ],
        },
        'execution': {
          'status': 'completed',
          'tasks_created': 2,
          'calendar_events_created': 1,
        },
      });

      expect(request.defaultOptionId, 'option-b');
      expect(request.selectedOptionId, 'option-b');
      expect(request.options, hasLength(2));
      expect(request.backgroundSteps.last.isRunning, isTrue);
      expect(request.execution?.tasksCreated, 2);
      expect(request.execution?.calendarEventsCreated, 1);
    });
  });

  group('buildEvalApprovalDecisionBody', () {
    test('approving executes the selected plan and includes the reason', () {
      expect(
        buildEvalApprovalDecisionBody(
          requestId: ' approval-1 ',
          decision: EvalApprovalDecision.approved,
          selectedOptionId: ' option-b ',
          reason: ' staffed window ',
        ),
        {
          'action': 'saas_approval.decide',
          'request_id': 'approval-1',
          'decision': 'approved',
          'review_note': 'staffed window',
          'selected_option_id': 'option-b',
          'execute': true,
        },
      );
    });

    test('rejecting never asks the backend to execute the plan', () {
      final body = buildEvalApprovalDecisionBody(
        requestId: 'approval-1',
        decision: EvalApprovalDecision.rejected,
      );

      expect(body['decision'], 'rejected');
      expect(body['execute'], isFalse);
      expect(body, isNot(contains('selected_option_id')));
    });
  });
}
