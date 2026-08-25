import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/musubi_social_models.dart';
import 'package:my_web_app/services/musubi_social_controller.dart';
import 'package:my_web_app/services/musubi_social_repository.dart';

void main() {
  group('MusubiSocialController', () {
    test('feed lenses and ordering are controlled by the user', () {
      final controller = MusubiSocialController(repository: _FakeRepository());

      expect(controller.visiblePosts, hasLength(5));

      controller.setLens(MusubiFeedLens.local);
      expect(
        controller.visiblePosts.map((post) => post.id),
        containsAll(<String>['preview-1', 'preview-3']),
      );

      controller.setLens(MusubiFeedLens.resonance);
      controller.setChronological(false);
      expect(controller.visiblePosts.first.id, 'preview-3');
    });

    test('publishing inserts a visible, human-labeled post', () async {
      final controller = MusubiSocialController(repository: _FakeRepository());

      expect(await controller.createPost('   '), isFalse);
      expect(await controller.createPost('今日の学びを共有します'), isTrue);

      final post = controller.visiblePosts.first;
      expect(post.content, '今日の学びを共有します');
      expect(post.isMine, isTrue);
      expect(post.isVerifiedHuman, isTrue);
      expect(controller.notice, contains('投稿しました'));
    });

    test('reactions, bookmarks, and safety preferences are mutable', () {
      final controller = MusubiSocialController(repository: _FakeRepository());
      final before =
          controller.visiblePosts.firstWhere((post) => post.id == 'preview-1');

      controller.toggleLike('preview-1');
      controller.toggleBookmark('preview-1');
      controller.setHideUnlabeledAi(false);
      controller.updateDiscovery(44);

      final after =
          controller.visiblePosts.firstWhere((post) => post.id == 'preview-1');
      expect(after.isLiked, isTrue);
      expect(after.isBookmarked, isTrue);
      expect(after.reactions, before.reactions + 1);
      expect(controller.preferences.hideUnlabeledAi, isFalse);
      expect(controller.preferences.discovery, 44);
    });
  });
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
      id: 'created-post',
      authorName: 'あなた',
      handle: '@you.musubi',
      avatarLabel: '私',
      content: content.trim(),
      createdAt: DateTime.now(),
      community: audience.name,
      lenses: const <MusubiFeedLens>{
        MusubiFeedLens.resonance,
        MusubiFeedLens.following,
        MusubiFeedLens.quiet,
      },
      resonance: 100,
      isVerifiedHuman: true,
      isAiAssisted: aiAssisted,
      isMine: true,
    );
  }
}
