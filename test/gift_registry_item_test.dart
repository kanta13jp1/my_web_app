import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/gift_registry_item.dart';

void main() {
  group('parseGiftRegistryItems', () {
    test('parses nested metadata items from EF response', () {
      final items = parseGiftRegistryItems({
        'success': true,
        'items': [
          {
            'id': 'a',
            'metadata': {
              'name': 'コーヒーメーカー',
              'url': 'https://example.com/a',
              'price': 8000,
              'priority': 'high',
              'purchased': false,
              'user_id': 'u1',
            },
            'created_at': '2026-07-10T09:00:00Z',
          },
          {
            'id': 'b',
            'metadata': {
              'name': 'ワイングラス',
              'price': 3500,
              'priority': 'low',
              'purchased': true,
              'user_id': 'u1',
            },
            'created_at': '2026-07-11T12:00:00Z',
          },
        ],
      });

      expect(items.length, 2);

      final first = items[0];
      expect(first.name, 'コーヒーメーカー');
      expect(first.url, 'https://example.com/a');
      expect(first.price, 8000);
      expect(first.priority, 'high');
      expect(first.purchased, isFalse);

      final second = items[1];
      expect(second.name, 'ワイングラス');
      expect(second.price, 3500);
      expect(second.purchased, isTrue);
    });

    test(
        'does NOT fabricate "ギフト N" / missing price / lost 予約済 badge '
        '(regression: old code read flat name/price/reserved)', () {
      // 旧実装は gift['name'] / gift['price'] / gift['reserved'] を読み、
      // 存在しないため全行で品名捏造・価格消失・購入バッジ消失していた。
      final items = parseGiftRegistryItems({
        'items': [
          {
            'metadata': {'name': 'ギフトカード', 'price': 5000, 'purchased': true},
            'created_at': '2026-07-12T00:00:00Z',
          },
        ],
      });
      final item = items.single;
      expect(item.name, 'ギフトカード', reason: 'metadata.name を読むべき');
      expect(
        item.name,
        isNot(startsWith('ギフト ')),
        reason: 'index ベースの捏造品名を出してはならない',
      );
      expect(item.price, 5000, reason: 'metadata.price を読むべき');
      expect(item.hasPrice, isTrue);
      expect(item.purchased, isTrue, reason: 'metadata.purchased を読むべき');
    });

    test('accepts legacy flat keys and "gifts" wrapper', () {
      final items = parseGiftRegistryItems({
        'gifts': [
          {'name': '旧形式', 'price': '1200', 'reserved': true, 'created_at': ''},
        ],
      });
      final item = items.single;
      expect(item.name, '旧形式');
      expect(item.price, 1200);
      expect(item.purchased, isTrue, reason: 'legacy reserved も予約済とみなす');
    });

    test('leaves price null when absent (no ¥0 fabrication)', () {
      final items = parseGiftRegistryItems({
        'items': [
          {
            'metadata': {'name': '値段未定'},
            'created_at': '',
          },
        ],
      });
      final item = items.single;
      expect(item.price, isNull);
      expect(item.hasPrice, isFalse);
      expect(item.priority, 'medium', reason: '既定の優先度');
    });

    test('handles null / malformed responses gracefully', () {
      expect(parseGiftRegistryItems(null), isEmpty);
      expect(parseGiftRegistryItems('oops'), isEmpty);
      expect(parseGiftRegistryItems(<dynamic>[]), isEmpty);
    });

    test('parses a bare list response', () {
      final items = parseGiftRegistryItems([
        {
          'metadata': {'name': 'A', 'price': 100},
          'created_at': '',
        },
      ]);
      expect(items.single.name, 'A');
      expect(items.single.price, 100);
    });
  });

  group('formatGiftPrice', () {
    test('adds thousands separators', () {
      expect(formatGiftPrice(8000), '8,000');
      expect(formatGiftPrice(1000000), '1,000,000');
      expect(formatGiftPrice(500), '500');
    });
  });
}
