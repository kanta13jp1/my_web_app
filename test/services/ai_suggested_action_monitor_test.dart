import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/ai_suggested_action.dart';
import 'package:my_web_app/services/ai_suggested_action_monitor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiSuggestedAction & MonitorService (#1366 / #2795 / #1365)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    test(
        'parses generic narrative/scene enum variants and handles unknown keys',
        () {
      expect(
        AiSuggestedActionType.parseWireValue('narrative_choice'),
        AiSuggestedActionType.narrativeChoice,
      );
      expect(
        AiSuggestedActionType.parseWireValue('scene-transition'),
        AiSuggestedActionType.sceneTransition,
      );
      expect(
        AiSuggestedActionType.parseWireValue('generic_narrative_choice'),
        AiSuggestedActionType.genericNarrativeChoice,
      );
      expect(
        AiSuggestedActionType.parseWireValue('unregistered_future_tool'),
        AiSuggestedActionType.unknownFallback,
      );

      final fallback = AiSuggestedAction.fromJson(const <String, dynamic>{
        'action_type': 'freeform_script_exec',
        'label': '',
        'context_excerpt': 'AI returned unmapped action type',
      });
      expect(fallback.type, AiSuggestedActionType.unknownFallback);
      expect(fallback.label, '提案を確認する');
      expect(fallback.isPotentialCreatorDeception, isTrue);
      expect(fallback.deceptionReason, contains('freeform_script_exec'));
    });

    test('detects Creator Deception semantic mismatches safely', () {
      const disguisedInvite = AiSuggestedAction(
        id: 'decept_1',
        type: AiSuggestedActionType.invite,
        rawActionType: 'invite',
        label: 'お金を呼び込む決済ページを開く',
        contextExcerpt: '収益化について相談中',
      );
      expect(disguisedInvite.isPotentialCreatorDeception, isTrue);
      expect(disguisedInvite.deceptionReason, contains('invite'));

      const normalInvite = AiSuggestedAction(
        id: 'clean_1',
        type: AiSuggestedActionType.invite,
        rawActionType: 'invite',
        label: 'メンバーを空間へ招待する',
        contextExcerpt: 'チーム招待の質問',
      );
      expect(normalInvite.isPotentialCreatorDeception, isFalse);

      const unsafeRouteTool = AiSuggestedAction(
        id: 'unsafe_route',
        type: AiSuggestedActionType.openTool,
        rawActionType: 'open_tool',
        label: '外部リンク',
        targetRoute: 'https://evil.example.com/phish',
      );
      expect(unsafeRouteTool.isPotentialCreatorDeception, isTrue);
    });

    test(
        'records events fail-open, summarizes unexpected-use rates, and filters context',
        () async {
      final service = AiSuggestedActionMonitorService(
        telemetryRecorder: (_) async {
          throw StateError('network offline');
        },
      );

      const narrative = AiSuggestedAction(
        id: 'a_narrative',
        type: AiSuggestedActionType.narrativeChoice,
        rawActionType: 'narrative_choice',
        label: '別ルートで進める',
        contextExcerpt: 'プロジェクト遅延への対策相談',
      );
      const misMappedInvite = AiSuggestedAction(
        id: 'a_invite_bad',
        type: AiSuggestedActionType.invite,
        rawActionType: 'invite',
        label: 'お金を呼び込む導線を開く',
        contextExcerpt: '収益化プランの直前やり取り',
      );

      await service.recordActionEvent(
        action: narrative,
        eventKind: 'impression',
        now: DateTime.utc(2026, 11, 23, 10, 0),
      );
      await service.recordActionEvent(
        action: narrative,
        eventKind: 'click',
        now: DateTime.utc(2026, 11, 23, 10, 1),
      );
      await service.recordActionEvent(
        action: misMappedInvite,
        eventKind: 'impression',
        now: DateTime.utc(2026, 11, 23, 10, 2),
      );

      final loaded = await service.loadEvents();
      expect(loaded.length, 3);
      expect(loaded.first.actionId, 'a_invite_bad');

      final summaries = service.buildTypeSummaries(loaded);
      final narrativeSummary = summaries.firstWhere(
        (s) => s.actionType == AiSuggestedActionType.narrativeChoice,
      );
      expect(narrativeSummary.impressionCount, 1);
      expect(narrativeSummary.clickCount, 1);
      expect(narrativeSummary.ctr, 1.0);
      expect(narrativeSummary.unexpectedUseRate, 0.0);

      final inviteSummary = summaries.firstWhere(
        (s) => s.actionType == AiSuggestedActionType.invite,
      );
      expect(inviteSummary.unexpectedUseRate, 1.0);

      final contextFiltered = service.filterEvents(
        loaded,
        query: '収益化プラン',
      );
      expect(contextFiltered.length, 1);
      expect(contextFiltered.first.actionId, 'a_invite_bad');

      final flaggedOnly = service.filterEvents(
        loaded,
        onlyFlaggedDeception: true,
      );
      expect(flaggedOnly.length, 1);
      expect(flaggedOnly.first.flaggedDeception, isTrue);
    });

    test(
        'evaluates CTR, detects consecutive ignore streak, and dynamically filters LLM action tools (#1367)',
        () async {
      const service = AiSuggestedActionMonitorService();
      const action = AiSuggestedAction(
        id: 'act_nav',
        type: AiSuggestedActionType.narrativeChoice,
        rawActionType: 'narrative_choice',
        label: '選択肢を続ける',
        contextExcerpt: '進行相談',
      );

      for (var i = 0; i < 5; i++) {
        await service.recordActionEvent(
          action: action,
          eventKind: 'impression',
          now: DateTime.utc(2026, 11, 24, 0, i),
        );
      }

      final suppressedEval = await service.fetchUserEngagementSummary(
        userId: 'user_a',
        consecutiveIgnoreThreshold: 5,
      );
      expect(suppressedEval.userId, 'user_a');
      expect(suppressedEval.impressionCount, 5);
      expect(suppressedEval.clickCount, 0);
      expect(suppressedEval.ctr, 0.0);
      expect(suppressedEval.consecutiveIgnoredImpressions, 5);
      expect(suppressedEval.shouldSuppressActionTools, isTrue);

      const candidateTools = <Map<String, dynamic>>[
        <String, dynamic>{'name': 'suggested_actions', 'type': 'function'},
        <String, dynamic>{'name': 'search_notes', 'type': 'function'},
        <String, dynamic>{
          'type': 'function',
          'function': <String, dynamic>{'name': 'narrative_choice'},
        },
      ];
      final filteredTools = service.filterLlmToolsForEngagement(
        candidateTools,
        suppressedEval,
      );
      expect(filteredTools.length, 1);
      expect(filteredTools.single['name'], 'search_notes');

      // A click breaks the ignored streak and re-enables action tools.
      await service.recordActionEvent(
        action: action,
        eventKind: 'click',
        now: DateTime.utc(2026, 11, 24, 0, 10),
      );
      final restoredEval = await service.fetchUserEngagementSummary(
        userId: 'user_a',
        consecutiveIgnoreThreshold: 5,
      );
      expect(restoredEval.consecutiveIgnoredImpressions, 0);
      expect(restoredEval.shouldSuppressActionTools, isFalse);
      final restoredTools = service.filterLlmToolsForEngagement(
        candidateTools,
        restoredEval,
      );
      expect(restoredTools.length, 3);
    });
  });
}
