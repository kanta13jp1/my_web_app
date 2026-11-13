import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../services/shop_service.dart';
import 'data/live_commerce_gateway.dart';
import 'view_models/live_commerce_view_model.dart';
import 'views/live_commerce_page.dart';

class LiveCommerceFeature extends StatelessWidget {
  const LiveCommerceFeature({
    super.key,
    this.gateway,
    this.shopGateway,
    this.initialUri,
  });

  final LiveCommerceGateway? gateway;
  final ShopGateway? shopGateway;
  final Uri? initialUri;

  @override
  Widget build(BuildContext context) {
    final uri = initialUri ?? Uri.base;
    return ChangeNotifierProvider<LiveCommerceViewModel>(
      create: (_) => LiveCommerceViewModel(
        gateway: gateway ?? PreviewLiveCommerceGateway(),
        shopGateway: shopGateway ?? ShopService(),
        roomId: uri.queryParameters['room_id']?.trim().isNotEmpty == true
            ? uri.queryParameters['room_id']!.trim()
            : 'preview-room',
        preferredProductId: uri.queryParameters['product_id'],
      )..load(),
      child: const LiveCommercePage(),
    );
  }
}
