import 'dart:async';

import 'package:my_web_app/models/shop_community.dart';
import 'package:my_web_app/services/shop_community_repository.dart';

class FakeShopCommunity implements ShopCommunityRepository {
  bool signedIn = true;
  bool paid = true;
  bool failRead = false;
  bool failWrite = false;
  int saves = 0;
  int deletes = 0;
  ShopReview? saved;
  Completer<void>? writeGate;
  Completer<void>? readGate;
  final sessions = StreamController<void>.broadcast(sync: true);
  final List<ShopReview> publicItems = [];
  List<ShopProductRelease> releaseItems = const [];

  @override
  bool get isSignedIn => signedIn;
  @override
  Stream<void> get sessionChanges => sessions.stream;

  @override
  Future<List<ShopProductRelease>> releases(String productId) async {
    await readGate?.future;
    if (failRead) throw StateError('private-internal-error');
    return releaseItems;
  }

  @override
  Future<ShopReviewPage> reviews(String productId, {ShopReview? before}) async {
    await readGate?.future;
    if (failRead) throw StateError('private-internal-error');
    final items = [if (saved != null && saved!.isVisible) saved!, ...publicItems];
    final offset = before == null ? 0 : items.indexWhere((r) => r.id == before.id) + 1;
    return ShopReviewPage(
      items: items.skip(offset).take(10).toList(),
      count: items.length,
      average: items.isEmpty ? null : items.fold<int>(0, (s, r) => s + r.rating) / items.length,
      hasMore: items.length > offset + 10,
    );
  }

  @override
  Future<ShopReviewContext> ownReview(String productId) async {
    await readGate?.future;
    if (failRead) throw StateError('private-internal-error');
    return ShopReviewContext(review: signedIn ? saved : null, canReview: signedIn && paid);
  }

  @override
  Future<void> saveReview(String productId, int rating, String body) async {
    saves++;
    await writeGate?.future;
    if (failWrite || !signedIn || !paid) throw StateError('private-internal-error');
    saved = review('own', rating: rating, body: body);
  }

  @override
  Future<void> deleteReview(String productId, String reviewId) async {
    deletes++;
    if (failWrite || !signedIn || saved?.id != reviewId) throw StateError('private-internal-error');
    saved = null;
  }

  static ShopReview review(String id, {int rating = 4, String body = '楽しく遊べました。'}) => ShopReview(
    id: id, rating: rating, body: body, postedVersion: '1.0',
    createdAt: DateTime.utc(2026, 9, 12), updatedAt: DateTime.utc(2026, 9, 12),
  );
}
