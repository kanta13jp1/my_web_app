import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/chat_highlights/data/chat_highlight_gateway.dart';
import 'package:my_web_app/ui/features/chat_highlights/domain/chat_highlight_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('時系列チャットと設定をversion付きJSONで復元する', () async {
    final preferences = await SharedPreferences.getInstance();
    final gateway = SharedPreferencesChatHighlightGateway(
      preferences: preferences,
    );
    const snapshot = ChatHighlightSnapshot(
      sourceTitle: '配信',
      sourceVideoUrl: 'https://example.com/video.mp4',
      events: <ChatHighlightEvent>[
        ChatHighlightEvent(
          id: 'event-1',
          offset: Duration(seconds: 12),
          author: 'viewer',
          message: '神展開',
        ),
      ],
      settings: ChatHighlightSettings(minimumComments: 3),
    );

    await gateway.save(snapshot);
    final restored = await gateway.load();

    expect(restored.sourceTitle, '配信');
    expect(restored.events.single.offset, const Duration(seconds: 12));
    expect(restored.events.single.message, '神展開');
    expect(restored.settings.minimumComments, 3);
    final stored = jsonDecode(
      preferences.getString(
        SharedPreferencesChatHighlightGateway.storageKey,
      )!,
    ) as Map<String, dynamic>;
    expect(stored['version'], 1);
  });

  test('壊れたデータは読み込み失敗として通知し、原文を保持する', () async {
    final preferences = await SharedPreferences.getInstance();
    for (final raw in <String>['{broken', '[]', '']) {
      await preferences.setString(
        SharedPreferencesChatHighlightGateway.storageKey,
        raw,
      );
      await expectLater(
        SharedPreferencesChatHighlightGateway(preferences: preferences).load(),
        throwsFormatException,
      );
      expect(
        preferences.getString(SharedPreferencesChatHighlightGateway.storageKey),
        raw,
      );
    }
  });
}
