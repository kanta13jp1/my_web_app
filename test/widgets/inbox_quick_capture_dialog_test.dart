import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/inbox_quick_capture_dialog.dart';

Future<void> openDialog(WidgetTester tester, TargetPlatform platform,
    Future<void> Function(String) save) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: platform),
    home: Builder(
        builder: (context) => Scaffold(
                body: TextButton(
              onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => InboxQuickCaptureDialog(onSave: save)),
              child: const Text('open'),
            ))),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows
  ]) {
    testWidgets('$platform: back keeps draft until explicit discard',
        (tester) async {
      var calls = 0;
      await openDialog(tester, platform, (_) async {
        calls++;
      });
      await tester.enterText(find.byType(TextField), 'draft');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('入力したメモを破棄しますか？'), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing);
      await tester.tap(find.text('入力を続ける'));
      await tester.pumpAndSettle();
      expect(find.text('draft'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('破棄する'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxQuickCaptureDialog), findsNothing);
      expect(calls, 0);
    });
    testWidgets(
        '$platform: pending save blocks back, barrier and edits; retry works',
        (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      String? submitted;
      await openDialog(tester, platform, (text) async {
        calls++;
        submitted = text;
        if (calls == 1) await pending.future;
      });
      await tester.enterText(find.byType(TextField), '  retained  ');
      await tester.pump();
      await tester
          .tap(find.byKey(const Key('inbox_quick_capture_save_button')));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(InboxQuickCaptureDialog), findsOneWidget);
      expect(find.text('入力したメモを破棄しますか？'), findsNothing);
      expect(calls, 1);
      pending.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text('  retained  '), findsOneWidget);
      expect(
          find.byKey(const Key('inbox_quick_capture_error')), findsOneWidget);
      await tester
          .tap(find.byKey(const Key('inbox_quick_capture_save_button')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(submitted, 'retained');
      expect(find.byType(InboxQuickCaptureDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$platform: narrow keyboard inset keeps actions reachable',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      await openDialog(tester, platform, (_) async {});
      await tester.enterText(find.byType(TextField), 'memo');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
          find.byKey(const Key('inbox_quick_capture_save_button')));
      await tester
          .tap(find.byKey(const Key('inbox_quick_capture_save_button')));
      await tester.pumpAndSettle();
      expect(find.byType(InboxQuickCaptureDialog), findsNothing);
    });
  }

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
