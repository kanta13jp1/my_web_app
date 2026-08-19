import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/widgets/asset_chat_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _testApp(AiHubChatService service) {
  return MaterialApp(
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
}
