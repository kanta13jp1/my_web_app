import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/compatibility_check_page.dart';
import 'package:my_web_app/pages/compatibility_result_page.dart';
import 'package:my_web_app/pages/competitor_browse_page.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('CompatibilityCheckPage AppBar sets black87 foreground on dark theme', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeService().getDarkTheme(),
        home: const CompatibilityCheckPage(myType: 'INTJ'),
      ),
    );
    await tester.pumpAndSettle();

    final AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFFFE0B2));
    expect(appBar.foregroundColor, Colors.black87);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CompatibilityResultPage AppBar sets black87 foreground on dark theme', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeService().getDarkTheme(),
        home: const CompatibilityResultPage(
          myType: 'INTJ',
          partnerType: 'ENFP',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFFFFE0B2));
    expect(appBar.foregroundColor, Colors.black87);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CompetitorBrowsePage AppBar sets white foreground on light theme', (
    final WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeService().getLightTheme(),
        home: CompetitorBrowsePage(
          loader: () async => const <Map<String, dynamic>>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final AppBar appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, const Color(0xFF1A1830));
    expect(appBar.foregroundColor, Colors.white);
    expect(tester.takeException(), isNull);
  });

  test('all 13 fixed pages declare explicit AppBar foregroundColor contract', () {
    const List<String> darkAppBarPages = <String>[
      'lib/pages/agent_board_page.dart',
      'lib/pages/agent_gpa_dashboard_page.dart',
      'lib/pages/ai_observability_page.dart',
      'lib/pages/ai_provider_status_page.dart',
      'lib/pages/ai_router_cost_dashboard_page.dart',
      'lib/pages/autonomous_ops_console_page.dart',
      'lib/pages/horse_racing_predictor_page.dart',
      'lib/pages/social_media_scheduler_page.dart',
      'lib/pages/task_budget_assistant_page.dart',
      'lib/pages/public_guitar_gallery_page.dart',
      'lib/pages/competitor_browse_page.dart',
    ];
    const List<String> lightAmberAppBarPages = <String>[
      'lib/pages/compatibility_check_page.dart',
      'lib/pages/compatibility_result_page.dart',
    ];

    for (final String path in darkAppBarPages) {
      final String src = File(path).readAsStringSync();
      expect(
        src,
        contains('foregroundColor: Colors.white,'),
        reason: '$path should specify white AppBar foregroundColor',
      );
    }
    for (final String path in lightAmberAppBarPages) {
      final String src = File(path).readAsStringSync();
      expect(
        src,
        contains('foregroundColor: Colors.black87,'),
        reason: '$path should specify black87 AppBar foregroundColor',
      );
    }
    final String horseSrc = File(
      'lib/pages/horse_racing_predictor_page.dart',
    ).readAsStringSync();
    expect(horseSrc, contains('labelColor: Colors.white,'));
    expect(horseSrc, contains('unselectedLabelColor: Colors.white70,'));
  });
}
