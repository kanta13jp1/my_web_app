import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/career_monthly_kpi.dart';
import 'package:my_web_app/models/self_mental_health_check.dart';
import 'package:my_web_app/pages/career_monthly_kpi_page.dart';
import 'package:my_web_app/services/career_monthly_kpi_service.dart';
import 'package:my_web_app/services/self_mental_health_risk_service.dart';
import 'package:my_web_app/services/self_skill_asset_service.dart';
import 'package:my_web_app/widgets/self_mental_health_risk_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryCareerMonthlyKpiService extends CareerMonthlyKpiService {
  final List<CareerMonthlyKpi> seed;

  _InMemoryCareerMonthlyKpiService(this.seed);

  @override
  Future<List<CareerMonthlyKpi>> list() async => seed;
}

void main() {
  group(
      'SelfMentalHealthRiskPanel & CareerMonthlyKpiPage (#1393 / #2771 / #2772)',
      () {
    testWidgets(
        'records 1-tap emoji mood/fatigue check and triggers burnout alert banner',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final now = DateTime(2026, 11, 23);
        final prior = <SelfMentalHealthCheck>[
          SelfMentalHealthCheck(
            dateKey: '2026-11-21',
            moodScore: 2,
            fatigueScore: 4,
            recordedAt: DateTime(2026, 11, 21),
          ),
          SelfMentalHealthCheck(
            dateKey: '2026-11-22',
            moodScore: 2,
            fatigueScore: 5,
            recordedAt: DateTime(2026, 11, 22),
          ),
        ];
        SharedPreferences.setMockInitialValues(<String, Object>{
          SelfMentalHealthRiskService.defaultPrefsKey:
              jsonEncode(prior.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelfMentalHealthRiskPanel(debugNow: now),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only 2 prior entries: status banner (low), no alert yet.
        expect(
          find.byKey(const Key('mental_burnout_status_banner')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('mental_mood_chip_1')));
        await tester.tap(find.byKey(const Key('mental_fatigue_chip_5')));
        await tester.enterText(
          find.byKey(const Key('mental_check_note_input')),
          '連続稼働で睡眠不足',
        );
        await tester.tap(find.byKey(const Key('mental_check_save_button')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('mental_burnout_alert_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('過労・バーンアウト警戒'), findsOneWidget);
        expect(find.textContaining('医療上の診断'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
        'renders closing report snapshot trigger and mental health panel in CareerMonthlyKpiPage',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final now = DateTime(2026, 11, 23);
      final kpiService = _InMemoryCareerMonthlyKpiService(
        const <CareerMonthlyKpi>[
          CareerMonthlyKpi(
            id: 'kpi-1',
            monthKey: '2026-11',
            annualGoal: '個人会社安定黒字化',
            category: 'career',
            metricName: '月次成果物',
            targetValue: 2,
            actualValue: 2,
            unit: '件',
          ),
        ],
      );
      final skillService = SelfSkillAssetService(
        storage: SharedPreferencesSelfSkillAssetStorage(
          userScope: 'kpi_close_test',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CareerMonthlyKpiPage(
            kpiService: kpiService,
            skillAssetService: skillService,
            debugNow: now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final genBtn = find.byKey(const Key('career_kpi_generate_close_button'));
      expect(genBtn, findsOneWidget);
      await tester.tap(genBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('最新確定: 2026-11'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('self_mental_health_risk_card')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.byKey(const Key('self_mental_health_risk_card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
