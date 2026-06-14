import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/grow_together_share.dart';
import 'package:my_web_app/widgets/grow_together_share_card.dart';

void main() {
  group('GrowTogetherShareCard', () {
    testWidgets('renders the canonical message and share controls',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowTogetherShareCard(),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('grow_together_share_card')), findsOneWidget);
      expect(
        find.text(GrowTogetherShare.fullShareMessage),
        findsOneWidget,
      );
      expect(find.text('Xでシェア'), findsOneWidget);
      expect(find.text('本文をコピー'), findsOneWidget);
    });

    testWidgets('tapping share invokes the injected share callback',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var shareCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowTogetherShareCard(
                onShareToX: () async {
                  shareCalls++;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('grow_together_share_x_button')));
      await tester.pump();

      expect(shareCalls, 1);
    });

    testWidgets('tapping copy invokes the injected copy callback',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var copyCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowTogetherShareCard(
                onCopyMessage: () async => copyCalls++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('grow_together_copy_button')));
      await tester.pump();

      expect(copyCalls, 1);
    });

    testWidgets('shows a fallback snackbar when X cannot be opened',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowTogetherShareCard(
                onShareToX: () async => false,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('grow_together_share_x_button')));
      await tester.pump();

      expect(
        find.textContaining('本文をコピーして共有してください'),
        findsOneWidget,
      );
    });
  });
}
