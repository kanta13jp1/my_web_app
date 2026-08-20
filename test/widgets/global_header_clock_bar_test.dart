import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/release_notes_page.dart';
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

  testWidgets('public shell omits internal clock and build chrome', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlobalHeaderClockShell(
          showClockBar: false,
          child: Scaffold(
            body: Center(child: Text('public landing page')),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('global_header_clock_bar')), findsNothing);
    expect(find.byKey(const Key('global_header_clock_text')), findsNothing);
    expect(find.text('public landing page'), findsOneWidget);
  });

  testWidgets('compact viewport omits internal clock and build chrome', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: GlobalHeaderClockShell(
          child: Scaffold(body: Text('mobile page')),
        ),
      ),
    );

    expect(find.byKey(const Key('global_header_clock_bar')), findsNothing);
    expect(find.byKey(const Key('global_header_version_badge')), findsNothing);
    expect(find.text('mobile page'), findsOneWidget);
  });

  testWidgets(
    'version badge opens the release notes dialog via navigatorKey when the '
    'header is mounted above the Navigator (MaterialApp.builder)',
    (WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('HOME')),
          // 本番(main.dart)と同じく Navigator(child)より上にヘッダーを置く。
          // このとき `Navigator.of(context)` は祖先 Navigator を見つけられず
          // release ビルドで null-check 例外になる(#3511)。ダイアログは
          // navigatorKey の context 上で開くことで回避する。
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

      expect(find.byType(ReleaseNotesPage), findsNothing);

      await tester.tap(find.byKey(const Key('global_header_version_badge')));
      await tester.pump(); // ダイアログ route push
      await tester.pump(const Duration(milliseconds: 300)); // フェード遷移

      // リリースノートがポップアップ(ダイアログ)で開き、閉じるボタンを備える。
      expect(find.byType(ReleaseNotesPage), findsOneWidget);
      expect(
        find.byKey(const Key('release_notes_close_button')),
        findsOneWidget,
      );

      // 周期タイマー(時計)を止めるため後始末でアンマウントする。
      await tester.pumpWidget(const SizedBox());
    },
  );
}
