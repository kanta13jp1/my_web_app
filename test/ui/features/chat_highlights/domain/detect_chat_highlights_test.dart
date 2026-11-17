import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/chat_highlights/domain/chat_highlight_models.dart';
import 'package:my_web_app/ui/features/chat_highlights/domain/detect_chat_highlights.dart';

void main() {
  const detector = DetectChatHighlights();

  ChatHighlightEvent event(String id, int seconds, String message) {
    return ChatHighlightEvent(
      id: id,
      offset: Duration(seconds: seconds),
      author: 'viewer',
      message: message,
    );
  }

  test('コメント閾値は集計窓の境界を含めて候補化する', () {
    final candidates = detector(
      <ChatHighlightEvent>[
        event('a', 10, 'a'),
        event('b', 20, 'b'),
        event('c', 30, 'c'),
        event('d', 40, 'd'),
      ],
      const ChatHighlightSettings(
        windowSeconds: 30,
        minimumComments: 4,
        minimumKeywordEvents: 9,
        preRollSeconds: 5,
        postRollSeconds: 10,
        keywords: <String>[],
      ),
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.start, const Duration(seconds: 5));
    expect(candidates.single.end, const Duration(seconds: 50));
    expect(candidates.single.peakCommentCount, 4);
    expect(
      candidates.single.triggers,
      contains(ChatHighlightTrigger.commentBurst),
    );
  });

  test('キーワード反応だけでも大文字小文字を無視して候補化する', () {
    final candidates = detector(
      <ChatHighlightEvent>[event('a', 60, 'WOW!'), event('b', 65, 'wow すごい')],
      const ChatHighlightSettings(
        minimumComments: 99,
        minimumKeywordEvents: 2,
        preRollSeconds: 0,
        postRollSeconds: 5,
        keywords: <String>['wow'],
      ),
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.peakKeywordEventCount, 2);
    expect(candidates.single.matchedKeywords, <String>{'wow'});
    expect(
      candidates.single.triggers,
      contains(ChatHighlightTrigger.keywordBurst),
    );
  });

  test('入力順と重複IDに依存せず、重なる候補を1区間へ統合する', () {
    final candidates = detector(
      <ChatHighlightEvent>[
        event('c', 20, 'c'),
        event('a', 10, 'a'),
        event('b', 15, 'b'),
        event('b', 16, '重複ID'),
        event('d', 24, 'd'),
      ],
      const ChatHighlightSettings(
        windowSeconds: 10,
        minimumComments: 3,
        minimumKeywordEvents: 99,
        preRollSeconds: 2,
        postRollSeconds: 5,
        keywords: <String>[],
      ),
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.start, const Duration(seconds: 8));
    expect(candidates.single.end, const Duration(seconds: 29));
  });

  test('空入力と閾値未満は候補を返さない', () {
    expect(
      detector(const <ChatHighlightEvent>[], const ChatHighlightSettings()),
      isEmpty,
    );
    expect(
      detector(
        <ChatHighlightEvent>[
          event('a', 1, '通常コメント'),
        ],
        const ChatHighlightSettings(),
      ),
      isEmpty,
    );
  });
}
