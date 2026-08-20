import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baseMigration =
    'supabase/migrations/20260728010000_create_shop_product_downloads.sql';
const _catalogMigration =
    'supabase/migrations/20260821015546_generalize_digital_product_store.sql';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n').toLowerCase();

void main() {
  group('digital product store schema', () {
    late final String baseSql;
    late final String catalogSql;

    setUpAll(() {
      baseSql = _read(_baseMigration);
      catalogSql = _read(_catalogMigration);
    });

    test(
      'supports the nine requested product types with a database constraint',
      () {
        for (final type in <String>[
          'image',
          'audio',
          'video',
          'design',
          'writing',
          'prompt',
          'idea',
          'game',
          'template',
        ]) {
          expect(catalogSql, contains("'$type'"));
        }
        expect(catalogSql, contains('shop_products_product_type_check'));
      },
    );

    test('keeps paid files private and grants no direct Storage access', () {
      expect(baseSql, contains("'product-downloads'"));
      expect(baseSql, contains('public = false'));
      expect(baseSql, contains('storage.objects のポリシーは作らない'.toLowerCase()));
      expect(
        baseSql,
        contains('alter table public.shop_purchases enable row level security'),
      );
    });

    test('lets only the actual buyer read a delisted product', () {
      expect(catalogSql, contains('create policy shop_products_buyer_read'));
      expect(catalogSql, contains('purchase.user_id = (select auth.uid())'));
      expect(catalogSql, contains("purchase.status = 'paid'"));
    });

    test('bounds catalog order and rejects unsafe download names', () {
      expect(catalogSql, contains('shop_products_catalog_idx'));
      expect(catalogSql, contains('sort_order between 0 and 32767'));
      expect(catalogSql, contains("position('/' in download_file_name) = 0"));
      expect(
        catalogSql,
        contains('position(chr(92) in download_file_name) = 0'),
      );
      expect(catalogSql, contains("download_file_name !~ '[[:cntrl:]]'"));
    });
  });
}
