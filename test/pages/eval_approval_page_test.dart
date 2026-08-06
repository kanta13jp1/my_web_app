import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/eval_approval_page.dart';
import 'package:my_web_app/services/eval_approval_service.dart';

void main() {
  testWidgets('selects an option, records a reason, and approves it', (
    tester,
  ) async {
    final gateway = _FakeEvalApprovalGateway();

    await tester.pumpWidget(
      MaterialApp(home: EvalApprovalPage(service: gateway)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('eval_decision_panel')), findsOneWidget);
    expect(find.text('判断待ち 1件'), findsOneWidget);
    expect(find.text('Tomorrow（推奨）'), findsOneWidget);
    expect(find.text('Use the staffed window.'), findsOneWidget);
    expect(find.text('Risk review'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await tester.pump();
    expect(find.text('Ship immediately.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('eval_reason_field')),
      'Customer impact is lower today.',
    );
    await tester.tap(find.byKey(const Key('eval_approve_button')));
    await tester.pumpAndSettle();

    expect(gateway.lastDecision, EvalApprovalDecision.approved);
    expect(gateway.lastOptionId, 'today');
    expect(gateway.lastReason, 'Customer impact is lower today.');
    expect(find.text('判断待ちはありません'), findsOneWidget);
    expect(find.text('承認済み'), findsOneWidget);
    expect(find.text('タスク2件・予定1件'), findsOneWidget);
  });

  testWidgets('rejects without executing downstream work', (tester) async {
    final gateway = _FakeEvalApprovalGateway();

    await tester.pumpWidget(
      MaterialApp(home: EvalApprovalPage(service: gateway)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eval_reject_button')));
    await tester.pumpAndSettle();

    expect(gateway.lastDecision, EvalApprovalDecision.rejected);
    expect(find.text('否認済み'), findsOneWidget);
    expect(find.text('判断待ちはありません'), findsOneWidget);
  });

  testWidgets('keeps decision controls usable on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: EvalApprovalPage(service: _FakeEvalApprovalGateway())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('eval_option_selector')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeEvalApprovalGateway implements EvalApprovalGateway {
  final EvalApprovalRequest _request = EvalApprovalRequest.fromJson({
    'id': 'approval-1',
    'status': 'pending',
    'created_at': '2026-07-17T09:00:00Z',
    'preview': {
      'title': 'Release timing',
      'summary': 'Choose the deployment window.',
      'options': [
        {'id': 'today', 'label': 'Today', 'summary': 'Ship immediately.'},
        {
          'id': 'tomorrow',
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
  });

  EvalApprovalDecision? lastDecision;
  String? lastOptionId;
  String? lastReason;

  @override
  Future<List<EvalApprovalRequest>> loadRequests() async => [_request];

  @override
  Future<EvalApprovalRequest> decide({
    required String requestId,
    required EvalApprovalDecision decision,
    String? selectedOptionId,
    String reason = '',
  }) async {
    lastDecision = decision;
    lastOptionId = selectedOptionId;
    lastReason = reason;
    return EvalApprovalRequest.fromJson({
      'id': requestId,
      'status': decision.name,
      'created_at': '2026-07-17T09:00:00Z',
      'selected_option_id': selectedOptionId,
      'review_note': reason,
      'preview': {
        'title': 'Release timing',
        'summary': 'Choose the deployment window.',
      },
      if (decision == EvalApprovalDecision.approved)
        'execution': {
          'status': 'completed',
          'tasks_created': 2,
          'calendar_events_created': 1,
        },
    });
  }
}
