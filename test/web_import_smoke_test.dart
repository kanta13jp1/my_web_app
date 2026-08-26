@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/main.dart' as app;
import 'package:my_web_app/pages/ai_assistant_chat_page.dart';
import 'package:my_web_app/pages/election_victory_page.dart';
import 'package:my_web_app/pages/gemini_university_v2_page.dart';
import 'package:my_web_app/pages/guitar_recording_studio_page.dart';
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/pages/personal_dashboard_page.dart';
import 'package:my_web_app/pages/work_menu_page.dart';
import 'package:my_web_app/widgets/personal_dashboard_kpi_card.dart';

void main() {
  test('web-only app imports compile on Chrome', () {
    expect(app.MyApp, isNotNull);
    expect(HomePage, isNotNull);
    expect(WorkMenuPage, isNotNull);
    expect(AiUniversityPage, isNotNull);
    expect(ElectionVictoryPage, isNotNull);
    expect(GuitarRecordingStudioPage, isNotNull);
    expect(AiAssistantChatPage, isNotNull);
  });

  testWidgets('long personal dashboard KPI content fits in Chrome', (
    tester,
  ) async {
    const dashboardWidth = 320.0;
    final spec = personalDashboardGridSpec(dashboardWidth);
    const cardWidth = dashboardWidth - 32;
    final cardHeight = cardWidth / spec.childAspectRatio;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: cardWidth,
                height: cardHeight,
                child: const PersonalDashboardKpiCard(
                  label: '非常に長いKPIカードのラベルでも内容を最後まで保持する',
                  value: '123,456,789,012.34時間',
                  icon: Icons.monitor_heart_outlined,
                  color: Color(0xFF0891B2),
                  subtitle: '前週から大きく変化した場合も、説明文を欠落させずカード内に収めて表示します。',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
