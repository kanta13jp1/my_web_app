import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_emotion_dashboard/ai_emotion_dashboard_container.dart';
import 'package:my_web_app/features/ai_emotion_dashboard/application/ai_emotion_controller.dart';
import 'package:my_web_app/features/ai_emotion_dashboard/domain/ai_emotion_models.dart';
import 'package:my_web_app/pages/enterprise_page.dart';

class _InMemoryAiEmotionRepository implements AiEmotionRepository {
  final List<AiEmotionLogEntry> logs = <AiEmotionLogEntry>[];
  final List<AiEmotionAlertEntry> alerts = <AiEmotionAlertEntry>[];
  int _seq = 0;

  @override
  Future<AiEmotionDashboardSnapshot> listDashboard({
    final FunctionalEmotionCategory? toneFilter,
    final double? threshold,
  }) async {
    final filtered = toneFilter == null
        ? List<AiEmotionLogEntry>.from(logs)
        : logs.where((final item) => item.tone == toneFilter).toList();
    return _snapshot(filtered, threshold ?? 0.7);
  }

  @override
  Future<AiEmotionDashboardSnapshot> seedDefaults({
    final double? threshold,
  }) async {
    if (logs.isEmpty) {
      await classifyAndLog(
        responseText: '落ち着いて手順を段階的に確認しましょう。',
        model: 'gemini-2.5-flash',
        alertThreshold: threshold,
      );
      await classifyAndLog(
        responseText: '今すぐ至急修正しないとパニックで崩壊します！!',
        model: 'claude-sonnet-4',
        alertThreshold: threshold,
      );
    }
    return _snapshot(List<AiEmotionLogEntry>.from(logs), threshold ?? 0.7);
  }

  @override
  Future<AiEmotionLogEntry> classifyAndLog({
    required final String responseText,
    required final String model,
    final String sourceAction = 'manual_eval',
    final double? alertThreshold,
  }) async {
    _seq += 1;
    final limit = alertThreshold ?? 0.7;
    final lower = responseText.toLowerCase();
    final isPanic = lower.contains('パニック') || lower.contains('panic');
    final isUrgent = lower.contains('至急') || lower.contains('今すぐ');
    final tone = isPanic
        ? FunctionalEmotionCategory.panic
        : isUrgent
            ? FunctionalEmotionCategory.urgency
            : FunctionalEmotionCategory.calm;
    final score = isPanic
        ? 0.90
        : isUrgent
            ? 0.80
            : 0.70;
    final exceeded = tone.isAlertable && score >= limit;
    final now = DateTime.utc(2026, 11, 25, 10 + (_seq % 10));

    final entry = AiEmotionLogEntry(
      id: 'emo-log-$_seq',
      model: model,
      sourceAction: sourceAction,
      responseExcerpt: responseText,
      tone: tone,
      score: score,
      alertThreshold: limit,
      thresholdExceeded: exceeded,
      alertSeverity: exceeded ? 'critical' : 'none',
      needsVerification: true,
      verificationNote: '要検証: Anthropic研究に基づく機能的感情の外部表現分類であり、内部ニューロン監視ではありません。',
      matchedSignals: <String>['${tone.apiValue}:sample'],
      recordedAt: now,
    );
    logs.insert(0, entry);

    if (exceeded) {
      alerts.insert(
        0,
        AiEmotionAlertEntry(
          id: 'emo-alert-$_seq',
          logId: entry.id,
          model: model,
          tone: tone,
          score: score,
          threshold: limit,
          severity: 'critical',
          message: '「${tone.label}」閾値超過検知',
          needsVerification: true,
          notified: true,
          triggeredAt: now,
        ),
      );
    }
    return entry;
  }

