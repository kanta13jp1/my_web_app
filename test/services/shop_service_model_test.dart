import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/shop_service.dart';

void main() {
  test('ShopProduct parses all supported digital product types', () {
    for (final type in ShopProductType.values) {
      final product = ShopProduct.fromRow({
        'id': 'product-${type.databaseValue}',
        'name_ja': type.labelJa,
        'summary_ja': 'summary',
        'price_jpy': 500,
        'version': '1.0',
        'stripe_price_id': 'price_123',
        'product_type': type.databaseValue,
        'format_label': 'ZIP',
        'requirements_ja': '利用条件',
        'license_summary_ja': 'ライセンス',
        'download_file_name': 'asset.zip',
        'sort_order': 10,
      });

      expect(product.type, type);
      expect(product.isPurchasable, isTrue);
      expect(product.downloadFileName, 'asset.zip');
    }
  });

  test('catalog rows omit detail payloads and still use safe fallbacks', () {
    final product = ShopProduct.fromRow({
      'id': 'legacy',
      'name_ja': '旧商品',
      'summary_ja': '一覧の説明',
      'price_jpy': 100,
      'version': '1',
      'product_type': 'unknown',
    });

    expect(product.type, ShopProductType.template);
    expect(product.effectiveDescription, '一覧の説明');
    expect(product.isPurchasable, isFalse);
  });
}
