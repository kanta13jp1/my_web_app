import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_youtube_viewer_route.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    lastPushedRoute = route;
  }
}

void main() {
  testWidgets('YouTubeビューアーはモーダル障壁のない不透明ルートで開く', (tester) async {
    final observer = _RecordingNavigatorObserver();
    var backgroundTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => backgroundTapCount++,
            child: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAiUniversityYoutubeViewer<void>(
                    context: context,
                    viewerBuilder: (viewerContext) => Dialog(
                      child: TextButton(
                        onPressed: () => Navigator.of(viewerContext).pop(),
                        child: const Text('閉じる'),
                      ),
                    ),
                  ),
                  child: const Text('動画を見る'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('動画を見る'));
    await tester.pumpAndSettle();

    final route = observer.lastPushedRoute;
    expect(route, isA<AiUniversityYoutubeViewerRoute<void>>());
    final viewerRoute = route! as AiUniversityYoutubeViewerRoute<void>;
    expect(viewerRoute.opaque, isTrue);
    expect(viewerRoute.barrierColor, isNull);

    final backgroundTapsBeforeOutsideClick = backgroundTapCount;
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(backgroundTapCount, backgroundTapsBeforeOutsideClick);
    expect(find.text('閉じる'), findsOneWidget);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('閉じる'), findsNothing);
  });
}
