import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/note_editor/note_range_select_page.dart';

void main() {
  group('NoteRangeSelectPage', () {
    String? mockClipboard;

    void installClipboardMock() {
      mockClipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>?;
          mockClipboard = args?['text'] as String?;
          return null;
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
    }

    testWidgets('ワンタップコピーと文字単位微調整・反映が動作する', (tester) async {
      installClipboardMock();
      const body = 'ユーザー名: alice_01\nパスワード: sec-99-xyz';
      TextSelection? returned;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  returned = await openNoteRangeSelectPage(
                    context: context,
                    text: body,
                    initialSelection: const TextSelection(
                      baseOffset: 0,
                      extentOffset: body.length,
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('note_range_select_page')), findsOneWidget);

      await tester.tap(find.byKey(const Key('note_range_mode_precision')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('note_range_quick_copy_1')));
      await tester.pumpAndSettle();
      expect(mockClipboard, 'sec-99-xyz');

      final startPlus = find.byKey(const Key('note_range_start_plus_1'));
      final endMinus = find.byKey(const Key('note_range_end_minus_1'));
      await tester.ensureVisible(startPlus);
      await tester.tap(startPlus);
      await tester.pump();
      await tester.ensureVisible(endMinus);
      await tester.tap(endMinus);
      await tester.pump();

      final precisionCopy = find.byKey(
        const Key('note_range_precision_copy_button'),
      );
      await tester.ensureVisible(precisionCopy);
      await tester.tap(precisionCopy);
      await tester.pumpAndSettle();
      expect(mockClipboard, body.substring(1, body.length - 1));

      final applyButton = find.byKey(
        const Key('note_range_precision_apply_button'),
      );
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();
      expect(
        returned,
        const TextSelection(baseOffset: 1, extentOffset: body.length - 1),
      );
    });

    testWidgets('狭幅 390x844 と空文字でもオーバーフローしない', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: NoteRangeSelectPage(
            text: '',
            initialSelection: TextSelection.collapsed(offset: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('note_range_mode_precision')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
