import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_published_video_banner.dart';

void main() {
  Widget subject({
    required VoidCallback onFirstPlay,
    required VoidCallback onSecondPlay,
    double width = 800,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: AiUniversityPublishedVideoBanner(
              videos: [
                AiUniversityPublishedVideoBannerItem(
                  title: 'Codex Record & Replay｜一度見せれば、次から任せられる',
                  providerLabel: 'OpenAI',
                  onPlay: onFirstPlay,
                ),
                AiUniversityPublishedVideoBannerItem(
                  title: '「完了した人としておかしいですよね？」を解説',
                  providerLabel: 'OpenAI',
                  onPlay: onSecondPlay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('公開動画を全件表示し、選んだ動画の再生操作だけを通知する', (tester) async {
    var firstPlayCount = 0;
    var secondPlayCount = 0;
    await tester.pumpWidget(
      subject(
        onFirstPlay: () => firstPlayCount++,
        onSecondPlay: () => secondPlayCount++,
      ),
    );

    expect(find.text('公開動画で学ぶ'), findsOneWidget);
    expect(find.text('2本'), findsOneWidget);
    expect(find.textContaining('Codex Record & Replay'), findsOneWidget);
    expect(find.textContaining('完了した人として'), findsOneWidget);
    expect(find.text('今すぐ見る'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('published-video-play-button-1')));
    await tester.pump();

    expect(firstPlayCount, 0);
    expect(secondPlayCount, 1);
  });

  testWidgets('PC幅では動画一覧の高さを制限し、最後の動画まで縦スクロールできる', (tester) async {
    var lastPlayCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Column(
            children: [
              AiUniversityPublishedVideoBanner(
                videos: [
                  for (var index = 0; index < 16; index++)
                    AiUniversityPublishedVideoBannerItem(
                      title: '公開動画 ${index + 1}',
                      providerLabel: 'OpenAI',
                      onPlay: index == 15 ? () => lastPlayCount++ : () {},
                    ),
                ],
              ),
              const Expanded(
                child: ColoredBox(
                  key: Key('content-below-published-videos'),
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final banner = tester.getRect(
      find.byKey(const Key('published-video-banner')),
    );
    final contentBelow = tester.getRect(
      find.byKey(const Key('content-below-published-videos')),
    );

    expect(
      find.byKey(const Key('published-video-desktop-grid')),
      findsOneWidget,
    );
    expect(banner.height, lessThan(310));
    expect(contentBelow.height, greaterThan(0));
    expect(contentBelow.top, banner.bottom);

    await tester.drag(
      find.byKey(const Key('published-video-desktop-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('published-video-play-button-15')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('published-video-play-button-15')));
    await tester.pump();
    expect(lastPlayCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('狭い幅では動画を固定高の横カルーセルにして本文を押し出さない', (tester) async {
    await tester.pumpWidget(
      subject(onFirstPlay: () {}, onSecondPlay: () {}, width: 320),
    );

    final banner = tester.getRect(
      find.byKey(const Key('published-video-banner')),
    );
    expect(
      find.byKey(const Key('published-video-mobile-carousel')),
      findsOneWidget,
    );
    final firstButton = tester.getRect(
      find.byKey(const Key('published-video-play-button-0')),
    );
    final secondButton = tester.getRect(
      find.byKey(const Key('published-video-play-button-1')),
    );

    expect(firstButton.width, greaterThan(200));
    expect(secondButton.width, greaterThan(200));
    expect(firstButton.left, greaterThanOrEqualTo(banner.left));
    expect(firstButton.right, lessThanOrEqualTo(banner.right));
    expect(secondButton.left, greaterThan(firstButton.right));
    expect(secondButton.top, firstButton.top);
    expect(banner.height, lessThan(240));
    expect(tester.takeException(), isNull);
  });
}
