import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/chat_highlights/data/chat_highlight_export_gateway.dart';
import 'package:my_web_app/ui/features/chat_highlights/domain/chat_highlight_models.dart';

void main() {
  test('実行文字列ではなく安全なFFmpeg引数配列をJSON出力する', () async {
    String? content;
    String? fileName;
    String? mimeType;
    final gateway = BrowserChatHighlightExportGateway(
      now: () => DateTime.utc(2026, 8, 26),
      downloader: (text, name, mime) {
        content = text;
        fileName = name;
        mimeType = mime;
      },
    );
    const snapshot = ChatHighlightSnapshot(
      sourceTitle: '配信',
      sourceVideoUrl: 'https://example.com/video.mp4?x=1&y=2',
    );
    const candidate = ChatHighlightCandidate(
      start: Duration(seconds: 10),
      end: Duration(seconds: 25),
      peakCommentCount: 4,
      peakKeywordEventCount: 2,
      matchedKeywords: <String>{'神'},
      triggers: <ChatHighlightTrigger>{ChatHighlightTrigger.commentBurst},
      score: 1.5,
    );

    await gateway.export(
      snapshot: snapshot,
      candidates: const <ChatHighlightCandidate>[candidate],
    );

    final document = jsonDecode(content!) as Map<String, dynamic>;
    final clips = document['clips'] as List<dynamic>;
    final clip = clips.single as Map<String, dynamic>;
    expect(fileName, 'chat_highlight_manifest.json');
    expect(mimeType, 'application/json;charset=utf-8');
    expect(clip.containsKey('ffmpegCommand'), isFalse);
    expect(
      clip['ffmpegArgs'],
      contains('https://example.com/video.mp4?x=1&y=2'),
    );
  });
}
