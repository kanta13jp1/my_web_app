import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/musubi_social_models.dart';
import 'package:my_web_app/pages/social_feed_page.dart';
import 'package:my_web_app/services/musubi_social_controller.dart';
import 'package:my_web_app/services/musubi_social_repository.dart';

void main() {
  testWidgets('MUSUBI publishes a post from the composer', (tester) async {
    _setViewport(tester, const Size(1280, 1400));
    final controller = MusubiSocialController(repository: _FakeRepository());
    await tester.pumpWidget(_app(controller));

    expect(find.byKey(const Key('musubi_page_title')), findsOneWidget);
    expect(find.text('注目を奪わず、\nつながりを育てる。'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('musubi_composer_field')),
      '人と文脈を大切にする投稿',
    );
    await tester.ensureVisible(find.byKey(const Key('musubi_publish_button')));
    await tester.tap(find.byKey(const Key('musubi_publish_button')));
    await tester.pumpAndSettle();

    expect(find.text('人と文脈を大切にする投稿'), findsOneWidget);
    expect(controller.visiblePosts.first.isMine, isTrue);
  });

  testWidgets('feed lens and reaction controls update the experience',
      (tester) async {
    _setViewport(tester, const Size(1280, 1400));
    final controller = MusubiSocialController(repository: _FakeRepository());
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('musubi-lens-local')));
    await tester.pump();
    expect(controller.activeLens, MusubiFeedLens.local);
    expect(controller.visiblePosts, hasLength(2));

    await tester.tap(find.byKey(const Key('musubi-lens-resonance')));
    await tester.pump();
    final post = controller.visiblePosts.first;
    await tester.scrollUntilVisible(
      find.byKey(Key('musubi-like-${post.id}')),
      320,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(Key('musubi-like-${post.id}')));
    await tester.pump();
    expect(controller.visiblePosts.first.isLiked, isTrue);
  });

  testWidgets('mobile layout exposes bottom navigation without overflow',
      (tester) async {
    _setViewport(tester, const Size(390, 844));

    final controller = MusubiSocialController(repository: _FakeRepository());
    await tester.pumpWidget(_app(controller));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const Key('musubi_composer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(MusubiSocialController controller) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: MusubiSocialPage(
      controller: controller,
      autoInitialize: false,
    ),
  );
}

class _FakeRepository implements MusubiSocialRepository {
  @override
  List<MusubiPost> get previewPosts => musubiPreviewPosts();

  @override
  Future<List<MusubiPost>> loadPosts() async => previewPosts;

  @override
  Future<MusubiPost> createPost({
    required String content,
    required MusubiAudience audience,
    required bool aiAssisted,
  }) async {
    return MusubiPost(
      id: 'widget-created',
      authorName: 'あなた',
      handle: '@you.musubi',
      avatarLabel: '私',
      content: content.trim(),
      createdAt: DateTime.now(),
      community: audience.name,
      lenses: const <MusubiFeedLens>{
        MusubiFeedLens.resonance,
        MusubiFeedLens.following,
      },
      resonance: 100,
      isVerifiedHuman: true,
      isAiAssisted: aiAssisted,
      isMine: true,
    );
  }
}
