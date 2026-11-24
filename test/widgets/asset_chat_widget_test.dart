import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/widgets/asset_chat_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _testApp(AiHubChatService service, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: const SizedBox.expand(),
      floatingActionButton: AssetChatWidget(service: service),
    ),
  );
}

Map<String, dynamic> _successResponse() => <String, dynamic>{
      'success': true,
      'thread_id': '11111111-1111-4111-8111-111111111111',
      'thread_title': '今月の支払い相談',
      'thread_created': true,
      'reply': '口座残高と未払い予定を確認してください。',
      'provider': 'google',
      'model': 'gemini-2.5-flash',
      'tokens_in': 128,
      'tokens_out': 42,
      'estimated_cost_usd': 0.000321,
    };

void main() {
  setUp(() {
    AiHubChatQuotaGuard.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('opens, sends, and displays reply with token cost', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = AiHubChatService(invoker: (_) async => _successResponse());

    await tester.pumpWidget(_testApp(service));
    expect(find.byKey(const Key('asset_chat_open_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('asset_chat_open_button')));
    await tester.pump();
    expect(find.byKey(const Key('asset_chat_panel')), findsOneWidget);
    expect(find.textContaining('資産スナップショットをAIへ送信'), findsOne);

    await tester.enterText(
      find.byKey(const Key('asset_chat_input')),
      '今月の支払いを確認して',
    );
    await tester.tap(find.byKey(const Key('asset_chat_send_button')));
    await tester.pumpAndSettle();

    expect(find.text('今月の支払いを確認して'), findsOneWidget);
    expect(find.text('口座残高と未払い予定を確認してください。'), findsOneWidget);
    expect(find.textContaining('入力 128 / 出力 42 tokens'), findsOneWidget);
    expect(find.textContaining(r'$0.000321'), findsOneWidget);
    expect(find.text('今月の支払い相談'), findsOneWidget);

    await tester.tap(find.byKey(const Key('asset_chat_close_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('asset_chat_open_button')));
    await tester.pump();
    expect(find.text('口座残高と未払い予定を確認してください。'), findsOneWidget);
  });

  testWidgets('shows a safe error and re-enables input after failure', (
    tester,
  ) async {
    final service = AiHubChatService(
      invoker: (_) async => throw const AiHubChatException('unauthorized'),
    );
    await tester.pumpWidget(_testApp(service));
    await tester.tap(find.byKey(const Key('asset_chat_open_button')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('asset_chat_input')), '相談したい');
    await tester.tap(find.byKey(const Key('asset_chat_send_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset_chat_error')), findsOneWidget);
    expect(find.textContaining('ログイン'), findsOneWidget);
    final input = tester.widget<TextField>(
      find.byKey(const Key('asset_chat_input')),
    );
    expect(input.enabled, isTrue);
  });

  testWidgets('fits a narrow mobile viewport without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = AiHubChatService(invoker: (_) async => _successResponse());

    await tester.pumpWidget(_testApp(service));
    await tester.tap(find.byKey(const Key('asset_chat_open_button')));
    await tester.pump();

    expect(find.byKey(const Key('asset_chat_panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
    final panelSize = tester.getSize(find.byKey(const Key('asset_chat_panel')));
    expect(panelSize.width, lessThanOrEqualTo(320));
    expect(panelSize.height, lessThanOrEqualTo(568));
  });

  testWidgets('opens the registered chat history route from the header', (
    tester,
  ) async {
    final service = AiHubChatService(invoker: (_) async => _successResponse());
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/asset-chat-history': (_) => const Scaffold(
                body: Text('履歴ページ'),
              ),
        },
        home: Scaffold(
          body: const SizedBox.expand(),
          floatingActionButton: AssetChatWidget(service: service),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('asset_chat_open_button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('asset_chat_history_button')));
    await tester.pumpAndSettle();

    expect(find.text('履歴ページ'), findsOneWidget);
  });

  testWidgets('quick prompt chips populate input without auto-sending', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var invokerCalls = 0;
    final service = AiHubChatService(
      invoker: (_) async {
        invokerCalls++;
        return _successResponse();
      },
    );

    await tester.pumpWidget(_testApp(service));
    await tester.tap(find.byKey(const Key('asset_chat_open_button')));
    await tester.pump();

    const expectedPrompts = <String>[
      '今月の支払いで注意すべき点は？',
      '固定費の見直し候補を教えて',
      '残高不足のリスクはある？',
    ];
    for (var i = 0; i < expectedPrompts.length; i++) {
      final chipFinder = find.byKey(Key('asset_chat_prompt_chip_$i'));
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();

      final input = tester.widget<TextField>(
        find.byKey(const Key('asset_chat_input')),
      );
      expect(input.controller?.text, expectedPrompts[i]);
      expect(input.controller?.selection.isCollapsed, isTrue);
      expect(
        input.controller?.selection.baseOffset,
        expectedPrompts[i].length,
      );
    }

    expect(invokerCalls, 0);
    expect(find.byKey(const Key('asset_chat_message_0')), findsNothing);
    expect(find.byKey(const Key('asset_chat_sending_indicator')), findsNothing);
  });

  testWidgets('renders dark theme across empty, error, and reply states', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final darkTheme = ThemeData.dark();
    var shouldFail = true;
    final service = AiHubChatService(
      invoker: (_) async {
        if (shouldFail) {
          throw const AiHubChatException('unauthorized');
        }
        return _successResponse();
      },
    );

    await tester.pumpWidget(_testApp(service, theme: darkTheme));
    await tester.tap(find.byKey(const Key('asset_chat_open_button')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final emptyIcon = tester.widget<Icon>(
      find.byIcon(Icons.account_balance_wallet_outlined),
    );
    expect(emptyIcon.color, darkTheme.colorScheme.primary);

    final emptyNotice = tester.widget<Text>(
      find.text('入力内容と資産スナップショットをAIへ送信します。'),
    );
    expect(
      emptyNotice.style?.color,
      darkTheme.colorScheme.onSurfaceVariant,
    );

    final inputContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.descendant(
              of: find.byKey(const Key('asset_chat_panel')),
              matching: find.byType(SafeArea),
            ),
            matching: find.byType(Container),
          )
          .first,
    );
    final inputDecoration = inputContainer.decoration as BoxDecoration?;
    final inputBorder = inputDecoration?.border as Border?;
    expect(inputBorder?.top.color, darkTheme.colorScheme.outlineVariant);

    await tester.tap(find.byKey(const Key('asset_chat_prompt_chip_0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('asset_chat_send_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final errorContainer = tester.widget<Container>(
      find.byKey(const Key('asset_chat_error')),
    );
    expect(errorContainer.color, darkTheme.colorScheme.errorContainer);
    final errorText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('asset_chat_error')),
        matching: find.byType(Text),
      ),
    );
    expect(errorText.style?.color, darkTheme.colorScheme.onErrorContainer);

    shouldFail = false;
    await tester.enterText(
      find.byKey(const Key('asset_chat_input')),
      '固定費を見直したい',
    );
    await tester.tap(find.byKey(const Key('asset_chat_send_button')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final replyContainer = tester.widget<Container>(
      find.byKey(const Key('asset_chat_message_2')),
    );
    final replyDecoration = replyContainer.decoration as BoxDecoration?;
    expect(
      replyDecoration?.color,
      darkTheme.colorScheme.surfaceContainerHighest,
    );
    final replyText = tester.widget<SelectableText>(
      find.descendant(
        of: find.byKey(const Key('asset_chat_message_2')),
        matching: find.byType(SelectableText),
      ),
    );
    expect(replyText.style?.color, darkTheme.colorScheme.onSurface);
    final usageText = tester.widget<Text>(
      find.byKey(const Key('asset_chat_usage_2')),
    );
    expect(usageText.style?.color, darkTheme.colorScheme.onSurfaceVariant);
  });
}
