import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/inventory_item_summary.dart';

void main() {
  group('parseInventoryItems', () {
    test('parses nested metadata fields from EF response', () {
      final items = parseInventoryItems({
        'success': true,
        'items': [
          {
            'id': 'a',
            'metadata': {
              'name': 'USB ケーブル',
              'sku': 'USB-001',
              'quantity': 12,
              'price': 500,
              'category': '周辺機器',
              'location': 'A-1',
              'user_id': 'u1',
            },
            'created_at': '2026-07-10T09:00:00Z',
          },
        ],
      });

      final item = items.single;
      expect(item.name, 'USB ケーブル');
      expect(item.sku, 'USB-001');
      expect(item.quantity, 12);
      expect(item.price, 500);
      expect(item.category, '周辺機器');
      expect(item.location, 'A-1');
    });

    test(
        'does NOT fabricate "商品 N" / qty 0 / 在庫不足 for stocked items '
        '(regression: old code read flat name/quantity + phantom minQuantity)',
        () {
      // 旧実装は item['name']/['quantity'] を flat 読み → 捏造 + 存在しない
      // item['minQuantity'] で 0<=0 → 全品「在庫不足」赤バナー。
      final items = parseInventoryItems({
        'items': [
          {
            'metadata': {'name': 'マウス', 'quantity': 25, 'sku': 'M-9'},
            'created_at': '2026-07-12T00:00:00Z',
          },
        ],
      });
      final item = items.single;
      expect(item.name, 'マウス', reason: 'metadata.name を読むべき');
      expect(
        item.name,
        isNot(startsWith('商品 ')),
        reason: 'index ベースの捏造品名を出してはならない',
      );
      expect(item.quantity, 25, reason: 'metadata.quantity を読むべき');
      expect(item.isOutOfStock, isFalse);
      expect(item.isLowStock, isFalse, reason: 'しきい値が無い限り在庫不足を捏造してはならない');
    });

    test('flags out-of-stock only when quantity <= 0', () {
      final items = parseInventoryItems({
        'items': [
          {
            'metadata': {'name': '在庫切れ品', 'quantity': 0},
            'created_at': '',
          },
        ],
      });
      final item = items.single;
      expect(item.isOutOfStock, isTrue);
      expect(item.isLowStock, isFalse, reason: '発注点未設定なので在庫不足ではない');
    });

    test('flags low-stock only when a real reorder point exists', () {
      final items = parseInventoryItems({
        'items': [
          {
            'metadata': {'name': 'A', 'quantity': 3, 'min_quantity': 5},
            'created_at': '',
          },
          {
            'metadata': {'name': 'B', 'quantity': 8, 'minQuantity': 5},
            'created_at': '',
          },
        ],
      });
      expect(items[0].isLowStock, isTrue, reason: '3 <= 5');
      expect(items[1].isLowStock, isFalse, reason: '8 > 5');
    });

    test(
        'parses numeric strings for quantity and leaves price null when absent',
        () {
      final items = parseInventoryItems({
        'items': [
          {
            'metadata': {'name': 'X', 'quantity': '7'},
            'created_at': '',
          },
        ],
      });
      expect(items.single.quantity, 7);
      expect(items.single.price, isNull);
    });

    test('handles null / malformed / bare list responses', () {
      expect(parseInventoryItems(null), isEmpty);
      expect(parseInventoryItems('oops'), isEmpty);
      final bare = parseInventoryItems([
        {
          'metadata': {'name': 'Y', 'quantity': 1},
          'created_at': '',
        },
      ]);
      expect(bare.single.name, 'Y');
    });
  });
}
