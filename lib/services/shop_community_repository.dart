import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop_community.dart';
import 'supabase_client_provider.dart';

abstract interface class ShopCommunityRepository {
  bool get isSignedIn;
  Stream<void> get sessionChanges;
  Future<List<ShopProductRelease>> releases(String productId);
  Future<ShopReviewPage> reviews(String productId, {ShopReview? before});
  Future<ShopReviewContext> ownReview(String productId);
  Future<void> saveReview(String productId, int rating, String body);
  Future<void> deleteReview(String productId, String reviewId);
}

/// RLS/RPC validate ownership and paid status; UI flags are not authority.
class SupabaseShopCommunityRepository implements ShopCommunityRepository {
  SupabaseShopCommunityRepository({SupabaseClient? client})
      : _client = client ?? supabase;

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentUser != null;

  @override
  Stream<void> get sessionChanges =>
      _client.auth.onAuthStateChange.map((_) {});

  @override
  Future<List<ShopProductRelease>> releases(String productId) async {
    final rows = await _client
        .from('shop_product_releases')
        .select('id,version,title_ja,notes_ja,sha256,published_at')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(20);
    return List.unmodifiable(rows.map(ShopProductRelease.fromRow));
  }

  @override
  Future<ShopReviewPage> reviews(String productId, {ShopReview? before}) async {
    final data = await _client.rpc('get_shop_product_reviews', params: {
      'p_product_id': productId,
      if (before != null)
        'p_before_created_at': before.createdAt.toUtc().toIso8601String(),
      if (before != null) 'p_before_id': before.id,
    });
    return ShopReviewPage.fromRow(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<ShopReviewContext> ownReview(String productId) async {
    if (!isSignedIn) return const ShopReviewContext();
    final data = Map<String, dynamic>.from(
      await _client.rpc('get_my_shop_product_review', params: {
        'p_product_id': productId,
      }) as Map,
    );
    return ShopReviewContext(
      canReview: data['can_review'] == true,
      review: data['review'] == null
          ? null
          : ShopReview.fromRow(Map<String, dynamic>.from(data['review'] as Map)),
    );
  }

  @override
  Future<void> saveReview(String productId, int rating, String body) async {
    await _client.rpc('save_shop_product_review', params: {
      'p_product_id': productId,
      'p_rating': rating,
      'p_body': body,
    });
  }

  @override
  Future<void> deleteReview(String productId, String reviewId) async {
    // Returning the affected safe ID distinguishes success from an RLS no-op.
    final rows = await _client
        .from('shop_product_reviews')
        .delete()
        .eq('id', reviewId)
        .eq('product_id', productId)
        .select('id');
    if (rows.length != 1) throw StateError('Review was not deleted');
  }
}
