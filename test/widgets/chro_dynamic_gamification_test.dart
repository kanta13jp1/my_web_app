import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/agent_memory_entry.dart';
import 'package:my_web_app/models/agent_profile.dart';
import 'package:my_web_app/models/agent_task.dart';
import 'package:my_web_app/pages/chro_office_page.dart';
import 'package:my_web_app/services/agent_org_service.dart';
import 'package:my_web_app/services/gamification_service.dart';
import 'package:my_web_app/widgets/chro_gamification_summary_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

AgentWorkspaceSnapshot _dummyChroWorkspace() {
  final now = DateTime.utc(2026, 11, 24, 1);
  return AgentWorkspaceSnapshot(
    agent: AgentProfile(
      id: 'agent-chro',
      userId: 'user-ceo',
      slug: 'chro',
      displayName: 'CHRO',
      roleTitle: '最高人事責任者',
      department: '人事',
      status: 'active',
      identityPrompt: '健康と継続性を支援',
      permissionsSummary: '実績評価・チーム支援',
      createdAt: now,
      updatedAt: now,
    ),
    tasks: const <AgentTask>[],
    recentMemories: const <AgentMemoryEntry>[],
    startupPrompt: '今日の成果を確認します。',
  );
}

void main() {
  group('GamificationService dynamic CHRO evaluation (#1406)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    test('unlocks task and declutter achievements with AI praise and no dupes',
        () async {
      final service = GamificationService.configured(
        aiEvaluator: (achievement, stats) async =>
            'CHRO個別メッセージ: ${achievement.title} を達成 (合計${stats.totalPoints}pt)',
        nowProvider: () => DateTime.utc(2026, 11, 24, 1, 0),
      );

      expect(await service.getUserStats(), isNull);
      expect(await service.getUserAchievements(), isEmpty);
      expect(service.totalPoints, 0);

      final first = await service.recordActivity(
        tasksCompletedDelta: 1,
        contextNote: '朝レビュー完了',
      );
      expect(first.map((a) => a.id), contains('first_task_completed'));
      expect(service.totalPoints, 50);
      expect(service.latestEvaluation?.source, 'ai_evaluator');
      expect(
        service.latestEvaluation?.message,
        contains('CHRO個別メッセージ: 初タスク達成'),
      );

      final declutter = await service.recordActivity(
        declutterCompletedDelta: 1,
        contextNote: 'デスク断捨離クエスト',
      );
      expect(
        declutter.map((a) => a.id),
        containsAll(
          <String>['declutter_quest_success', 'points_milestone_100'],
        ),
      );
      expect(service.totalPoints, 250);

      // Duplicate evaluation should not re-unlock existing achievements.
      final repeat = await service.checkAchievements();
      expect(repeat, isEmpty);
      expect(service.totalPoints, 250);

      final stats = await service.getUserStats();
      expect(stats, isNotNull);
      expect(stats?.totalPoints, 250);
      expect(stats?.currentLevel, 2);

      final summary = service.buildChroSummary();
      expect(summary.unlockedCount, 3);
      expect(summary.latestEvaluation?.achievementTitle, '100pt 達成評価');
    });

    test('falls back cleanly when custom aiEvaluator throws', () async {
      final service = GamificationService.configured(
        aiEvaluator: (_, __) async => throw StateError('AI unavailable'),
        nowProvider: () => DateTime.utc(2026, 11, 24, 2, 0),
      );

      final unlocked = await service.recordActivity(notesCreatedDelta: 1);
      expect(unlocked.map((a) => a.id), contains('first_note_created'));
      expect(service.latestEvaluation?.source, 'local_fallback');
      expect(service.latestEvaluation?.message, contains('ナレッジ初記録'));
    });
  });

  group('ChroOfficePage dynamic gamification UI & a11y (#1406)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    testWidgets('shows points, unlocked achievements, and live AI evaluation',
        (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        for (final viewport in const <Size>[Size(1280, 900), Size(390, 844)]) {
          final service = GamificationService.configured(
            aiEvaluator: (achievement, stats) async =>
                'CHRO称賛: ${achievement.title} 達成により ${stats.totalPoints}pt 到達！',
            nowProvider: () => DateTime.utc(2026, 11, 24, 3, 0),
          );
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: ChroOfficePage(
                gamificationService: service,
                initialWorkspace: _dummyChroWorkspace(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('chro_office_page_scaffold')),
            findsOneWidget,
          );
          expect(find.byType(ChroGamificationSummaryCard), findsOneWidget);
          expect(
              find.byKey(const Key('chro_menu_people_help')), findsOneWidget);
          expect(find.text('0 pt'), findsOneWidget);
          expect(
            find.byKey(const Key('chro_achievements_empty_text')),
            findsOneWidget,
          );

          await service.recordActivity(
            tasksCompletedDelta: 1,
            declutterCompletedDelta: 1,
            contextNote: 'リアル断捨離クエスト',
          );
          await tester.pumpAndSettle();

          expect(find.text('250 pt'), findsOneWidget);
          expect(
            find.byKey(
              const Key('chro_unlocked_achievement_declutter_quest_success'),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('CHRO称賛:'), findsOneWidget);

          await tester.ensureVisible(
            find.byKey(const Key('chro_gamification_evaluate_btn')),
          );
          await tester.tap(
            find.byKey(const Key('chro_gamification_evaluate_btn')),
          );
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
        }
      } finally {
        handle.dispose();
      }
    });
  });
}
