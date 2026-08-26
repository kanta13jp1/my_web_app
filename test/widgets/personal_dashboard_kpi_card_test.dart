import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/personal_dashboard_page.dart';
import 'package:my_web_app/widgets/personal_dashboard_kpi_card.dart';

void main() {
  testWidgets('long KPI content fits every responsive grid size', (
    tester,
  ) async {
    const dashboardWidths = <double>[1280, 900, 420, 320];
    const label = '非常に長いKPIカードのラベルでも内容を最後まで保持する';
    const value = '123,456,789,012.34時間';
    const subtitle = '前週から大きく変化した場合も、説明文を欠落させずカード内に収めて表示します。';

    for (final dashboardWidth in dashboardWidths) {
      final spec = personalDashboardGridSpec(dashboardWidth);
      final gridWidth = dashboardWidth - 32;
      final gapWidth = (spec.crossAxisCount - 1) * 12;
      final cardWidth = (gridWidth - gapWidth) / spec.crossAxisCount;
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
                    label: label,
                    value: value,
                    icon: Icons.monitor_heart_outlined,
                    color: Color(0xFF0891B2),
                    subtitle: subtitle,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'dashboard width $dashboardWidth must not overflow',
      );
      expect(find.text(label), findsOneWidget);
      expect(find.text(value), findsOneWidget);
      expect(find.text(subtitle), findsOneWidget);
    }
  });
}
