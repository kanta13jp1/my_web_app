import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/task_clarity_service.dart';
import 'package:my_web_app/widgets/task_clarity_dialog.dart';

void main() {
  testWidgets('task clarification controls have accessible labels and contrast',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final evaluation = TaskClarityEvaluation.fromJson(<String, dynamic>{
        'score': 3,
        'threshold': 6,
        'source': 'test',
        'questions': <String>['期限は？', '完了条件は？'],
        'evaluated_at': '2026-07-20T00:00:00Z',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskClarityDialog(evaluation: evaluation),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('期限は？'), findsOneWidget);
      expect(find.text('完了条件は？'), findsOneWidget);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
