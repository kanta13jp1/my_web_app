import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/services/supabase_resource_simulator_service.dart';
import 'package:my_web_app/widgets/supabase_resource_simulator_panel.dart';

void main() {
  group('SupabaseResourceSimulatorService', () {
    test(
      'computes normal, warning (>=80%), and overage (>100%) quotas for Free tier',
      () {
        final normal = SupabaseResourceSimulatorCalculator.evaluate(
          const SupabaseResourceInputs(),
        );
        expect(normal.hasWarning, isFalse);
        expect(normal.hasOverage, isFalse);
        expect(normal.estimatedTotalUsd, 0.0);
        expect(normal.alerts.single, contains('7 日間'));

        final warning = SupabaseResourceSimulatorCalculator.evaluate(
          const SupabaseResourceInputs(
            planTier: SupabasePlanTier.free,
            mau: 45000,
            avgDbMbPerUser: 0.008,
            avgEgressMbPerUser: 0.05,
            storageGb: 0.5,
          ),
        );
        expect(warning.hasWarning, isTrue);
        expect(warning.hasOverage, isFalse);
        final mauMetric = warning.metrics.firstWhere((m) => m.id == 'auth_mau');
        expect(mauMetric.utilizationPercent, 90.0);
        expect(mauMetric.thresholdLevel, QuotaThresholdLevel.warning);

        final overage = SupabaseResourceSimulatorCalculator.evaluate(
          const SupabaseResourceInputs(
            planTier: SupabasePlanTier.free,
            mau: 60000,
            avgDbMbPerUser: 0.01,
            avgEgressMbPerUser: 0.1,
            storageGb: 1.5,
          ),
        );
        expect(overage.hasWarning, isTrue);
        expect(overage.hasOverage, isTrue);
        expect(overage.alerts.any((a) => a.contains('Free 上限')), isTrue);
      },
    );

    test(
      'computes Pro tier base USD 25.00 and verified overage rates accurately',
      () {
        final proOverage = SupabaseResourceSimulatorCalculator.evaluate(
          const SupabaseResourceInputs(
            planTier: SupabasePlanTier.pro,
            mau: 120000,
            avgDbMbPerUser: 0.1,
            avgEgressMbPerUser: 2.5,
            storageGb: 120.0,
          ),
        );
        // MAU excess: 20,000 * 0.00325 = 65.00
        // DB: 12,000 MB -> 4,000 MB (4 GB) excess * 0.125 = 0.50
        // Egress: 300 GB -> 50 GB excess * 0.09 = 4.50
        // Storage: 120 GB -> 20 GB excess * 0.0213 = 0.426
        expect(proOverage.hasOverage, isTrue);
        expect(proOverage.estimatedOverageUsd, closeTo(70.426, 0.0001));
        expect(proOverage.estimatedTotalUsd, closeTo(95.426, 0.0001));
        expect(proOverage.alerts.any((a) => a.contains('7 日間')), isFalse);
      },
    );

    test(
      'controller notifies listeners on updates and ignores calls after dispose',
      () {
        final controller = SupabaseResourceSimulatorController();
        var notifications = 0;
        controller.addListener(() {
          notifications += 1;
        });

        controller.setMau(45000);
        expect(notifications, 1);
        expect(controller.result.hasWarning, isTrue);

        controller.setPlanTier(SupabasePlanTier.pro);
        expect(notifications, 2);
        expect(controller.result.estimatedTotalUsd, 25.0);

        controller.dispose();
        controller.setStorageGb(200.0);
        expect(notifications, 2);
      },
    );
  });

  group('SupabaseResourceSimulatorPanel Widget & A11y', () {
    testWidgets(
      'updates prediction bars and warning/overage alerts interactively on slider and tier changes',
      (WidgetTester tester) async {
        final controller = SupabaseResourceSimulatorController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SupabaseResourceSimulatorPanel(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('全リソース項目が 80% 未満の安全圏内です'),
          findsOneWidget,
        );
        expect(find.textContaining('推定月額合計: USD 0.00 / 月'), findsOneWidget);

        controller.setStorageGb(1.5);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('警告: 設定されたプランクォータを超過しています'),
          findsOneWidget,
        );

        final proButton =
            find.byKey(const ValueKey<String>('sim_plan_pro_button'));
        await tester.ensureVisible(proButton);
        await tester.tap(proButton);
        await tester.pumpAndSettle();
        expect(find.textContaining('推定月額合計: USD 25.00 / 月'), findsOneWidget);
        expect(
          find.textContaining('全リソース項目が 80% 未満の安全圏内です'),
          findsOneWidget,
        );

        final storageSlider =
            find.byKey(const ValueKey<String>('sim_storage_slider'));
        await tester.ensureVisible(storageSlider);
        await tester.drag(storageSlider, const Offset(250, 0));
        await tester.pumpAndSettle();
        expect(controller.inputs.storageGb, greaterThan(1.5));

        final resetBtn = find.byKey(const ValueKey<String>('sim_reset_button'));
        await tester.ensureVisible(resetBtn);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();
        expect(controller.inputs.planTier, SupabasePlanTier.free);
        expect(controller.inputs.mau, 12000);
      },
    );

    for (final viewport in const <Size>[Size(390, 844), Size(1280, 800)]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
          (WidgetTester tester) async {
            final a11yHandle = tester.ensureSemantics();
            addTearDown(a11yHandle.dispose);
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final theme = brightness == Brightness.dark
                  ? ThemeData.dark()
                  : ThemeData.light();
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    '${viewport.width.toInt()}_${brightness.name}',
                  ),
                  theme: theme,
                  home: Builder(
                    builder: (BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          size: viewport,
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: const Scaffold(
                          body: SingleChildScrollView(
                            child: SupabaseResourceSimulatorPanel(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();

              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(textContrastGuideline),
              );
            } finally {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
