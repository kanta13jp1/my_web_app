import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/musubi_post_content.dart';

void main() {
  const youtubeUrl = 'https://www.youtube.com/watch?v=ZK3JhU73W18';

  testWidgets('opens a raw YouTube URL when the link is tapped',
      (tester) async {
    Uri? openedUri;

    await tester.pumpWidget(
      _app(
        MusubiPostContent(
          text: youtubeUrl,
          urlOpener: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    final link = find.text(youtubeUrl, findRichText: true);
    expect(link, findsOneWidget);

    await tester.tap(link);
    await tester.pump();

    expect(openedUri, Uri.parse(youtubeUrl));
  });

  testWidgets('keeps surrounding post text visible', (tester) async {
    await tester.pumpWidget(
      _app(
        const MusubiPostContent(
          text: 'この動画がおすすめです\n$youtubeUrl',
        ),
      ),
    );

    expect(
      find.textContaining('この動画がおすすめです', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining(youtubeUrl, findRichText: true), findsOneWidget);
  });

  testWidgets('does not open non-web URL schemes', (tester) async {
    Uri? openedUri;

    await tester.pumpWidget(
      _app(
        MusubiPostContent(
          text: 'mailto:test@example.com',
          urlOpener: (uri) async {
            openedUri = uri;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('mailto:test@example.com', findRichText: true));
    await tester.pump();

    expect(openedUri, isNull);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(body: child),
  );
}
