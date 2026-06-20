import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/global_header_clock_bar.dart';

void main() {
  testWidgets('GlobalHeaderClockShell shows clock and wrapped child', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlobalHeaderClockShell(
          child: Scaffold(
            body: Center(child: Text('dummy page')),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('global_header_clock_bar')), findsOneWidget);
    expect(find.byKey(const Key('global_header_clock_text')), findsOneWidget);
    expect(find.text('dummy page'), findsOneWidget);
  });

  testWidgets(
    'version badge opens release notes via navigatorKey when the header is '
    'mounted above the Navigator (MaterialApp.builder)',
    (WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          onGenerateRoute: (settings) {
            if (settings.name == '/release-notes') {
              return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('RELEASE_NOTES')),
              );
            }
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('HOME')),
            );
          },
          // 本番(main.dart)と同じく Navigator(child)より上にヘッダーを置く。
          // このとき `Navigator.of(context)` は祖先 Navigator を見つけられず
          // release ビルドで null-check 例外になる(修正前の不具合)。
          builder: (context, child) {
            return Column(
              children: [
                GlobalHeaderClockBar(navigatorKey: navigatorKey),
                Expanded(child: child ?? const SizedBox.shrink()),
              ],
            );
          },
        ),
      );
      await tester.pump();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('RELEASE_NOTES'), findsNothing);

      await tester.tap(find.byKey(const Key('global_header_version_badge')));
      await tester.pump(); // ルート push 開始
      await tester.pump(const Duration(milliseconds: 400)); // 遷移完了

      expect(find.text('RELEASE_NOTES'), findsOneWidget);

      // 周期タイマー(時計)を止めるため後始末でアンマウントする。
      await tester.pumpWidget(const SizedBox());
    },
  );
}
