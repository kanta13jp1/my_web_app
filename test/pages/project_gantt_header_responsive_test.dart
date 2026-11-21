import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

void main() {
  group('ProjectGantt responsive header and tabs', () {
    testWidgets('uses scrollable tabs on mobile width', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Builder(
              builder: (context) {
                final isCompact = MediaQuery.sizeOf(context).width < 600;
                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      '開発ロードマップ & WBS',
                      style: buildProjectGanttTitleStyle(
                        context,
                        isCompact: isCompact,
                      ),
                    ),
                    bottom: buildProjectGanttTabBar(
                      controller: DefaultTabController.of(context),
                      isCompact: isCompact,
                    ),
                  ),
                  body: const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.isScrollable, isTrue);
      expect(tabBar.tabAlignment, TabAlignment.start);
      expect(tabBar.unselectedLabelColor, const Color(0xFFB0B8C4));

      final title = tester.widget<Text>(find.text('開発ロードマップ & WBS'));
      expect(title.style?.fontSize, 16);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses fill tabs on desktop width', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 4,
            child: Builder(
              builder: (context) {
                final isCompact = MediaQuery.sizeOf(context).width < 600;
                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      '開発ロードマップ & WBS',
                      style: buildProjectGanttTitleStyle(
                        context,
                        isCompact: isCompact,
                      ),
                    ),
                    bottom: buildProjectGanttTabBar(
                      controller: DefaultTabController.of(context),
                      isCompact: isCompact,
                    ),
                  ),
                  body: const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.isScrollable, isFalse);
      expect(tabBar.tabAlignment, TabAlignment.fill);
      expect(tabBar.unselectedLabelColor, const Color(0xFFB0B8C4));

      final title = tester.widget<Text>(find.text('開発ロードマップ & WBS'));
      expect(title.style?.fontSize, 22);
      expect(tester.takeException(), isNull);
    });
  });
}
