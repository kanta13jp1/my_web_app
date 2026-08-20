import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_dashboard_grid.dart';

Widget _host(Widget child, {double width = 1200}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(width: width, child: SingleChildScrollView(child: child)),
    ),
  );
}

AssetDashboardPanel _panel(String title, {VoidCallback? onDetail}) {
  return AssetDashboardPanel(
    title: title,
    onOpenDetail: onDetail,
    child: SizedBox(key: Key('body_$title'), height: 40),
  );
}

void main() {
  group('dashboardColumnCountFor', () {
    test('mobile widths use a single column', () {
      expect(dashboardColumnCountFor(360), 1);
      expect(dashboardColumnCountFor(719.9), 1);
    });

    test('wide widths use two columns', () {
      expect(dashboardColumnCountFor(720), 2);
      expect(dashboardColumnCountFor(1440), 2);
    });

    test('degenerate widths fall back to one column', () {
      expect(dashboardColumnCountFor(0), 1);
      expect(dashboardColumnCountFor(-10), 1);
      expect(dashboardColumnCountFor(double.infinity), 1);
      expect(dashboardColumnCountFor(double.nan), 1);
    });

    test('breakpoint is configurable', () {
      expect(dashboardColumnCountFor(500, breakpoint: 480), 2);
      expect(dashboardColumnCountFor(500, breakpoint: 900), 1);
    });
  });

  group('AssetDashboardGrid', () {
    testWidgets('renders nothing when there are no panels', (tester) async {
      await tester.pumpWidget(
        _host(const AssetDashboardGrid(panels: <AssetDashboardPanel>[])),
      );
      expect(find.byType(Row), findsNothing);
    });

    testWidgets('renders every provided panel with its title', (tester) async {
      await tester.pumpWidget(
        _host(
          AssetDashboardGrid(
            panels: [_panel('純資産'), _panel('キャッシュフロー'), _panel('アラート')],
          ),
        ),
      );

      expect(find.text('純資産'), findsOneWidget);
      expect(find.text('キャッシュフロー'), findsOneWidget);
      expect(find.text('アラート'), findsOneWidget);
      expect(find.byKey(const Key('body_純資産')), findsOneWidget);
      expect(find.byKey(const Key('body_アラート')), findsOneWidget);
    });

    testWidgets('omitted panels leave no empty cell (投資 未実装ケース)',
        (tester) async {
      // 投資パネルを渡さない = 第2弾B 未着地の状態。
      await tester.pumpWidget(
        _host(
          AssetDashboardGrid(
            panels: [_panel('純資産'), _panel('キャッシュフロー'), _panel('アラート')],
          ),
        ),
      );
      expect(find.text('投資'), findsNothing);
      // 3 枚とも本体が描画されている。
      for (final t in ['純資産', 'キャッシュフロー', 'アラート']) {
        expect(find.byKey(Key('body_$t')), findsOneWidget);
      }
    });

    testWidgets('detail link is shown only when a callback is given',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          AssetDashboardGrid(
            panels: [
              _panel('純資産', onDetail: () => tapped++),
              _panel('アラート'),
            ],
          ),
        ),
      );

      expect(
        find.byKey(const Key('asset_dashboard_detail_純資産')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_dashboard_detail_アラート')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('asset_dashboard_detail_純資産')));
      await tester.pump();
      expect(tapped, 1);
    });

    testWidgets('narrow viewport stacks panels in one column', (tester) async {
      await tester.pumpWidget(
        _host(
          AssetDashboardGrid(panels: [_panel('A'), _panel('B')]),
          width: 400,
        ),
      );
      expect(find.byKey(const Key('body_A')), findsOneWidget);
      expect(find.byKey(const Key('body_B')), findsOneWidget);
      // 1 列では縦積み: 左端が揃い、B が A より下に来る。
      final a = tester.getTopLeft(find.byKey(const Key('body_A')));
      final b = tester.getTopLeft(find.byKey(const Key('body_B')));
      expect(b.dx, closeTo(a.dx, 0.5));
      expect(b.dy, greaterThan(a.dy));
    });

    testWidgets('wide viewport lays panels out two per row', (tester) async {
      await tester.pumpWidget(
        _host(
          AssetDashboardGrid(panels: [_panel('A'), _panel('B')]),
          width: 1000,
        ),
      );
      // 2 列では横並び: B が A の右、かつ同じ行 (上端が揃う)。
      final a = tester.getTopLeft(find.byKey(const Key('body_A')));
      final b = tester.getTopLeft(find.byKey(const Key('body_B')));
      expect(b.dx, greaterThan(a.dx));
      expect(b.dy, closeTo(a.dy, 0.5));
    });

    testWidgets('odd panel count keeps the last panel at half width',
        (tester) async {
      await tester.pumpWidget(
        _host(
          AssetDashboardGrid(panels: [_panel('A'), _panel('B'), _panel('C')]),
          width: 1000,
        ),
      );
      final bWidth = tester.getSize(find.byKey(const Key('body_B'))).width;
      final cWidth = tester.getSize(find.byKey(const Key('body_C'))).width;
      // 端数の C が横幅いっぱいに伸びず、B と同じ幅に収まる。
      expect(cWidth, closeTo(bWidth, 1.0));
    });
  });
}
