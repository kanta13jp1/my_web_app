import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_chat.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/view_models/asset_chat_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AiHubChatQuotaGuard.resetForTesting();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'keeps current-session history and reuses the returned thread id',
    () async {
      final requests = <Map<String, dynamic>>[];
      var call = 0;
      final service = AiHubChatService(
        invoker: (body) async {
          requests.add(Map<String, dynamic>.from(body));
          call += 1;
          return <String, dynamic>{
            'success': true,
            'thread_id': '11111111-1111-4111-8111-111111111111',
            'thread_title': '資産相談',
            'thread_created': call == 1,
            'reply': call == 1 ? '最初の回答' : '続きの回答',
            'provider': 'google',
            'model': 'gemini-2.5-flash',
            'tokens_in': 100 + call,
            'tokens_out': 20 + call,
            'estimated_cost_usd': 0.0002 * call,
          };
        },
      );
      final viewModel = AssetChatViewModel(service: service);
      addTearDown(viewModel.dispose);

      expect(await viewModel.sendMessage('最初の質問'), isTrue);
      expect(await viewModel.sendMessage('続きの質問'), isTrue);

      expect(requests.first.containsKey('thread_id'), isFalse);
      expect(
        requests.last['thread_id'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(viewModel.messages, hasLength(4));
      expect(viewModel.messages[0].role, AssetChatMessageRole.user);
      expect(viewModel.messages[1].role, AssetChatMessageRole.assistant);
      expect(viewModel.messages[3].text, '続きの回答');
      expect(viewModel.messages[3].usage?.tokensIn, 102);
      expect(viewModel.threadTitle, '資産相談');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isSending, isFalse);
    },
  );

  test('keeps the user message and exposes a safe login error', () async {
    final service = AiHubChatService(
      invoker: (_) async => throw const AiHubChatException('unauthorized'),
    );
    final viewModel = AssetChatViewModel(service: service);
    addTearDown(viewModel.dispose);

    expect(await viewModel.sendMessage('相談したい'), isFalse);

    expect(viewModel.messages, hasLength(1));
    expect(viewModel.messages.single.text, '相談したい');
    expect(viewModel.errorMessage, contains('ログイン'));
    expect(viewModel.isSending, isFalse);
  });

  test('ignores empty messages', () async {
    var invoked = false;
    final service = AiHubChatService(
      invoker: (_) async {
        invoked = true;
        return <String, dynamic>{};
      },
    );
    final viewModel = AssetChatViewModel(service: service);
    addTearDown(viewModel.dispose);

    expect(await viewModel.sendMessage('   '), isFalse);
    expect(invoked, isFalse);
    expect(viewModel.messages, isEmpty);
  });
}
