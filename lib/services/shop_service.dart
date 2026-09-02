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

  /// 販売中の商品一覧。RLS により公開可能な行だけが返る。
  Future<List<ShopProduct>> fetchProducts({ShopProductType? type});

  Future<ShopProduct?> fetchProduct(String productId);

  Future<bool> hasPurchased(String productId);

  /// ログイン中の利用者が購入済みの商品。未ログインなら空配列を返す。
  Future<List<ShopPurchase>> fetchPurchases();

  /// [visitorId] と [source] は funnel の最終段をサーバ側で記録するために
  /// Stripe の metadata へ載せる。省略しても購入自体は成立する。
  Future<CheckoutStart> startCheckout(
    String productId, {
    String? visitorId,
    String? source,
  });

  Future<DownloadTicket> requestDownloadUrl(String productId);
}

/// Supabase を実際に叩く実装。
class ShopService implements ShopGateway {
  ShopService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  /// HexCiv Windows 版の商品 ID (migration の初期登録と一致させること)。
  static const String hexcivProductId = 'hexciv-win64';

  static const String _catalogColumns =
      'id, name_ja, summary_ja, price_jpy, version, file_size_bytes, '
      'stripe_price_id, product_type, format_label, preview_image_url, '
      'sort_order, published_at';

  static const String _detailColumns =
      '$_catalogColumns, sha256, description_ja, requirements_ja, '
      'license_summary_ja, download_file_name';

  @override
  bool get isSignedIn => _client.auth.currentUser != null;

  @override
  Future<List<ShopProduct>> fetchProducts({ShopProductType? type}) async {
    // 一覧では長文 description_ja やライセンス本文を取らない。商品数が増えても
    // 無制限転送にならないよう、表示順つきで100件に制限する。
    final List<dynamic> rows;
    if (type == null) {
      rows = await _client
          .from('shop_products')
          .select(_catalogColumns)
          .order('sort_order')
          .order('id')
          .limit(100);
    } else {
      rows = await _client
          .from('shop_products')
          .select(_catalogColumns)
          .eq('product_type', type.databaseValue)
          .order('sort_order')
          .order('id')
          .limit(100);
    }
    return rows
        .map(
          (row) => ShopProduct.fromRow(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  /// 商品情報を取る。RLS により `is_active = true` のものだけ見える。
  /// 未ログインでも読める (商品ページを見せるため)。
  @override
  Future<ShopProduct?> fetchProduct(String productId) async {
    final row = await _client
        .from('shop_products')
        .select(_detailColumns)
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

  @override
  Future<List<ShopPurchase>> fetchPurchases() async {
    if (_client.auth.currentUser == null) return const [];
    // shop_purchases の本人RLSと shop_products_buyer_read の両方を通る。
    // 商品ごとの追加取得を避け、購入情報と商品を1リクエストで取得する。
    final rows = await _client
        .from('shop_purchases')
        .select('id, purchased_at, shop_products!inner($_detailColumns)')
        .eq('status', 'paid')
        .order('purchased_at', ascending: false)
        .limit(100);
    return (rows as List<dynamic>).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final productRow = Map<String, dynamic>.from(
        map['shop_products'] as Map,
      );
      return ShopPurchase.fromRow(map, productRow: productRow);
    }).toList(growable: false);
  }

  /// Stripe Checkout を開始する。
  ///
  /// 既に購入済みの場合、EF は課金せずに `already_purchased` を返す。
  /// 買い直しではなく再ダウンロードへ誘導したいため、二重課金させない。
  @override
  Future<CheckoutStart> startCheckout(
    String productId, {
    String? visitorId,
    String? source,
  }) async {
    final response = await _client.functions.invoke(
      'shop-checkout',
      body: {
        'product_id': productId,
        // funnel の最終段を webhook 側で書くために持ち回す。
        // 無くても購入は成立する (計測が欠けるだけ)。
        if (visitorId != null && visitorId.isNotEmpty) 'visitor_id': visitorId,
        if (source != null && source.isNotEmpty) 'source': source,
      },
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
      fileName: data['file_name'] as String? ?? '',
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
    this.type = ShopProductType.game,
    this.descriptionJa = '',
    this.formatLabel = 'ZIP',
    this.requirementsJa = 'ダウンロード後、対応アプリでご利用ください。',
    this.licenseSummaryJa = '購入者本人による利用に限ります。素材そのものの再配布・再販売はできません。',
    this.downloadFileName = 'digital-product.zip',
    this.previewImageUrl,
    this.sortOrder = 100,
    this.publishedAt,
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
      type: ShopProductType.fromDatabase(row['product_type'] as String?),
      descriptionJa: row['description_ja'] as String? ?? '',
      formatLabel: row['format_label'] as String? ?? 'ZIP',
      requirementsJa:
          row['requirements_ja'] as String? ?? 'ダウンロード後、対応アプリでご利用ください。',
      licenseSummaryJa: row['license_summary_ja'] as String? ??
          '購入者本人による利用に限ります。素材そのものの再配布・再販売はできません。',
      downloadFileName:
          row['download_file_name'] as String? ?? 'digital-product.zip',
      previewImageUrl: row['preview_image_url'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      publishedAt: DateTime.tryParse(row['published_at'] as String? ?? ''),
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
  final ShopProductType type;
  final String descriptionJa;
  final String formatLabel;
  final String requirementsJa;
  final String licenseSummaryJa;
  final String downloadFileName;
  final String? previewImageUrl;
  final int sortOrder;
  final DateTime? publishedAt;

  /// Stripe の Price が設定済みで、実際に購入手続きへ進めるか。
  final bool isPurchasable;

  String get effectiveDescription =>
      descriptionJa.trim().isEmpty ? summaryJa : descriptionJa;
}

enum ShopProductType {
  image('image', '画像'),
  audio('audio', '音声'),
  video('video', '動画'),
  design('design', 'デザイン'),
  writing('writing', '文章'),
  prompt('prompt', 'プロンプト'),
  idea('idea', 'アイデア'),
  game('game', 'ゲーム'),
  application('application', 'アプリ'),
  template('template', 'テンプレート');

  const ShopProductType(this.databaseValue, this.labelJa);

  factory ShopProductType.fromDatabase(String? value) {
    return values.firstWhere(
      (type) => type.databaseValue == value,
      orElse: () => ShopProductType.template,
    );
  }

  final String databaseValue;
  final String labelJa;
}

class ShopPurchase {
  const ShopPurchase({
    required this.id,
    required this.product,
    required this.purchasedAt,
  });

  factory ShopPurchase.fromRow(
    Map<String, dynamic> row, {
    required Map<String, dynamic> productRow,
  }) {
    return ShopPurchase(
      id: row['id'] as String? ?? '',
      product: ShopProduct.fromRow(productRow),
      purchasedAt: DateTime.tryParse(row['purchased_at'] as String? ?? ''),
    );
  }

  final String id;
  final ShopProduct product;
  final DateTime? purchasedAt;
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
    this.fileName = '',
  });

  final String url;
  final int expiresInSeconds;
  final String version;

  /// 落としたファイルの同一性を購入者自身が確認できるようにするための値。
  final String sha256;
  final int? fileSizeBytes;
  final String fileName;
}

class ShopException implements Exception {
  const ShopException(this.message);

  final String message;

  @override
  String toString() => message;
}
