import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/shop_community.dart';
import '../services/shop_community_repository.dart';

class ShopCommunityViewModel extends ChangeNotifier {
  ShopCommunityViewModel({required this.productId, required this.repository}) {
    _sessionSubscription = repository.sessionChanges.listen((_) {
      sessionRevision++;
      own = const ShopReviewContext();
      notice = null;
      actionError = null;
      unawaited(load());
    });
  }

  final String productId;
  final ShopCommunityRepository repository;
  late final StreamSubscription<void> _sessionSubscription;
  int _revision = 0;
  bool _disposed = false;
  bool loading = false;
  bool paging = false;
  bool working = false;
  int pageNumber = 1;
  int sessionRevision = 0;
  String? releaseError;
  String? reviewError;
  String? ownerError;
  String? actionError;
  String? notice;
  List<ShopProductRelease> releases = const [];
  ShopReviewPage? page;
  ShopReviewContext own = const ShopReviewContext();

  bool get signedIn => repository.isSignedIn;
  bool get canReview => signedIn && !loading && ownerError == null && own.canReview;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final revision = ++_revision;
    loading = true;
    paging = false;
    releaseError = null;
    reviewError = null;
    ownerError = null;
    pageNumber = 1;
    _notify();
    await Future.wait([
      () async {
        try {
          final value = await repository.releases(productId);
          if (revision == _revision) releases = value;
        } catch (_) {
          if (revision == _revision) releaseError = '更新情報を読み込めませんでした。';
        }
      }(),
      () async {
        try {
          final value = await repository.reviews(productId);
          if (revision == _revision) page = value;
        } catch (_) {
          if (revision == _revision) reviewError = '口コミ・評価を読み込めませんでした。';
        }
      }(),
      () async {
        try {
          final value = await repository.ownReview(productId);
          if (revision == _revision) own = value;
        } catch (_) {
          if (revision == _revision) ownerError = '投稿権限を確認できませんでした。';
        }
      }(),
    ]);
    if (revision != _revision || _disposed) return;
    loading = false;
    _notify();
  }

  Future<void> nextPage() async {
    if (paging || loading || working || page == null || !page!.hasMore) return;
    final revision = _revision;
    paging = true;
    reviewError = null;
    _notify();
    try {
      final value = await repository.reviews(productId, before: page!.items.last);
      if (revision == _revision) {
        page = value;
        pageNumber++;
      }
    } catch (_) {
      if (revision == _revision) reviewError = '続きの口コミを読み込めませんでした。';
    } finally {
      if (revision == _revision) {
        paging = false;
        _notify();
      }
    }
  }

  Future<bool> save(int rating, String body) async {
    if (working) return false;
    actionError = null;
    if (!canReview) {
      actionError = 'ログインと購入状況を確認して、再読み込みしてください。';
      _notify();
      return false;
    }
    if (rating < 1 || rating > 5 || body.runes.length > 2000) {
      actionError = '星を1〜5で選び、口コミを2000文字以内にしてください。';
      _notify();
      return false;
    }
    return _mutate(() => repository.saveReview(productId, rating, body.trim()),
        '口コミ・評価を保存しました。');
  }

  Future<bool> delete() async {
    if (working || loading || !signedIn || own.review == null) return false;
    final id = own.review!.id;
    return _mutate(() => repository.deleteReview(productId, id), '口コミ・評価を削除しました。');
  }

  Future<bool> _mutate(Future<void> Function() action, String success) async {
    final startedSession = sessionRevision;
    working = true;
    actionError = null;
    notice = null;
    _notify();
    try {
      await action();
      if (_disposed || startedSession != sessionRevision) return false;
      notice = success;
      await load();
      return true;
    } catch (_) {
      if (startedSession == sessionRevision) {
        actionError = '保存内容を確認できませんでした。再読み込みしてからお試しください。';
      }
      return false;
    } finally {
      working = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    unawaited(_sessionSubscription.cancel());
    super.dispose();
  }
}
