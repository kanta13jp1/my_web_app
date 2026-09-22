import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migration =
    'supabase/migrations/20260822203000_seed_jibun_spreadsheet_product.sql';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(_migration)
        .readAsStringSync()
        .replaceAll('\r\n', '\n')
        .toLowerCase();
  });

  test('adds an application product type to catalog and intake constraints',
      () {
    expect(sql, contains("'application'"));
    expect(sql, contains('shop_products_product_type_check'));
    expect(sql, contains('artifact_candidates_artifact_kind_check'));
  });

  test('stages the exact release candidate without activating sales', () {
    expect(sql, contains("'jibun-spreadsheet-win64'"));
    expect(sql, contains("'1.0.0'"));
    expect(sql, contains('30725914'));
    expect(
      sql,
      contains(
        "'5ed8e0f8fb414d999c09f6d978012672f0e4c3f0e5e2dd89b6f2626e4e613d0f'",
      ),
    );
    expect(sql, contains("'product-downloads'"));
    expect(sql, contains('false\n)'));
  });

  test('preserves live payment and publication fields on reapply', () {
    final updateClause = sql.split('on conflict (id) do update').last;
    expect(updateClause, isNot(contains('stripe_price_id =')));
    expect(updateClause, isNot(contains('is_active =')));
    expect(updateClause, isNot(contains('published_at =')));
  });
}
