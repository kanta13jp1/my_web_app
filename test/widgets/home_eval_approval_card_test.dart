import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_eval_approval_card.dart';

void main() {
  const mobileViewport = Size(360, 800);

  Widget wrapMobile2x(Widget child, {ThemeData? theme}) {
    return MediaQuery(
      data: const MediaQueryData(
        size: mobileViewport,
        textScaler: TextScaler.linear(2.0),
      ),
      child: MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('HomeEvalApprovalCard @ 360x800 2.0x', () {
    testWidgets('renders title, subtitle and fires onTap without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = 0;
      await tester.pumpWidget(
        wrapMobile2x(HomeEvalApprovalCard(onTap: () => tapped++)),
      );
      await tester.pumpAndSettle();

      expect(find.text('CEO Eval'), findsOneWidget);
      expect(find.text('AI役員から届いた選択肢を承認・否認'), findsOneWidget);
      expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.ensureVisible(find.text('CEO Eval'));
      await tester.tap(find.text('CEO Eval'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders in dark theme and trailing chevron tap fires onTap',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var tapped = 0;
      await tester.pumpWidget(
        wrapMobile2x(
          HomeEvalApprovalCard(onTap: () => tapped++),
          theme: ThemeData.dark(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CEO Eval'), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.chevron_right));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(tapped, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
