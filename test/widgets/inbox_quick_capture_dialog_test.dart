import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/inbox_quick_capture_dialog.dart';

void main() {
  testWidgets('saves one plain-text field and closes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? savedText;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => InboxQuickCaptureDialog(
                  onSave: (text) async {
                    savedText = text;
                  },
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('inbox_quick_capture_save_button')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const Key('inbox_quick_capture_text_field')),
      '  Quick idea\nnext line  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox_quick_capture_save_button')));
    await tester.pumpAndSettle();

    expect(savedText, 'Quick idea\nnext line');
    expect(find.byType(InboxQuickCaptureDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the text available when saving fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => InboxQuickCaptureDialog(
                  onSave: (_) async => throw Exception('offline'),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('inbox_quick_capture_text_field')),
      'Do not lose this',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox_quick_capture_save_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('inbox_quick_capture_error')), findsOneWidget);
    expect(find.text('Do not lose this'), findsOneWidget);
    expect(find.byType(InboxQuickCaptureDialog), findsOneWidget);
  });
}
