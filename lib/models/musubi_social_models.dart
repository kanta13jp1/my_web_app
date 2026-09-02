enum MusubiFeedLens { resonance, following, local, learning, quiet }

enum MusubiAudience { public, circles, local }

class MusubiPost {
  const MusubiPost({
    required this.id,
    required this.authorName,
    required this.handle,
    required this.avatarLabel,
    required this.content,
    required this.createdAt,
    required this.community,
    required this.lenses,
    this.translatedContent,
    this.languageLabel = '日本語',
    this.sourceTitle,
    this.contextNote,
    this.tags = const <String>[],
    this.reactions = 0,
    this.replies = 0,
    this.boosts = 0,
    this.resonance = 0,
    this.isVerifiedHuman = false,
    this.isAiAssisted = false,
    this.hasCommunityContext = false,
    this.isLiked = false,
    this.isBookmarked = false,
    this.isMine = false,
  });

  final String id;
  final String authorName;
  final String handle;
  final String avatarLabel;
  final String content;
  final String? translatedContent;
  final String languageLabel;
  final DateTime createdAt;
  final String community;
  final Set<MusubiFeedLens> lenses;
  final String? sourceTitle;
  final String? contextNote;
  final List<String> tags;
  final int reactions;
  final int replies;
  final int boosts;
  final int resonance;
  final bool isVerifiedHuman;
  final bool isAiAssisted;
  final bool hasCommunityContext;
  final bool isLiked;
  final bool isBookmarked;
  final bool isMine;

  MusubiPost copyWith({
    int? reactions,
    int? replies,
    int? boosts,
    int? resonance,
    bool? isLiked,
    bool? isBookmarked,
  }) {
    return MusubiPost(
      id: id,
      authorName: authorName,
      handle: handle,
      avatarLabel: avatarLabel,
      content: content,
      translatedContent: translatedContent,
      languageLabel: languageLabel,
      createdAt: createdAt,
      community: community,
      lenses: lenses,
      sourceTitle: sourceTitle,
      contextNote: contextNote,
      tags: tags,
      reactions: reactions ?? this.reactions,
      replies: replies ?? this.replies,
      boosts: boosts ?? this.boosts,
      resonance: resonance ?? this.resonance,
      isVerifiedHuman: isVerifiedHuman,
      isAiAssisted: isAiAssisted,
      hasCommunityContext: hasCommunityContext,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isMine: isMine,
    );
  }
}

class MusubiCommunity {
  const MusubiCommunity({
    required this.id,
    required this.name,
    required this.emoji,
    required this.memberLabel,
    required this.description,
    this.isJoined = false,
    this.isLive = false,
  });

  final String id;
  final String name;
  final String emoji;
  final String memberLabel;
  final String description;
  final bool isJoined;
  final bool isLive;
}

class MusubiFeedPreferences {
  const MusubiFeedPreferences({
    this.discovery = 28,
    this.local = 22,
    this.chronological = true,
    this.hideUnlabeledAi = true,
    this.pauseInfiniteScroll = true,
  });

  final double discovery;
  final double local;
  final bool chronological;
  final bool hideUnlabeledAi;
  final bool pauseInfiniteScroll;

  MusubiFeedPreferences copyWith({
    double? discovery,
    double? local,
    bool? chronological,
    bool? hideUnlabeledAi,
    bool? pauseInfiniteScroll,
  }) {
    return MusubiFeedPreferences(
      discovery: discovery ?? this.discovery,
      local: local ?? this.local,
      chronological: chronological ?? this.chronological,
      hideUnlabeledAi: hideUnlabeledAi ?? this.hideUnlabeledAi,
      pauseInfiniteScroll: pauseInfiniteScroll ?? this.pauseInfiniteScroll,
    );
  }
}
