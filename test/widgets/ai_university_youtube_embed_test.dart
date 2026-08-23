import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_youtube_embed.dart';

void main() {
  testWidgets('renders the YouTube lesson and opens the source',
      (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiUniversityYoutubeEmbed(
            videoId: '-ZxiEPqxKRY',
            title: 'Codex Record & Replay',
            onOpen: () => opened = true,
          ),
        ),
      ),
    );

    expect(find.text('YouTube 教材'), findsOneWidget);
    expect(find.text('YouTubeで開く'), findsOneWidget);
    if (kIsWeb) {
      expect(find.byType(HtmlElementView), findsOneWidget);
    } else {
      expect(find.text('YouTubeで動画を再生できます'), findsOneWidget);
    }

    await tester.tap(find.text('YouTubeで開く'));
    await tester.pump();

    expect(opened, isTrue);
  });
}
