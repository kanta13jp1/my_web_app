import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/route_visibility_observer.dart';

// HomePage / LandingPage は共有 observer `deepLinkVisibilityRouteObserver` と
// 「不可視の間は fetch/計測を開始せず、可視になった瞬間 (didPopNext) に一度だけ
// 開始する」RouteAware ライフサイクルに依存する。HomePage 実体はアプリ全体を
// 推移的に import し browser バンドルが巨大で読めないため、ここでは同じ observer
// と同じライフサイクルを持つ軽量プローブでその契約を VM 上で検証する
// (HomePage/LandingPage 側の配線同一性は flutter analyze が担保する)。
class _VisibilityProbe extends StatefulWidget {
  final void Function() onVisibleBootstrap;
  const _VisibilityProbe({required this.onVisibleBootstrap});

  @override
  State<_VisibilityProbe> createState() => _VisibilityProbeState();
}

class _VisibilityProbeState extends State<_VisibilityProbe> with RouteAware {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      deepLinkVisibilityRouteObserver.subscribe(this, route);
    }
    if (route == null || route.isCurrent) {
      _startOnce();
    }
  }

  @override
  void didPopNext() {
    _startOnce();
  }

  void _startOnce() {
    if (_started) return;
    _started = true;
    widget.onVisibleBootstrap();
  }

  @override
  void dispose() {
    deepLinkVisibilityRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 可視化ゲート: 不可視の間は本体を build しない。
    if (!_started) return const SizedBox.shrink();
    return const Text('PROBE_BODY');
  }
}

void main() {
  testWidgets(
    'deep link で下に積まれた間は bootstrap を開始せず本体も build しない',
    (WidgetTester tester) async {
      var bootstrapCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[
            deepLinkVisibilityRouteObserver,
          ],
          initialRoute: '/second',
          onGenerateRoute: (settings) {
            if (settings.name == '/second') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(
                        tester.element(find.text('POP_ME')),
                      ).pop(),
                      child: const Text('POP_ME'),
                    ),
                  ),
                ),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => _VisibilityProbe(
                onVisibleBootstrap: () => bootstrapCalls += 1,
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // 上のルートが可視。下のプローブは不可視。
      expect(find.text('POP_ME'), findsOneWidget);
      // 不可視なので bootstrap は未実行・本体も未 build。
      expect(bootstrapCalls, 0);
      expect(find.text('PROBE_BODY'), findsNothing);

      // 上のルートを pop → プローブが初めて可視に。
      await tester.tap(find.text('POP_ME'));
      await tester.pumpAndSettle();

      // 可視化した瞬間に一度だけ bootstrap 実行・本体 build。
      expect(bootstrapCalls, 1);
      expect(find.text('PROBE_BODY'), findsOneWidget);
    },
  );

  testWidgets(
    '最初から可視 (単独ルート) なら即 bootstrap する',
    (WidgetTester tester) async {
      var bootstrapCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[
            deepLinkVisibilityRouteObserver,
          ],
          home: _VisibilityProbe(
            onVisibleBootstrap: () => bootstrapCalls += 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(bootstrapCalls, 1);
      expect(find.text('PROBE_BODY'), findsOneWidget);
    },
  );
}
