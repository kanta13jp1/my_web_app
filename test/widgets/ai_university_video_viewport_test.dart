import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_youtube_embed.dart';

void main() {
  for (final size in [
    const Size(1920, 912),
    const Size(1366, 650),
    const Size(390, 700),
    const Size(844, 390),
  ]) {
    testWidgets('video fits remaining lesson viewport at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(height: size.height * 0.5),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewport) {
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          AiUniversityYoutubeEmbed(
                            videoId: 'zBLlOoS6Mp0',
                            title: 'Lesson',
                            maxPlayerHeight:
                                (viewport.maxHeight - 96).clamp(0.0, 720.0),
                            onOpen: () => opened = true,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final picture = tester.getRect(find.byType(AspectRatio));
      expect(picture.width / picture.height, closeTo(16 / 9, 0.001));
      expect(picture.left, greaterThanOrEqualTo(16));
      expect(picture.right, lessThanOrEqualTo(size.width - 16));
      expect(picture.bottom, lessThanOrEqualTo(size.height - 64));
      expect(
        tester.getRect(find.byType(TextButton)).bottom,
        lessThanOrEqualTo(size.height),
      );
      await tester.tap(find.text('YouTubeで開く'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
