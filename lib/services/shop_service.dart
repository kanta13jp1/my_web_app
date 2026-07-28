import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_provider.dart';

/// 買い切り商品の販売・配信まわり (2026-07-28 追加)。
///
/// 対応する裏側:
///  - テーブル `shop_products` / `shop_purchases`
///  - Edge Function `shop-checkout` (Stripe Checkout セッション作成)
///  - Edge Function `shop-download` (購入者にだけ署名付きURLを発行)
///
/// 方針: **金額と権利の判断はこの層で行わない**。価格は Stripe の Price が正であり、
/// 「買ったかどうか」は EF が service role で判定する。クライアント側の判定は
/// 表示の出し分けに使うだけで、これを迂回されても配信は EF 側で止まる。
/// 画面が依存する最小の契約。
///
/// 画面から `SupabaseClient` を直接触らせないために切っている。直接触ると
/// ウィジェットテストが `Supabase.instance` の初期化を要求してしまい、
/// 「4つの状態がそれぞれ正しく描かれるか」を検証できなくなる。
abstract interface class ShopGateway {
  /// ログイン済みか。購入は user_id に紐づくため、未ログインでは購入させない。
  bool get isSignedIn;

  Future<ShopProduct?> fetchProduct(String productId);

  Future<bool> hasPurchased(String productId);

  Future<CheckoutStart> startCheckout(String productId);

  Future<DownloadTicket> requestDownloadUrl(String productId);
}

/// Supabase を実際に叩く実装。
class ShopService implements ShopGateway {
  ShopService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  /// HexCiv Windows 版の商品 ID (migration の初期登録と一致させること)。
  static const String hexcivProductId = 'hexciv-win64';

  @override
  bool get isSignedIn => _client.auth.currentUser != null;

  /// 商品情報を取る。RLS により `is_active = true` のものだけ見える。
  /// 未ログインでも読める (商品ページを見せるため)。
  @override
  Future<ShopProduct?> fetchProduct(String productId) async {
    final row = await _client
        .from('shop_products')
        .select(
          'id, name_ja, summary_ja, price_jpy, version, '
          'file_size_bytes, sha256, stripe_price_id',
        )
        .eq('id', productId)
        .maybeSingle();
    if (row == null) return null;
    return ShopProduct.fromRow(row);
  }

  /// この利用者が購入済みか。未ログインなら false。
  ///
  /// 表示の出し分け用。ここが false でも購入導線を出すだけで、
  /// 実際の配信可否は `shop-download` が改めて判定する。
  @override
  Future<bool> hasPurchased(String productId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('shop_purchases')
        .select('id')
        .eq('user_id', user.id)
        .eq('product_id', productId)
        .eq('status', 'paid')
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  /// Stripe Checkout を開始する。
  ///
  /// 既に購入済みの場合、EF は課金せずに `already_purchased` を返す。
  /// 買い直しではなく再ダウンロードへ誘導したいため、二重課金させない。
  @override
  Future<CheckoutStart> startCheckout(String productId) async {
    final response = await _client.functions.invoke(
      'shop-checkout',
      body: {'product_id': productId},
    );
    final data = _asMap(response.data);
    if (data == null) {
      throw const ShopException('購入手続きを開始できませんでした');
    }
    if (data['already_purchased'] == true) {
      return const CheckoutStart.alreadyPurchased();
    }
    final url = data['checkout_url'] as String?;
    if (url == null || url.isEmpty) {
      throw ShopException(_messageFrom(data, '購入手続きを開始できませんでした'));
    }
    return CheckoutStart.redirect(url);
  }

  /// 購入者向けのダウンロードURLを発行する。
  ///
  /// 返る URL は**有効期限つき**(既定5分)。画面側で保持して使い回さず、
  /// 押されたタイミングで都度取り直す前提。
  @override
  Future<DownloadTicket> requestDownloadUrl(String productId) async {
    final response = await _client.functions.invoke(
      'shop-download',
      body: {'product_id': productId},
    );
    final data = _asMap(response.data);
    if (data == null) {
      throw const ShopException('ダウンロードURLを取得できませんでした');
    }
    final url = data['download_url'] as String?;
    if (url == null || url.isEmpty) {
      throw ShopException(_messageFrom(data, 'ダウンロードURLを取得できませんでした'));
    }
    return DownloadTicket(
      url: url,
      expiresInSeconds: (data['expires_in_seconds'] as num?)?.toInt() ?? 0,
      version: data['version'] as String? ?? '',
      sha256: data['sha256'] as String? ?? '',
      fileSizeBytes: (data['file_size_bytes'] as num?)?.toInt(),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// EF が返したエラー文をそのまま見せる。原因が分からないまま
  /// 「失敗しました」だけ出すと、設定漏れなのか権利が無いのか切り分けられない。
  static String _messageFrom(Map<String, dynamic> data, String fallback) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
    return fallback;
  }
}

/// 商品1件。
class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.nameJa,
    required this.summaryJa,
    required this.priceJpy,
    required this.version,
    required this.fileSizeBytes,
    required this.sha256,
    required this.isPurchasable,
  });

  factory ShopProduct.fromRow(Map<String, dynamic> row) {
    final priceId = row['stripe_price_id'] as String?;
    return ShopProduct(
      id: row['id'] as String? ?? '',
      nameJa: row['name_ja'] as String? ?? '',
      summaryJa: row['summary_ja'] as String? ?? '',
      priceJpy: (row['price_jpy'] as num?)?.toInt() ?? 0,
      version: row['version'] as String? ?? '',
      fileSizeBytes: (row['file_size_bytes'] as num?)?.toInt(),
      sha256: row['sha256'] as String? ?? '',
      // Price 未設定のまま購入ボタンを出すと、押した先で必ず失敗する。
      // 「買えるように見えて買えない」を作らないため、ここで判定しておく。
      isPurchasable: priceId != null && priceId.trim().isNotEmpty,
    );
  }

  final String id;
  final String nameJa;
  final String summaryJa;
  final int priceJpy;
  final String version;
  final int? fileSizeBytes;
  final String sha256;

  /// Stripe の Price が設定済みで、実際に購入手続きへ進めるか。
  final bool isPurchasable;
}

/// 購入開始の結果。
class CheckoutStart {
  const CheckoutStart.redirect(this.checkoutUrl) : alreadyPurchased = false;
  const CheckoutStart.alreadyPurchased()
      : checkoutUrl = null,
        alreadyPurchased = true;

  final String? checkoutUrl;
  final bool alreadyPurchased;
}

/// 発行されたダウンロードURLと、その付帯情報。
class DownloadTicket {
  const DownloadTicket({
    required this.url,
    required this.expiresInSeconds,
    required this.version,
    required this.sha256,
    required this.fileSizeBytes,
  });

  final String url;
  final int expiresInSeconds;
  final String version;

  /// 落としたファイルの同一性を購入者自身が確認できるようにするための値。
  final String sha256;
  final int? fileSizeBytes;
}

class ShopException implements Exception {
  const ShopException(this.message);

  final String message;

  @override
  String toString() => message;
}
