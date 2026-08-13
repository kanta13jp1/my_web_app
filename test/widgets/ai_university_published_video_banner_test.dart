import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_published_video_banner.dart';

void main() {
  Widget subject({required VoidCallback onPlay, double width = 800}) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: AiUniversityPublishedVideoBanner(
              title: 'Codex Record & Replay｜一度見せれば、次から任せられる',
              providerLabel: 'OpenAI',
              videoCount: 1,
              onPlay: onPlay,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('公開動画の情報を表示し、CTAから再生操作を通知する', (tester) async {
    var playCount = 0;
    await tester.pumpWidget(subject(onPlay: () => playCount++));

    expect(find.text('公開動画で学ぶ'), findsOneWidget);
    expect(find.text('1本'), findsOneWidget);
    expect(find.textContaining('Codex Record & Replay'), findsOneWidget);
    expect(find.text('OpenAI の公開済み動画教材'), findsOneWidget);

    await tester.tap(find.text('今すぐ見る'));
    await tester.pump();

    expect(playCount, 1);
  });

  testWidgets('狭い幅ではCTAを横幅いっぱいに配置してオーバーフローしない', (tester) async {
    await tester.pumpWidget(subject(onPlay: () {}, width: 320));

    final banner = tester.getRect(
      find.byKey(const Key('published-video-banner')),
    );
    final button = tester.getRect(
      find.byKey(const Key('published-video-play-button')),
    );

    expect(button.width, greaterThan(250));
    expect(button.left, greaterThanOrEqualTo(banner.left));
    expect(button.right, lessThanOrEqualTo(banner.right));
    expect(tester.takeException(), isNull);
  });
}
