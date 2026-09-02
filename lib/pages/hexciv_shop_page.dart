import 'package:flutter/material.dart';

import '../services/shop_funnel_service.dart';
import '../services/shop_service.dart';
import 'digital_product_store_pages.dart';

/// 既存の公開URLを保つための後方互換ラッパー。
///
/// HexCiv も汎用デジタル商品と同じ購入・権利・配信フローを使う。商品ごとに
/// 専用ページを増やさず、今後の追加商品は `/shop/product?product_id=...` で表示する。
class HexcivShopPage extends StatelessWidget {
  const HexcivShopPage({
    super.key,
    this.purchaseResult,
    this.service,
    this.funnel,
    this.urlLauncher,
  });

  final String? purchaseResult;
  final ShopGateway? service;
  final ShopFunnelService? funnel;
  final ShopUrlLauncher? urlLauncher;

  @override
  Widget build(BuildContext context) {
    return DigitalProductPage(
      productId: ShopService.hexcivProductId,
      purchaseResult: purchaseResult,
      service: service,
      funnel: funnel,
      urlLauncher: urlLauncher,
    );
  }
}
