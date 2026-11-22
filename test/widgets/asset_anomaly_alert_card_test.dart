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

  testWidgets(
    'renders critical and warning alerts with long title and restore on 320x640 without overflow',
    (tester) async {
      var restoreCalls = 0;
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AssetAlertCenterCard(
              center: const AssetAlertCenter(
                alerts: [
                  AssetAlert(
                    id: 'critical-long-1',
                    severity: AssetAlertSeverity.critical,
                    category: AssetAlertCategory.accountShortfall,
                    title: 'クレジットカード引落予定口座の残高が支払期日前に大きく不足する見込みです',
                    detail: '見込み残高 ¥-45,000 / 不足 ¥45,000。入金または資金移動を検討してください。',
                  ),
                  AssetAlert(
                    id: 'warning-1',
                    severity: AssetAlertSeverity.warning,
                    category: AssetAlertCategory.paymentDue,
                    title: '公共料金の自動引落が明日に迫っています',
                    detail: '予定支払 ¥12,800',
                  ),
                ],
                dismissedCount: 2,
              ),
              onDismiss: (_) {},
              onRestoreDismissed: () => restoreCalls += 1,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('asset_alert_center_card')), findsOneWidget);
      expect(find.text('緊急 1'), findsOneWidget);
      expect(find.text('注意 1'), findsOneWidget);
      expect(find.text('非表示 2 件を戻す'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('asset_alert_center_restore')));
      expect(restoreCalls, 1);
    },
  );

  testWidgets(
    'renders empty state with restore button in dark mode on 320x640',
    (tester) async {
      var restoreCalls = 0;
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: AssetAlertCenterCard(
              center: const AssetAlertCenter(
                alerts: <AssetAlert>[],
                dismissedCount: 3,
              ),
              onRestoreDismissed: () => restoreCalls += 1,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('asset_alert_center_card_empty')),
        findsOneWidget,
      );
      expect(find.text('対応が必要なアラートはありません。'), findsOneWidget);
      expect(find.text('非表示 3 件を戻す'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('asset_alert_center_restore_empty')),
      );
      expect(restoreCalls, 1);
    },
  );

  testWidgets(
    'renders all severities in ThemeData.dark() using theme colors',
    (tester) async {
      final darkTheme = ThemeData.dark();
      var restoreCalls = 0;
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AssetAlertCenterCard(
                center: const AssetAlertCenter(
                  alerts: [
                    AssetAlert(
                      id: 'dark-critical',
                      severity: AssetAlertSeverity.critical,
                      category: AssetAlertCategory.accountShortfall,
                      title: '残高不足の見込み',
                      detail: 'ダーク時の詳細文言',
                    ),
                    AssetAlert(
                      id: 'dark-warning',
                      severity: AssetAlertSeverity.warning,
                      category: AssetAlertCategory.paymentDue,
                      title: '支払日前リマインダー',
                      detail: '明日引落予定です',
                    ),
                    AssetAlert(
                      id: 'dark-info',
                      severity: AssetAlertSeverity.info,
                      category: AssetAlertCategory.anomaly,
                      title: '情報通知',
                      detail: '確認メモ',
                    ),
                  ],
                  dismissedCount: 1,
                ),
                onDismiss: (_) {},
                onRestoreDismissed: () => restoreCalls += 1,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('asset_alert_center_card')), findsOneWidget);
      expect(find.text('緊急 1'), findsOneWidget);
      expect(find.text('注意 1'), findsOneWidget);
      expect(find.text('情報'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final criticalIcon = tester.widget<Icon>(
        find.byIcon(Icons.error_outline),
      );
      expect(criticalIcon.color, darkTheme.colorScheme.error);

      final dismissButton = tester.widget<IconButton>(
        find.byKey(const Key('asset_alert_dismiss_dark-critical')),
      );
      expect(dismissButton.color, darkTheme.colorScheme.onSurfaceVariant);

      final detailText = tester.widget<Text>(find.text('ダーク時の詳細文言'));
      expect(detailText.style?.color, darkTheme.colorScheme.onSurfaceVariant);

      await tester.tap(find.byKey(const Key('asset_alert_center_restore')));
      expect(restoreCalls, 1);
    },
  );
}