  AiEmotionDashboardSnapshot _snapshot(
    final List<AiEmotionLogEntry> visibleLogs,
    final double threshold,
  ) {
    final counts = <FunctionalEmotionCategory, int>{
      for (final cat in FunctionalEmotionCategory.values) cat: 0,
    };
    var overCount = 0;
    for (final l in logs) {
      counts[l.tone] = (counts[l.tone] ?? 0) + 1;
      if (l.thresholdExceeded) overCount += 1;
    }
    final timeline = <EmotionTimeBucket>[
      for (var i = 0; i < logs.length; i++)
        EmotionTimeBucket(
          bucketLabel: '11-25 ${10 + i}:00',
          totalCount: 1,
          alertCount: logs[i].thresholdExceeded ? 1 : 0,
          dominantTone: logs[i].tone,
          avgUrgencyScore: logs[i].score,
          toneCounts: <FunctionalEmotionCategory, int>{
            logs[i].tone: 1,
          },
        ),
    ];
    final rate = logs.isEmpty ? 0.0 : (overCount / logs.length) * 100.0;
    return AiEmotionDashboardSnapshot(
      threshold: threshold,
      needsVerification: true,
      verificationNote: '要検証: Anthropic研究に基づく機能的感情の外部表現分類であり、内部ニューロン監視ではありません。',
      logs: visibleLogs,
      alerts: List<AiEmotionAlertEntry>.from(alerts),
      summary: AiEmotionSummary(
        totalLogs: logs.length,
        alertCount: alerts.length,
        overThresholdRatePct: rate,
        dominantTone:
            logs.isEmpty ? FunctionalEmotionCategory.calm : logs.first.tone,
        needsVerification: true,
        verificationNote: '要検証: Anthropic研究に基づく機能的感情分類',
        countsByTone: counts,
        timeline: timeline,
      ),
    );
  }
}

class _DelayedEmotionRepository extends _InMemoryAiEmotionRepository {
  final Completer<AiEmotionDashboardSnapshot> completer =
      Completer<AiEmotionDashboardSnapshot>();

  @override
  Future<AiEmotionDashboardSnapshot> listDashboard({
    final FunctionalEmotionCategory? toneFilter,
    final double? threshold,
  }) =>
      completer.future;
}

void main() {
  group('AiEmotionModels & Controller', () {
    test(
      'always forces needsVerification true even if payload omits or false',
      () {
        final entry = AiEmotionLogEntry.fromJson(<String, Object?>{
          'id': 'log-1',
          'tone': 'urgency',
          'score': 0.85,
          'alert_threshold': 0.7,
          'threshold_exceeded': true,
          'needs_verification': false,
        });
        expect(entry.tone, FunctionalEmotionCategory.urgency);
        expect(entry.needsVerification, isTrue);
        expect(entry.thresholdExceeded, isTrue);
      },
    );

    test(
      'controller safely ignores late async completion after dispose',
      () async {
        final delayedRepo = _DelayedEmotionRepository();
        final controller = AiEmotionController(repository: delayedRepo);
        final future = controller.loadDashboard();
        controller.dispose();
        delayedRepo.completer.complete(
          const AiEmotionDashboardSnapshot.empty(),
        );
        await future;
        expect(controller.state.isLoading, isTrue);
      },
    );
  });

  group('AiEmotionDashboard UI', () {
    testWidgets(
      'seeds timeline, classifies response, and triggers threshold alert',
      (final WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _InMemoryAiEmotionRepository();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AiEmotionDashboardContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('ai_emotion_needs_verification_badge'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('ai_emotion_empty_state')),
          findsOneWidget,
        );

        final seedBtn = find.byKey(
          const ValueKey<String>('ai_emotion_seed_button'),
        );
        await tester.ensureVisible(seedBtn);
        await tester.tap(seedBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('ai_emotion_kpi_total')),
            matching: find.text('2 件'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('ai_emotion_alert_banner')),
          findsOneWidget,
        );

        final responseField = find.byKey(
          const ValueKey<String>('ai_emotion_response_field'),
        );
        await tester.ensureVisible(responseField);
        await tester.enterText(
          responseField,
          '今すぐ至急対応しないとパニックになる可能性があります！!',
        );

        final submitBtn = find.byKey(
          const ValueKey<String>('ai_emotion_submit_button'),
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const ValueKey<String>('ai_emotion_kpi_total')),
            matching: find.text('3 件'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('記録完了'), findsOneWidget);
      },
    );

    testWidgets(
      'passes Light/Dark WCAG accessibility at 360x800 and 1280x800 2.0x scale',
      (final WidgetTester tester) async {
        final repo = _InMemoryAiEmotionRepository();
        await repo.seedDefaults();

        for (final brightness in const <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          for (final size in const <Size>[
            Size(360, 800),
            Size(1280, 800),
          ]) {
            final handle = tester.ensureSemantics();
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(brightness: brightness, useMaterial3: true),
                builder: (final context, final child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: AiEmotionDashboardContainer(repository: repo),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            handle.dispose();
          }
        }
      },
    );

    testWidgets(
      'EnterprisePage exposes functional emotion dashboard action',
      (final WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: EnterprisePage()),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('enterprise_ai_emotion_action')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
