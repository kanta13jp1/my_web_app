import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_alert.dart';
import 'package:my_web_app/services/asset_alert_center_service.dart';
import 'package:my_web_app/widgets/asset_alert_center_card.dart';

void main() {
  testWidgets('shows anomaly metrics and sends its stable id on dismiss', (
    tester,
  ) async {
    const id = 'anomaly_detection:detection-1';
    String? dismissedId;
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetAlertCenterCard(
            center: const AssetAlertCenter(
              alerts: [
                AssetAlert(
                  id: id,
                  severity: AssetAlertSeverity.critical,
                  category: AssetAlertCategory.anomaly,
                  title: '食費の支出に異常を検出',
                  detail: '期待値 ¥30,000 / 実績 ¥60,000 / 差分 +100.0%',
                ),
              ],
              dismissedCount: 0,
            ),
            onDismiss: (value) => dismissedId = value,
          ),
        ),
      ),
    );

    expect(find.text('緊急'), findsWidgets);
    expect(find.text('食費の支出に異常を検出'), findsOneWidget);
    expect(
      find.text('期待値 ¥30,000 / 実績 ¥60,000 / 差分 +100.0%'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('asset_alert_dismiss_$id')));
    expect(dismissedId, id);
  });
}
