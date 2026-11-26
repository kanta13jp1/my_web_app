import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:my_web_app/pages/public_blog_post_page.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ja');
  });

  Widget buildApp({
    required Future<Map<String, dynamic>?> Function(String id) loader,
    String? postId = 'post-1',
    Size? surfaceSize,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      routes: {
        '/': (_) => Scaffold(
              appBar: AppBar(title: const Text('無料AI体験トップ')),
              body: const Text('トップ体験画面'),
            ),
        '/blog': (_) => Scaffold(
              appBar: AppBar(title: const Text('ブログ一覧')),
              body: const Text('一覧画面'),
            ),
      },
      initialRoute: '/blog/post',
      onGenerateRoute: (settings) {
        if (settings.name == '/blog/post') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) {
              final child = PublicBlogPostPage(
                postId: postId,
                postLoader: loader,
                currentUserIdProvider: () => null,
              );
              if (textScale == 1.0) return child;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                ),
                child: child,
              );
            },
          );
        }
        return null;
      },
    );
  }

  testWidgets('strips raw YAML frontmatter and navigates from AI trial CTA',
      (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        buildApp(
          loader: (_) async => {
            'id': 'post-1',
            'title': '収支棚卸し手順',
            'posted_at': '2026-11-27T00:00:00Z',
            'status': 'posted',
            'content': '---\ntitle: "収支棚卸し手順"\npublished: false\n---\n\n'
                '## 3つの確認ポイント\n\nまずは1件だけ試せます。',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('収支棚卸し手順'), findsOneWidget);
      expect(find.textContaining('published: false'), findsNothing);
      expect(find.textContaining('3つの確認ポイント'), findsOneWidget);
      expect(find.text('まずは無料で1件、AI体験を試してみませんか？'), findsOneWidget);
      expect(find.text('無料で1件AI体験を試す'), findsOneWidget);

      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.ensureVisible(find.text('無料で1件AI体験を試す'));
      await tester.tap(find.text('無料で1件AI体験を試す'));
      await tester.pumpAndSettle();

      expect(find.text('トップ体験画面'), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('renders empty and error states without crashing',
      (tester) async {
    await tester.pumpWidget(
      buildApp(
        postId: 'post-empty',
        loader: (_) async => null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('記事が見つかりません'), findsOneWidget);

    await tester.pumpWidget(
      buildApp(
        postId: 'post-error',
        loader: (_) async => throw Exception('network timeout'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('記事の読み込みに失敗しました'), findsOneWidget);
  });

  testWidgets('does not overflow at 320x568 with 2x text scaling',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(
        textScale: 2.0,
        loader: (_) async => {
          'id': 'post-2',
          'title': '狭幅と拡大文字での表示テスト記事タイトル',
          'posted_at': '2026-11-27T00:00:00Z',
          'status': 'posted',
          'content': '本文テストです。',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('無料で1件AI体験を試す'));
    expect(tester.takeException(), isNull);
  });
}
