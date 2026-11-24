import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/collapsible_home_section.dart';
import 'package:my_web_app/widgets/home_curated_calendar_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildSampleCalendarChild() {
  return Container(
    key: const Key('sample_home_calendar_panel'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFB0B0B0)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2026年11月', key: Key('home_calendar_month_label')),
        SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            Text('収入'),
            Text('支出'),
            Text('借入/違反'),
          ],
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Case 1 (happy path, desktop): expands curated calendar by default, meets a11y, and navigates to /asset-management',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1280, 2200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            routes: <String, WidgetBuilder>{
              '/asset-management': (_) => const Scaffold(
                    body: Text('Asset Management Calendar Route'),
                  ),
            },
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Builder(
                  builder: (context) => HomeCuratedCalendarSection(
                    isCompact: false,
                    calendarChild: _buildSampleCalendarChild(),
                    onOpenAssetManagement: () =>
                        Navigator.of(context).pushNamed('/asset-management'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final section = tester.widget<CollapsibleHomeSection>(
          find.byKey(const Key('home_curated_operations_calendar')),
        );
        expect(section.initiallyExpanded, isTrue);
        expect(find.text('月次カレンダー（収支・借入/違反）'), findsOneWidget);
        expect(find.text('2026年11月'), findsOneWidget);
        expect(find.text('借入/違反'), findsOneWidget);

        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        final button = find.byKey(
          const Key('home_curated_calendar_open_asset_management_button'),
        );
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.text('Asset Management Calendar Route'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Case 2 (compact mobile & expand recovery): starts collapsed, expands on tap, and persists SharedPreferences',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: HomeCuratedCalendarSection(
                isCompact: true,
                calendarChild: _buildSampleCalendarChild(),
                onOpenAssetManagement: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final section = tester.widget<CollapsibleHomeSection>(
        find.byKey(const Key('home_curated_operations_calendar')),
      );
      expect(section.initiallyExpanded, isFalse);
      expect(find.text('月次カレンダー（収支・借入/違反）'), findsOneWidget);
      expect(find.text('借入/違反'), findsNothing);

      await tester.tap(find.text('月次カレンダー（収支・借入/違反）'));
      await tester.pumpAndSettle();

      expect(find.text('借入/違反'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('home_curated_operations_calendar'), isTrue);
    },
  );

  testWidgets(
    'Case 3 (dark mode, 2.0x text scale, toggle recovery, and home_page.dart contract)',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: HomeCuratedCalendarSection(
                    isCompact: false,
                    calendarChild: _buildSampleCalendarChild(),
                    onOpenAssetManagement: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('借入/違反'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await tester.tap(find.text('月次カレンダー（収支・借入/違反）'));
        await tester.pumpAndSettle();
        expect(find.text('借入/違反'), findsNothing);

        await tester.tap(find.text('月次カレンダー（収支・借入/違反）'));
        await tester.pumpAndSettle();
        expect(find.text('借入/違反'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }

      final homeSource = File('lib/pages/home_page.dart').readAsStringSync();
      expect(
        homeSource,
        contains('static const bool _showLegacyHomeSections = false;'),
      );
      expect(homeSource, contains('if (!showInternalOperations) ...['));
      expect(homeSource, contains('HomeCuratedCalendarSection('));
    },
  );
}
