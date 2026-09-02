import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/musubi_engagement_models.dart';
import '../models/musubi_social_models.dart';
import 'musubi_engagement_repository.dart';
import 'musubi_social_repository.dart';

class MusubiSocialController extends ChangeNotifier {
  MusubiSocialController({
    MusubiSocialRepository? repository,
    MusubiRealtimeRepository? realtimeRepository,
  })  : _repository = repository ?? SupabaseMusubiSocialRepository(),
        _realtimeRepository = realtimeRepository {
    _posts = List<MusubiPost>.of(_repository.previewPosts);
    _communities = List<MusubiCommunity>.of(musubiPreviewCommunities());
  }

  final MusubiSocialRepository _repository;
  final MusubiRealtimeRepository? _realtimeRepository;
  StreamSubscription<List<MusubiPost>>? _realtimeSubscription;
  late List<MusubiPost> _posts;
  late List<MusubiCommunity> _communities;
  MusubiFeedLens _activeLens = MusubiFeedLens.resonance;
  MusubiAudience _audience = MusubiAudience.public;
  MusubiFeedPreferences _preferences = const MusubiFeedPreferences();
  bool _isLoading = false;
  bool _isPosting = false;
  bool _aiAssisted = false;
  String? _notice;
  MusubiRealtimeState _realtimeState = MusubiRealtimeState.preview;

  MusubiFeedLens get activeLens => _activeLens;
  MusubiAudience get audience => _audience;
  MusubiFeedPreferences get preferences => _preferences;
  List<MusubiCommunity> get communities => List.unmodifiable(_communities);
  bool get isLoading => _isLoading;
  bool get isPosting => _isPosting;
  bool get aiAssisted => _aiAssisted;
  String? get notice => _notice;
  MusubiRealtimeState get realtimeState => _realtimeState;
  List<MusubiPost> get bookmarkedPosts =>
      List.unmodifiable(_posts.where((post) => post.isBookmarked));

  List<MusubiPost> get visiblePosts {
    final filtered = _posts
        .where((post) => post.lenses.contains(_activeLens))
        .where(
          (post) =>
              !_preferences.hideUnlabeledAi ||
              !post.isAiAssisted ||
              post.translatedContent != null ||
              post.isMine,
        )
        .toList();
    if (_preferences.chronological) {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      filtered.sort((a, b) => b.resonance.compareTo(a.resonance));
    }
    return filtered;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      _posts = List<MusubiPost>.of(await _repository.loadPosts());
    } catch (_) {
      _notice = 'ネットワークに接続できないため、プレビューフィードを表示しています。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await connectRealtime();
  }

  Future<void> connectRealtime() async {
    await _realtimeSubscription?.cancel();
    final realtime = _realtimeRepository;
    if (realtime == null || realtime.isPreview) {
      _realtimeState = MusubiRealtimeState.preview;
      notifyListeners();
      return;
    }
    _realtimeState = MusubiRealtimeState.connecting;
    notifyListeners();
    _realtimeSubscription = realtime.watchFeed().listen(
      (livePosts) {
        final previewIds =
            _repository.previewPosts.map((post) => post.id).toSet();
        final localOnly = _posts.where(
          (post) =>
              post.id.startsWith('local-') &&
              !livePosts.any((live) => live.content == post.content),
        );
        _posts = <MusubiPost>[
          ...livePosts,
          ...localOnly,
          ..._repository.previewPosts.where(
            (post) =>
                previewIds.contains(post.id) &&
                !livePosts.any((live) => live.id == post.id),
          ),
        ];
        _realtimeState = MusubiRealtimeState.connected;
        notifyListeners();
      },
      onError: (_) {
        _realtimeState = MusubiRealtimeState.degraded;
        _notice = 'リアルタイム配信が中断しました。表示中の投稿はそのまま読めます。';
        notifyListeners();
      },
    );
  }

  void setLens(MusubiFeedLens lens) {
    if (_activeLens == lens) return;
    _activeLens = lens;
    notifyListeners();
  }

  void setAudience(MusubiAudience audience) {
    if (_audience == audience) return;
    _audience = audience;
    notifyListeners();
  }

  void setAiAssisted(bool value) {
    if (_aiAssisted == value) return;
    _aiAssisted = value;
    notifyListeners();
  }

  void updateDiscovery(double value) {
    _preferences = _preferences.copyWith(discovery: value);
    notifyListeners();
  }

  void updateLocal(double value) {
    _preferences = _preferences.copyWith(local: value);
    notifyListeners();
  }

  void setChronological(bool value) {
    _preferences = _preferences.copyWith(chronological: value);
    notifyListeners();
  }

  void setHideUnlabeledAi(bool value) {
    _preferences = _preferences.copyWith(hideUnlabeledAi: value);
    notifyListeners();
  }

  void setPauseInfiniteScroll(bool value) {
    _preferences = _preferences.copyWith(pauseInfiniteScroll: value);
    notifyListeners();
  }

  Future<bool> createPost(String content) async {
    if (content.trim().isEmpty || _isPosting) return false;
    _isPosting = true;
    _notice = null;
    notifyListeners();
    try {
      final post = await _repository.createPost(
        content: content,
        audience: _audience,
        aiAssisted: _aiAssisted,
      );
      _posts.insert(0, post);
      _activeLens = MusubiFeedLens.resonance;
      _aiAssisted = false;
      _notice = '投稿しました。公開範囲とAI利用表示はいつでも変更できます。';
      return true;
    } catch (_) {
      _notice = '投稿を保存できませんでした。接続を確認して再試行してください。';
      return false;
    } finally {
      _isPosting = false;
      notifyListeners();
    }
  }

  void toggleLike(String postId) {
    _replacePost(postId, (post) {
      final nextLiked = !post.isLiked;
      return post.copyWith(
        isLiked: nextLiked,
        reactions: (post.reactions + (nextLiked ? 1 : -1)).clamp(0, 1 << 30),
      );
    });
  }

  void toggleBookmark(String postId) {
    _replacePost(
      postId,
      (post) => post.copyWith(isBookmarked: !post.isBookmarked),
    );
  }

  void toggleCommunity(String communityId) {
    final index = _communities.indexWhere((item) => item.id == communityId);
    if (index < 0) return;
    final item = _communities[index];
    _communities[index] = MusubiCommunity(
      id: item.id,
      name: item.name,
      emoji: item.emoji,
      memberLabel: item.memberLabel,
      description: item.description,
      isJoined: !item.isJoined,
      isLive: item.isLive,
    );
    notifyListeners();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  void _replacePost(String postId, MusubiPost Function(MusubiPost) update) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return;
    _posts[index] = update(_posts[index]);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_realtimeSubscription?.cancel());
    super.dispose();
  }
}
