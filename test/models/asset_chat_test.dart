import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_chat.dart';

void main() {
  test('parses thread summary timestamps', () {
    final thread = AssetChatThreadSummary.fromMap(<String, dynamic>{
      'id': 'thread-1',
      'title': '今月の支払い',
      'created_at': '2026-08-18T01:00:00Z',
      'last_message_at': '2026-08-18T02:00:00Z',
    });

    expect(thread.id, 'thread-1');
    expect(thread.title, '今月の支払い');
    expect(thread.createdAt.toUtc().hour, 1);
    expect(thread.lastMessageAt.toUtc().hour, 2);
  });

  test('parses stored assistant message usage', () {
    final message = AssetChatStoredMessage.fromMap(<String, dynamic>{
      'id': 'message-1',
      'thread_id': 'thread-1',
      'role': 'assistant',
      'content': '未払い予定を確認してください。',
      'tokens_in': 120,
      'tokens_out': 24,
      'model': 'gemini-2.5-flash',
      'created_at': '2026-08-18T02:00:00Z',
    });

    expect(message.isUser, isFalse);
    expect(message.tokensIn, 120);
    expect(message.tokensOut, 24);
    expect(message.model, 'gemini-2.5-flash');
  });

  test('rejects unsupported stored message roles', () {
    expect(
      () => AssetChatStoredMessage.fromMap(<String, dynamic>{
        'id': 'message-1',
        'thread_id': 'thread-1',
        'role': 'system',
        'content': 'secret',
        'created_at': '2026-08-18T02:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
