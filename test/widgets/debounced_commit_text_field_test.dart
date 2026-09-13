import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/debounced_commit_text_field.dart';

void main() {
  testWidgets('typing burst commits only the final value', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final commits = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DebouncedCommitTextField(
        controller: controller,
        onCommitted: commits.add,
        decoration: const InputDecoration(),
      )),
    ));
    await tester.enterText(find.byType(TextField), '1');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump(const Duration(milliseconds: 100));
    expect(commits, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(commits, ['15']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('submit flushes once and unmount cancels pending work',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final commits = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: DebouncedCommitTextField(
        controller: controller,
        onCommitted: commits.add,
        decoration: const InputDecoration(),
      )),
    ));
    await tester.enterText(find.byType(TextField), '14.6');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(commits, ['14.6']);
    await tester.pump(const Duration(milliseconds: 250));
    expect(commits, ['14.6']);
    await tester.enterText(find.byType(TextField), '15');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 250));
    expect(commits, ['14.6']);
    expect(tester.takeException(), isNull);
  });
}
