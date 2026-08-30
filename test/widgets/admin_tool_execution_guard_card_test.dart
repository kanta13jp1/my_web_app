import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/admin_tool_execution_guard_card.dart';

void main() {
  Widget testApp({
    List<Map<String, dynamic>> logs = const [],
    int allowedCount = 0,
    int blockedCount = 0,
    Map<String, int> blockedReasons = const {},
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminToolExecutionGuardCard(
            toolExecutionLogs: logs,
            allowedToolExecutionCount: allowedCount,
            blockedToolExecutionCount: blockedCount,
            blockedReasonBreakdown: blockedReasons,
            currentTime: DateTime(2026, 8, 29, 12),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the migration-aware empty state', (tester) async {
    await tester.pumpWidget(testApp());

    expect(
      find.textContaining('agent_tool_execution_logs のデータがありません。'),
      findsOneWidget,
    );
    expect(find.text('Recent Tool Executions'), findsNothing);
  });

  testWidgets('renders summary, reasons, status, and timestamp freshness', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        allowedCount: 2,
        blockedCount: 1,
        blockedReasons: const {'missing_user_consent': 1},
        logs: [
          {
            'allowed': true,
            'tool_name': 'delegate_task',
            'created_at': '2026-08-29T03:04:05',
          },
          {
            'allowed': 'false',
            'tool_name': 'custom_tool',
            'blocked_reason': '',
            'created_at': '2026-06-01T03:04:05',
          },
        ],
      ),
    );

    expect(
      find.text('Blocked Rate 33.3%', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Blocked Reasons'), findsOneWidget);
    expect(find.text('missing_user_consent'), findsOneWidget);
    expect(find.text('delegate_task'), findsOneWidget);
    expect(find.text('custom_tool'), findsOneWidget);
    expect(find.text('No block reason'), findsOneWidget);
    expect(find.text('08/29 03:04:05'), findsOneWidget);
    expect(find.text('2026/06/01 03:04:05'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets('limits recent execution rows to twelve', (tester) async {
    await tester.pumpWidget(
      testApp(
        allowedCount: 13,
        logs: [
          for (var index = 0; index < 13; index++)
            {
              'allowed': 1,
              'tool_name': 'tool_$index',
              'created_at': '2026-08-29T03:04:05',
            },
        ],
      ),
    );

    expect(find.text('tool_0'), findsOneWidget);
    expect(find.text('tool_11'), findsOneWidget);
    expect(find.text('tool_12'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(12));
  });
}
