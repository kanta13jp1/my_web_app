import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client_provider.dart';

/// 販売 funnel の到達を記録する (2026-07-29 追加)。
///
/// 現状は購入完了しか記録が無く、「どこで落ちているか」が分からない。
/// 閲覧・購入ボタン押下・Checkout 到達を数えて、施策の効果を判定できるようにする。
///
/// 方針:
///  * **計測の失敗で画面を止めない**。ここは本体機能ではないので、
///    どんな失敗も握り潰して呼び出し元へは影響させない。
///  * **流入元 (source) を必ず持たせる**。itch.io / X / 直接流入を区別できないと
///    「どのチャネルが効いたか」が最後まで分からない。これが計測の主目的。
///  * `purchase_complete` はここから送らない。金銭の絡む段だけは
///    クライアントの自己申告を信じず、webhook がサーバ側で記録する。
class ShopFunnelService {
  ShopFunnelService({SupabaseClient? client}) : _client = client ?? supabase;

  final SupabaseClient _client;

  /// 訪問者IDの保存キー。個人とは結び付かない乱数を1つ持つだけ。
  static const String _visitorKey = 'shop.visitor_id';

  String? _cachedVisitorId;

  /// 閲覧。
  static const String stageProductView = 'product_view';

  /// 購入ボタンが押された。
  static const String stagePurchaseClick = 'purchase_click';

  /// Stripe の Checkout URL が返った。
  static const String stageCheckoutRedirect = 'checkout_redirect';

  /// 訪問者IDを取得する (無ければ作って保存する)。
  ///
  /// 端末内に留まる乱数で、こちらから人物へは辿れない。
  /// 取得に失敗した場合は null を返し、計測を諦める (画面は動かす)。
  Future<String?> visitorId() async {
    final cached = _cachedVisitorId;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_visitorKey);
      if (id == null || id.isEmpty) {
        id = _newUuidV4();
        await prefs.setString(_visitorKey, id);
      }
      _cachedVisitorId = id;
      return id;
    } catch (_) {
      return null;
    }
  }

  /// 1段を記録する。**例外は投げない**。
  ///
  /// [source] は流入元。URL の `utm_source` を渡す想定で、無ければ 'direct'。
  Future<void> record(
    String stage, {
    required String productId,
    String? source,
    String? campaign,
  }) async {
    try {
      final visitor = await visitorId();
      if (visitor == null) return;
      await _client.functions.invoke(
        'shop-funnel',
        body: {
          'visitor_id': visitor,
          'product_id': productId,
          'stage': stage,
          'source': _normalize(source) ?? 'direct',
          'campaign': _normalize(campaign) ?? '',
        },
      );
    } catch (_) {
      // 計測できなくても購入体験は続ける。
    }
  }

  /// EF 側の文字種制限に合わせて正規化する。
  ///
  /// 弾かれる値を送ると、その段が丸ごと欠測して母数が合わなくなるので、
  /// 送る前にこちら側で整えておく。整えられない場合は null を返す。
  static String? _normalize(String? raw) {
    if (raw == null) return null;
    final lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty) return null;
    final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    if (cleaned.isEmpty) return null;
    return cleaned.length <= 64 ? cleaned : cleaned.substring(0, 64);
  }

  /// 流入元を URL のクエリから取り出す。無ければ 'direct'。
  static String sourceFromUri(Uri uri) {
    final utm = uri.queryParameters['utm_source'];
    return _normalize(utm) ?? 'direct';
  }

  /// キャンペーンを URL のクエリから取り出す。無ければ空。
  static String campaignFromUri(Uri uri) {
    return _normalize(uri.queryParameters['utm_campaign']) ?? '';
  }

  static final Random _random = Random.secure();

  /// UUID v4。外部依存を増やさずに済ませる。
  static String _newUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}
