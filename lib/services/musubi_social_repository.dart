import '../models/musubi_social_models.dart';
import '../models/social_feed_post.dart';
import 'musubi_supabase_service.dart';

abstract interface class MusubiSocialRepository {
  List<MusubiPost> get previewPosts;

  Future<List<MusubiPost>> loadPosts();

  Future<MusubiPost> createPost({
    required String content,
    required MusubiAudience audience,
    required bool aiAssisted,
  });
}

class PreviewMusubiSocialRepository implements MusubiSocialRepository {
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
    final now = DateTime.now();
    return MusubiPost(
      id: 'preview-created-${now.microsecondsSinceEpoch}',
      authorName: 'あなた',
      handle: '@you.musubi',
      avatarLabel: '私',
      content: content.trim(),
      createdAt: now,
      community: musubiCommunityForAudience(audience),
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

class SupabaseMusubiSocialRepository implements MusubiSocialRepository {
  SupabaseMusubiSocialRepository({MusubiSupabaseService? service})
      : _service = service ?? MusubiSupabaseService();

  final MusubiSupabaseService _service;

  @override
  List<MusubiPost> get previewPosts => musubiPreviewPosts();

  @override
  Future<List<MusubiPost>> loadPosts() async {
    final previews = previewPosts;
    if (!_service.isAuthenticated) return previews;

    try {
      final rows = await _service.fetchPosts();
      final remotePosts = rows.map(
        (row) => musubiPostFromDatabaseRow(
          row,
          currentUserId: _service.currentUserId,
        ),
      );
      return <MusubiPost>[...remotePosts, ...previews];
    } catch (_) {
      try {
        final data = await _service.invokeLegacyFeed(
          'feed.timeline',
          body: const <String, dynamic>{'type': 'public', 'limit': 30},
        );
        final remotePosts =
            SocialFeedPost.listFromResponse(data).asMap().entries.map((entry) {
          final post = entry.value;
          return MusubiPost(
            id: 'remote-${entry.key}-${post.createdAt}',
            authorName: 'あなた',
            handle: '@you.musubi',
            avatarLabel: '私',
            content: post.content,
            createdAt: DateTime.tryParse(post.createdAt) ?? DateTime.now(),
            community: 'マイ・サークル',
            lenses: const <MusubiFeedLens>{
              MusubiFeedLens.resonance,
              MusubiFeedLens.following,
            },
            reactions: post.likes.toInt(),
            replies: post.comments.toInt(),
            resonance: 100,
            isVerifiedHuman: true,
            isMine: true,
          );
        }).where((post) => post.content.trim().isNotEmpty);
        return <MusubiPost>[...remotePosts, ...previews];
      } catch (_) {
        return previews;
      }
    }
  }

  @override
  Future<MusubiPost> createPost({
    required String content,
    required MusubiAudience audience,
    required bool aiAssisted,
  }) async {
    final normalized = content.trim();
    if (_service.isAuthenticated) {
      try {
        final row = await _service.insertPost(
          content: normalized,
          audience: audience.name,
          aiAssisted: aiAssisted,
        );
        return musubiPostFromDatabaseRow(
          row,
          currentUserId: _service.currentUserId,
        );
      } catch (_) {
        await _service.invokeLegacyFeed(
          'feed.post',
          body: <String, dynamic>{
            'content': normalized,
            'visibility': audience.name,
            'hashtags': const <String>[],
            'ai_assisted': aiAssisted,
          },
        );
      }
    }
    return _localPost(
      content: normalized,
      audience: audience,
      aiAssisted: aiAssisted,
    );
  }

  MusubiPost _localPost({
    required String content,
    required MusubiAudience audience,
    required bool aiAssisted,
  }) {
    final now = DateTime.now();
    return MusubiPost(
      id: 'local-${now.microsecondsSinceEpoch}',
      authorName: 'あなた',
      handle: '@you.musubi',
      avatarLabel: '私',
      content: content,
      createdAt: now,
      community: musubiCommunityForAudience(audience),
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

MusubiPost musubiPostFromDatabaseRow(
  Map<String, dynamic> row, {
  String? currentUserId,
}) {
  final rawProfile = row['musubi_profiles'];
  final profile = rawProfile is Map
      ? Map<String, dynamic>.from(rawProfile)
      : const <String, dynamic>{};
  final authorId = row['author_id']?.toString();
  final audience = MusubiAudience.values.firstWhere(
    (value) => value.name == row['audience']?.toString(),
    orElse: () => MusubiAudience.public,
  );
  final tags = row['tags'] is List
      ? (row['tags'] as List).map((value) => value.toString()).toList()
      : const <String>[];
  return MusubiPost(
    id: row['id']?.toString() ??
        'remote-${DateTime.now().microsecondsSinceEpoch}',
    authorName: profile['display_name']?.toString() ?? 'MUSUBIメンバー',
    handle: '@${profile['handle']?.toString() ?? 'member'}',
    avatarLabel: profile['avatar_label']?.toString() ?? '結',
    content: row['content']?.toString() ?? '',
    createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now(),
    community: musubiCommunityForAudience(audience),
    lenses: <MusubiFeedLens>{
      MusubiFeedLens.resonance,
      if (authorId == currentUserId) MusubiFeedLens.following,
      if (audience == MusubiAudience.local) MusubiFeedLens.local,
      if ((row['resonance'] as num?)?.toInt() case final score?
          when score >= 85)
        MusubiFeedLens.quiet,
    },
    languageLabel: row['language_label']?.toString() ?? '日本語',
    sourceTitle: row['source_title']?.toString(),
    contextNote: row['context_note']?.toString(),
    tags: tags,
    reactions: (row['reaction_count'] as num?)?.toInt() ?? 0,
    replies: (row['reply_count'] as num?)?.toInt() ?? 0,
    boosts: (row['boost_count'] as num?)?.toInt() ?? 0,
    resonance: (row['resonance'] as num?)?.toInt() ?? 80,
    isVerifiedHuman: profile['verified_human'] == true,
    isAiAssisted: row['ai_assisted'] == true,
    isMine: authorId != null && authorId == currentUserId,
  );
}

String musubiCommunityForAudience(MusubiAudience audience) {
  return switch (audience) {
    MusubiAudience.public => 'パブリック',
    MusubiAudience.circles => '信頼サークル',
    MusubiAudience.local => 'ご近所',
  };
}

List<MusubiCommunity> musubiPreviewCommunities() => const <MusubiCommunity>[
      MusubiCommunity(
        id: 'future-cities',
        name: 'やさしい未来都市',
        emoji: '🌱',
        memberLabel: '12.4K 人',
        description: '地域、環境、テクノロジーを実践から話す場所',
        isJoined: true,
        isLive: true,
      ),
      MusubiCommunity(
        id: 'makers',
        name: 'つくる人の広場',
        emoji: '🛠️',
        memberLabel: '8.1K 人',
        description: '完成品より、途中の学びを共有するコミュニティ',
        isJoined: true,
      ),
      MusubiCommunity(
        id: 'slow-news',
        name: 'スローニュース室',
        emoji: '🫧',
        memberLabel: '5.7K 人',
        description: '一次情報と複数視点を確認してから対話する場所',
      ),
    ];

List<MusubiPost> musubiPreviewPosts() {
  final now = DateTime.now();
  return <MusubiPost>[
    MusubiPost(
      id: 'preview-1',
      authorName: '佐伯 ひかり',
      handle: '@hikari.local',
      avatarLabel: '光',
      content:
          '商店街の空き店舗を、週末だけ子どもの工作室として開く実験を始めます。道具を貸せる方、先生役を30分だけできる方を募集しています。',
      createdAt: now.subtract(const Duration(minutes: 8)),
      community: 'やさしい未来都市',
      lenses: const <MusubiFeedLens>{
        MusubiFeedLens.resonance,
        MusubiFeedLens.following,
        MusubiFeedLens.local,
      },
      sourceTitle: '実施概要・安全ガイドライン',
      contextNote: '主催者の本人確認済み。会場使用許可と保険加入を確認しています。',
      tags: const <String>['地域', '子ども', '参加募集'],
      reactions: 184,
      replies: 26,
      boosts: 41,
      resonance: 96,
      isVerifiedHuman: true,
    ),
    MusubiPost(
      id: 'preview-2',
      authorName: 'Maya Chen',
      handle: '@maya.builds',
      avatarLabel: 'MC',
      content:
          'We replaced engagement ranking with a user-controlled mixer. The surprising result: people explored more topics while reporting less fatigue.',
      translatedContent:
          'エンゲージメント順位を、利用者自身が調整できるミキサーに置き換えました。意外にも、疲労感は減り、触れる話題は増えました。',
      languageLabel: 'English',
      createdAt: now.subtract(const Duration(minutes: 31)),
      community: 'つくる人の広場',
      lenses: const <MusubiFeedLens>{
        MusubiFeedLens.resonance,
        MusubiFeedLens.learning,
      },
      sourceTitle: '公開した実験データを見る',
      tags: const <String>['OpenSocial', 'UXResearch'],
      reactions: 329,
      replies: 48,
      boosts: 72,
      resonance: 93,
      isVerifiedHuman: true,
      isAiAssisted: true,
    ),
    MusubiPost(
      id: 'preview-3',
      authorName: '防災ネット みなと',
      handle: '@minato.ready',
      avatarLabel: '港',
      content:
          '本日18時から強い雨の予報です。川沿いの遊歩道は17時に閉鎖されます。避難所ではなく「早めに立ち寄れる休憩所」も3か所開設します。',
      createdAt: now.subtract(const Duration(hours: 1, minutes: 4)),
      community: 'ご近所・港区',
      lenses: const <MusubiFeedLens>{
        MusubiFeedLens.resonance,
        MusubiFeedLens.local,
        MusubiFeedLens.quiet,
      },
      sourceTitle: '自治体防災情報（更新 16:12）',
      contextNote: '位置情報は約3km単位に丸めて照合しています。正確な避難情報は自治体発表を確認してください。',
      tags: const <String>['防災', '港区'],
      reactions: 92,
      replies: 11,
      boosts: 103,
      resonance: 99,
      isVerifiedHuman: true,
      hasCommunityContext: true,
    ),
    MusubiPost(
      id: 'preview-4',
      authorName: '凪 / indie developer',
      handle: '@nagi.dev',
      avatarLabel: '凪',
      content:
          '失敗ログを公開します。新機能を増やすより、通知を半分にした週の方が継続率が上がりました。「戻ってくる理由」と「離れられない仕組み」は別物でした。',
      createdAt: now.subtract(const Duration(hours: 2, minutes: 18)),
      community: 'つくる人の広場',
      lenses: const <MusubiFeedLens>{
        MusubiFeedLens.resonance,
        MusubiFeedLens.following,
        MusubiFeedLens.learning,
        MusubiFeedLens.quiet,
      },
      sourceTitle: '匿名化した4週間のリテンション記録',
      tags: const <String>['BuildInPublic', 'ウェルビーイング'],
      reactions: 511,
      replies: 63,
      boosts: 88,
      resonance: 91,
      isVerifiedHuman: true,
    ),
    MusubiPost(
      id: 'preview-5',
      authorName: 'オープン翻訳サークル',
      handle: '@open-translate',
      avatarLabel: '訳',
      content:
          'ニュースを共有するとき、見出しだけでなく「確認できた事実」「まだ不明な点」「当事者への影響」を3行で添えるテンプレートを公開しました。',
      createdAt: now.subtract(const Duration(hours: 4, minutes: 2)),
      community: 'スローニュース室',
      lenses: const <MusubiFeedLens>{
        MusubiFeedLens.resonance,
        MusubiFeedLens.learning,
        MusubiFeedLens.quiet,
      },
      sourceTitle: '対話を壊さないニュース共有テンプレート CC BY 4.0',
      contextNote: 'コミュニティの7名が原文と翻訳を照合しました。',
      tags: const <String>['メディアリテラシー', '翻訳'],
      reactions: 276,
      replies: 34,
      boosts: 119,
      resonance: 95,
      isVerifiedHuman: true,
      hasCommunityContext: true,
    ),
  ];
}
