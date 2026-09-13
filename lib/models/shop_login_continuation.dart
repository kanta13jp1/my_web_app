import 'shop_attribution.dart';

/// Product-only navigation. No arbitrary return URL, persistent cross-tab state,
/// access token, claimed purchase result or visitor identity is copied.
class ShopLoginContinuation {
  static final _productIdPattern =
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$');

  static Uri loginUri({
    required String productId,
    required ShopAttribution attribution,
  }) {
    if (!_productIdPattern.hasMatch(productId)) return Uri(path: '/login');
    return Uri(
      path: '/login',
      queryParameters: {'shop_product': productId, ...attribution.toQuery()},
    );
  }

  static Uri? productUri(Uri? loginLocation) {
    if (loginLocation == null || loginLocation.path != '/login') return null;
    final products = loginLocation.queryParametersAll['shop_product'];
    if (products == null ||
        products.length != 1 ||
        !_productIdPattern.hasMatch(products.single)) {
      return null;
    }
    return Uri(
      path: '/shop/product',
      queryParameters: {
        'product_id': products.single,
        ...ShopAttribution.fromUri(loginLocation).toQuery(),
      },
    );
  }

  /// The real application's origin is trusted; parameters from the route are
  /// allowlisted above. Supabase's approved redirect list must allow this path.
  static Uri? callbackUri({required Uri base, required Uri? loginLocation}) {
    final product = productUri(loginLocation);
    if (product == null ||
        !['http', 'https'].contains(base.scheme) ||
        base.host.isEmpty) {
      return null;
    }
    final login = loginUri(
      productId: product.queryParameters['product_id']!,
      attribution: ShopAttribution.fromUri(product),
    );
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: login.path,
      queryParameters: login.queryParameters,
    );
  }
}
