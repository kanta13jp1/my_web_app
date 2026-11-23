import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/chat_incremental_rendering_config.dart';
import 'package:my_web_app/pages/ai_assistant_chat_page.dart';
import 'package:my_web_app/services/inline_text_diff_service.dart';
import 'package:my_web_app/widgets/ai_inline_diff_card.dart';
import 'package:my_web_app/widgets/incremental_chat_text_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('IncrementalChatTextView (#1359)', () {
    testWidgets('streams blocks incrementally over timer ticks and finishes',
        (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IncrementalChatTextView(
              text: 'Alpha Beta Gamma',
              config: const ChatIncrementalRenderingConfig(
                enabled: true,
                animationStyle: ChatIncrementalAnimationStyle.fade,
                bufferUnit: ChatIncrementalBufferUnit.word,
                chunkDelayMs: 50,
              ),
              onCompleted: () => completed = true,
            ),
          ),
        ),
      );

      // Initially only the first block is revealed.
      expect(completed, isFalse);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(find.textContaining('Gamma'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders immediately when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IncrementalChatTextView(
              text: 'First line\nSecond line',
              config: ChatIncrementalRenderingConfig(
                enabled: false,
                animationStyle: ChatIncrementalAnimationStyle.none,
                bufferUnit: ChatIncrementalBufferUnit.paragraph,
              ),
            ),
          ),
        ),
      );
      expect(find.text('First line\nSecond line'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AiInlineDiffCard & AiAssistantChatPage (#1359 / #2802)', () {
    testWidgets('renders inline diff card and transitions on apply/discard',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        String? appliedText;
        final proposal = InlineTextDiffService.buildProposal(
          originalText: '予算 1000円',
          proposedText: '予算 1500円',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AiInlineDiffCard(
                proposal: proposal,
                onApply: (text) async {
                  appliedText = text;
                },
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('ai_inline_diff_card')), findsOneWidget);
        expect(find.text('確認待ち'), findsOneWidget);
        await tester.tap(find.byKey(const Key('ai_inline_diff_apply_button')));
        await tester.pumpAndSettle();

        expect(appliedText, '予算 1500円');
        expect(find.text('適用済み'), findsOneWidget);
        expect(
            find.byKey(const Key('ai_inline_diff_apply_button')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
        'configures rendering style in AiAssistantChatPage and applies inline proposal',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      String? applied;

      await tester.pumpWidget(
        MaterialApp(
          home: AiAssistantChatPage(
            debugInitialConfig: const ChatIncrementalRenderingConfig(
              enabled: true,
              animationStyle: ChatIncrementalAnimationStyle.fade,
              bufferUnit: ChatIncrementalBufferUnit.word,
            ),
            debugInitialMessages: const <AiAssistantChatDebugMessage>[
              AiAssistantChatDebugMessage(
                role: 'assistant',
                content: '変更案です。\n'
                    '<<<ORIGINAL\n'
                    '毎日チェック\n'
                    '===\n'
                    '週次チェックと月次締め\n'
                    '>>>PROPOSED',
              ),
            ],
            onApplyProposal: (text) async {
              applied = text;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Settings dialog switches animation style to blur & buffer unit to paragraph.
      await tester.tap(
        find.byKey(const Key('ai_chat_rendering_settings_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai_chat_anim_blur_chip')));
      await tester.tap(find.byKey(const Key('ai_chat_unit_paragraph_chip')));
      await tester.tap(
        find.byKey(const Key('ai_chat_rendering_settings_save_button')),
      );
      await tester.pumpAndSettle();

      final savedConfig = await ChatIncrementalRenderingConfig.loadFromPrefs();
      expect(savedConfig.animationStyle, ChatIncrementalAnimationStyle.blur);
      expect(savedConfig.bufferUnit, ChatIncrementalBufferUnit.paragraph);

      // Inline diff card apply action forwards proposed text.
      await tester.tap(find.byKey(const Key('ai_inline_diff_apply_button')));
      await tester.pumpAndSettle();
      expect(applied, '週次チェックと月次締め');
      expect(tester.takeException(), isNull);
    });
  });
}
