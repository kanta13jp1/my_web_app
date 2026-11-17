import 'dart:convert';

import '../../../../utils/web_text_downloader.dart';
import '../domain/chat_highlight_models.dart';

typedef ChatHighlightTextDownloader = void Function(
  String text,
  String fileName,
  String mimeType,
);

void _downloadManifest(String text, String fileName, String mimeType) {
  downloadTextFile(text, fileName, mimeType: mimeType);
}

abstract class ChatHighlightExportGateway {
  Future<void> export({
    required ChatHighlightSnapshot snapshot,
    required List<ChatHighlightCandidate> candidates,
  });
}

class BrowserChatHighlightExportGateway implements ChatHighlightExportGateway {
  const BrowserChatHighlightExportGateway({
    this.downloader = _downloadManifest,
    this.now = DateTime.now,
  });

  final ChatHighlightTextDownloader downloader;
  final DateTime Function() now;

  @override
  Future<void> export({
    required ChatHighlightSnapshot snapshot,
    required List<ChatHighlightCandidate> candidates,
  }) async {
    final source = snapshot.sourceVideoUrl.trim();
    final clips = <Map<String, dynamic>>[];
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final output = 'highlight_${(index + 1).toString().padLeft(2, '0')}.mp4';
      clips.add(<String, dynamic>{
        ...candidate.toJson(),
        'outputFile': output,
        'ffmpegArgs': <String>[
          '-ss',
          _seconds(candidate.start),
          '-i',
          source,
          '-t',
          _seconds(candidate.end - candidate.start),
          '-c',
          'copy',
          output,
        ],
      });
    }
    final document = <String, dynamic>{
      'schema': 'my-web-app/chat-highlight-manifest/v1',
      'generatedAt': now().toUtc().toIso8601String(),
      'source': <String, String>{
        'title': snapshot.sourceTitle,
        'videoUrl': source,
      },
      'settings': snapshot.settings.toJson(),
      'clips': clips,
      'notice': 'ffmpegArgs は編集環境で確認してから実行してください。',
    };
    downloader(
      const JsonEncoder.withIndent('  ').convert(document),
      'chat_highlight_manifest.json',
      'application/json;charset=utf-8',
    );
  }

  String _seconds(Duration value) =>
      (value.inMilliseconds / 1000).toStringAsFixed(3);
}
