import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/models/investment_asset.dart';
import 'package:my_web_app/services/investment_asset_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseInvestmentAssetRepository PostgREST integration', () {
    test('reads only the requested user portfolio with its authenticated JWT',
        () async {
      late http.Request captured;
      final repository = _repository((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[_assetRow()]),
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      });

      final assets = await repository.fetchByUser(userId: ' user-a ');

      expect(assets.single.id, 'asset-1');
      expect(captured.method, 'GET');
      expect(captured.url.path, '/rest/v1/investment_assets');
      expect(captured.url.queryParameters['user_id'], 'eq.user-a');
      expect(
        captured.url.queryParameters['order'],
        'asset_type.asc.nullslast,ticker.asc.nullslast,id.asc.nullslast',
      );
      expect(captured.url.queryParameters['offset'], '0');
      expect(captured.url.queryParameters['limit'], '1000');
      expect(captured.headers['authorization'], 'Bearer user-a-jwt');
    });

    test('paginates growing portfolios with a stable order', () async {
      final captured = <http.Request>[];
      final repository = _repository((request) async {
        captured.add(request);
        final offset = request.url.queryParameters['offset'];
        final rows = offset == '0'
            ? List<Map<String, dynamic>>.generate(
                1000,
                (index) => _assetRow(id: 'asset-$index'),
              )
            : <Map<String, dynamic>>[_assetRow(id: 'asset-last')];
        return http.Response(
          jsonEncode(rows),
          200,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      });

      final assets = await repository.fetchByUser(userId: 'user-a');

      expect(assets, hasLength(1001));
      expect(captured, hasLength(2));
      expect(captured[0].url.queryParameters['offset'], '0');
      expect(captured[1].url.queryParameters['offset'], '1000');
      expect(captured[1].url.queryParameters['limit'], '1000');
      expect(
        captured[1].url.queryParameters['order'],
        'asset_type.asc.nullslast,ticker.asc.nullslast,id.asc.nullslast',
      );
    });

    test('creates rows with the authenticated owner id', () async {
      late http.Request captured;
      final repository = _repository((request) async {
        captured = request;
        return http.Response(
          jsonEncode(_assetRow()),
          201,
          headers: const {'content-type': 'application/json'},
          request: request,
        );
      });

      final created = await repository.create(
        userId: ' user-a ',
        draft: _draft(),
      );

      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(created.userId, 'user-a');
      expect(captured.method, 'POST');
      expect(payload['user_id'], 'user-a');
      expect(payload['ticker'], '7203.T');
      expect(captured.headers['authorization'], 'Bearer user-a-jwt');
    });

    test('scopes update and delete mutations to both asset and owner',
        () async {
      final captured = <http.Request>[];
      final repository = _repository((request) async {
        captured.add(request);
        if (request.method == 'PATCH') {
          return http.Response(
            jsonEncode(_assetRow(currentPriceJpy: 3100)),
            200,
            headers: const {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response('', 204, request: request);
      });

      final updated = await repository.update(
        userId: ' user-a ',
        assetId: ' asset-1 ',
        draft: _draft(currentPriceJpy: 3100),
      );
      await repository.delete(userId: ' user-a ', assetId: ' asset-1 ');

      expect(updated.currentPriceJpy, 3100);
      expect(captured, hasLength(2));
      for (final request in captured) {
        expect(request.url.queryParameters['id'], 'eq.asset-1');
        expect(request.url.queryParameters['user_id'], 'eq.user-a');
        expect(request.headers['authorization'], 'Bearer user-a-jwt');
      }
      expect(captured[0].method, 'PATCH');
      expect(captured[1].method, 'DELETE');
    });
  });
}

SupabaseInvestmentAssetRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    accessToken: () async => 'user-a-jwt',
    httpClient: MockClient(handler),
  );
  return SupabaseInvestmentAssetRepository(client: client);
}

InvestmentAssetDraft _draft({double? currentPriceJpy}) {
  return InvestmentAssetDraft(
    assetType: InvestmentAssetType.stock,
    ticker: ' 7203.t ',
    quantity: 2,
    buyPriceJpy: 2500,
    buyDate: DateTime(2026, 7, 1),
    currentPriceJpy: currentPriceJpy,
    lastPricedAt: currentPriceJpy == null ? null : DateTime.utc(2026, 7, 20, 3),
  );
}

Map<String, dynamic> _assetRow({
  String id = 'asset-1',
  double currentPriceJpy = 3000,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': 'user-a',
    'asset_type': 'stock',
    'ticker': '7203.T',
    'quantity': 2,
    'buy_price_jpy': 2500,
    'buy_date': '2026-07-01',
    'current_price_jpy': currentPriceJpy,
    'last_priced_at': '2026-07-20T03:00:00Z',
    'created_at': '2026-07-01T00:00:00Z',
    'updated_at': '2026-07-20T03:00:00Z',
  };
}
