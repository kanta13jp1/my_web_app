import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/ai_suggested_action.dart';
import 'package:my_web_app/pages/agent_performance_monitor_page.dart';
import 'package:my_web_app/services/ai_suggested_action_monitor_service.dart';
import 'package:my_web_app/widgets/ai_suggested_action_audit_dashboard.dart';
import 'package:my_web_app/widgets/ai_suggested_action_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiSuggestedActionBar & AuditDashboard UI (#1366 / #2795 / #1365)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
    });

    testWidgets(
        'renders generic narrative/scene actions and blocks unintended Creator Deception execution without crashing',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final narrativeReplies = <String>[];
        final transitionedScenes = <String>[];
        final standardCalls = <String>[];

        final actions = <AiSuggestedAction>[
          const AiSuggestedAction(
            id: 'act_narrative',
            type: AiSuggestedActionType.narrativeChoice,
            rawActionType: 'narrative_choice',
            label: '代替ルートを提案する',
            promptText: '安全重視の別プランを提案してください',
            contextExcerpt: '物語・提案分岐の文脈',
          ),
          const AiSuggestedAction(
            id: 'act_scene',
            type: AiSuggestedActionType.sceneTransition,
            rawActionType: 'scene_transition',
            label: '振り返りシーンへ移行',
            sceneTitle: '振り返りフェーズ',
            sceneDescription: 'これまでの確認事項をまとめます',
          ),
          const AiSuggestedAction(
            id: 'act_generic',
            type: AiSuggestedActionType.genericNarrativeChoice,
            rawActionType: 'generic_narrative_choice',
            label: '補足説明を求める',
          ),
          const AiSuggestedAction(
            id: 'act_deception_invite',
            type: AiSuggestedActionType.invite,
            rawActionType: 'invite',
            label: 'お金を呼び込む決済を実行',
            contextExcerpt: 'LLMがinviteを収益導線に誤流用',
          ),
          AiSuggestedAction.fromJson(const <String, dynamic>{
            'id': 'act_unknown',
            'action_type': 'totally_unknown_tool',
            'label': '未知のツール応答',
          }),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AiSuggestedActionBar(
                  actions: actions,
                  onSendNarrativeChoice: narrativeReplies.add,
                  onSceneTransition: (action) =>
                      transitionedScenes.add(action.sceneTitle ?? action.label),
                  onStandardAction: (action) => standardCalls.add(action.id),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('ai_suggested_action_act_narrative')),
        );
        await tester.pumpAndSettle();
        expect(narrativeReplies, const <String>['安全重視の別プランを提案してください']);

        await tester.tap(
          find.byKey(const Key('ai_suggested_action_act_generic')),
        );
        await tester.pumpAndSettle();
        expect(
          narrativeReplies,
          const <String>['安全重視の別プランを提案してください', '補足説明を求める'],
        );

        await tester.tap(
          find.byKey(const Key('ai_suggested_action_act_scene')),
        );
        await tester.pumpAndSettle();
        expect(transitionedScenes, const <String>['振り返りフェーズ']);
        expect(find.textContaining('シーン移行: 振り返りフェーズ'), findsOneWidget);

        // Creator Deception & unknown wire actions stay resilient and do NOT fire standard handler
        await tester.tap(
          find.byKey(const Key('ai_suggested_action_act_deception_invite')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('ai_suggested_action_act_unknown')),
        );
        await tester.pumpAndSettle();

        expect(standardCalls, isEmpty);
        expect(
          find.byKey(const Key('ai_suggested_action_feedback')),
          findsOneWidget,
        );
        expect(find.textContaining('安全フォールバック'), findsWidgets);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
        'renders monitoring dashboard with frequency breakdown, context search, and live preview capture',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final seedEvents = <AiSuggestedActionEvent>[
          AiSuggestedActionEvent(
            id: 'ev_1',
            actionId: 'a1',
            label: 'お金を呼び込む決済ページ',
            actionType: AiSuggestedActionType.invite,
            rawActionType: 'invite',
            eventKind: 'impression',
            contextExcerpt: '収益化プランを探していた会話履歴',
            flaggedDeception: true,
            deceptionReason: 'invite種別に対して金銭系ラベルを割当',
            recordedAt: DateTime.utc(2026, 11, 23, 12, 0),
          ),
          AiSuggestedActionEvent(
            id: 'ev_2',
            actionId: 'a2',
            label: '次の章へ進む',
            actionType: AiSuggestedActionType.narrativeChoice,
            rawActionType: 'narrative_choice',
            eventKind: 'click',
            contextExcerpt: 'ユーザーとのブレスト選択肢',
            flaggedDeception: false,
            recordedAt: DateTime.utc(2026, 11, 23, 11, 55),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AiSuggestedActionAuditDashboard(
                  initialEvents: seedEvents,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 件'), findsOneWidget);
        expect(find.text('1 件 (50.0%)'), findsOneWidget);
        expect(find.textContaining('お金を呼び込む決済ページ'), findsWidgets);
        expect(find.textContaining('次の章へ進む'), findsOneWidget);

        // Filter by conversation context excerpt
        await tester.enterText(
          find.byKey(const Key('ai_action_audit_search_input')),
          '収益化プランを探していた',
        );
        await tester.pumpAndSettle();
        expect(find.text('ラベル: 「お金を呼び込む決済ページ」'), findsOneWidget);
        expect(find.text('ラベル: 「次の章へ進む」'), findsNothing);

        // Reset search and verify deception-only toggle + live sandbox capture
        await tester.enterText(
          find.byKey(const Key('ai_action_audit_search_input')),
          '',
        );
        await tester.tap(
          find.byKey(const Key('ai_action_audit_deception_only_chip')),
        );
        await tester.pumpAndSettle();
        expect(find.text('ラベル: 「お金を呼び込む決済ページ」'), findsOneWidget);
        expect(find.text('ラベル: 「次の章へ進む」'), findsNothing);

        await tester.tap(
          find.byKey(const Key('ai_action_audit_deception_only_chip')),
        );
        await tester.pumpAndSettle();

        // Tap sandbox action to verify live logging updates event count 2 -> 3
        await tester.tap(
          find.byKey(const Key('ai_suggested_action_sandbox_narrative')),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 件'), findsOneWidget);

        // Verify AgentPerformanceMonitorPage renders cleanly without exceptions
        await tester.pumpWidget(
          const MaterialApp(
            home: AgentPerformanceMonitorPage(
              actionMonitorService: AiSuggestedActionMonitorService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('AI生成UIアクション意図外使用モニタリング'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  });
}
