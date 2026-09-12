import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/models/shop_attribution.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';
import 'package:my_web_app/services/shop_service.dart';
import 'package:my_web_app/view_models/shop_view_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const visitor = '12345678-1234-4123-8123-123456789abc';
  final labels = ShopAttribution.parse(
    source: 'x', campaign: 'h4_h7_pitch', contentId: 'growth_game_t30_r1',
  );
  late SupabaseClient client;
  late List<http.Request> requests;
  late int responseStatus;
  late Map<String, Object> checkoutResponse;

  setUp(() {
    SharedPreferences.setMockInitialValues({'shop.visitor_id': visitor});
    requests = [];
    responseStatus = 200;
    checkoutResponse = {'checkout_url': 'https://checkout.example.invalid/test'};
    client = SupabaseClient('https://example.supabase.co', 'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(request.url.path.endsWith('/shop-checkout')
            ? checkoutResponse : {'recorded': true, 'post_recorded': true}),
          responseStatus, headers: {'content-type': 'application/json'});
      }),
    );
  });
  tearDown(() async => client.dispose());

  test('real funnel transport carries identical labels at all client stages', () async {
    final funnel = ShopFunnelService(client: client);
    for (final stage in ['product_view', 'purchase_click', 'checkout_redirect']) {
      await funnel.record(stage, productId: 'hexciv-win64', attribution: labels);
    }
    expect(requests, hasLength(3));
    for (var index = 0; index < requests.length; index++) {
      expect(requests[index].url.path, '/functions/v1/shop-funnel');
      expect(jsonDecode(requests[index].body), {
        'visitor_id': visitor, 'product_id': 'hexciv-win64',
        'stage': ['product_view', 'purchase_click', 'checkout_redirect'][index],
        ...labels.toRequest(),
      });
    }
  });

  test('unavailable attribution and client-paid claims emit no event', () async {
    final funnel = ShopFunnelService(client: client);
    await funnel.record('product_view', productId: 'hexciv-win64',
        attribution: const ShopAttribution.unavailable());
    await funnel.record('product_view', productId: 'hexciv-win64', source: 'a/b');
    await funnel.record('purchase_complete', productId: 'hexciv-win64',
        attribution: labels);
    expect(requests, isEmpty);
  });

  test('telemetry HTTP failure does not throw to the caller', () async {
    responseStatus = 503;
    await ShopFunnelService(client: client).record(
      'product_view', productId: 'hexciv-win64', attribution: labels,
    );
    expect(requests, hasLength(1));
  });

  test('view model and real checkout transport preserve product visitor and tags', () async {
    final model = ShopProductViewModel(
      gateway: ShopService(client: client), productId: 'hexciv-win64',
    );
    addTearDown(model.dispose);
    final start = await model.startCheckout(visitorId: visitor, attribution: labels);
    expect(start?.checkoutUrl, 'https://checkout.example.invalid/test');
    expect(requests.single.url.path, '/functions/v1/shop-checkout');
    expect(jsonDecode(requests.single.body), {
      'product_id': 'hexciv-win64', 'visitor_id': visitor, ...labels.toRequest(),
    });
  });

  test('bad labels suppress identity but never block checkout', () async {
    final start = await ShopService(client: client).startCheckout('hexciv-win64',
      visitorId: visitor, attribution: const ShopAttribution.unavailable(),
    );
    expect(start.alreadyPurchased, isFalse);
    expect(jsonDecode(requests.single.body), {
      'product_id': 'hexciv-win64', 'attribution_valid': false,
    });
  });

  test('legacy checkout caller retains its existing request', () async {
    await ShopService(client: client).startCheckout('hexciv-win64',
        visitorId: visitor, source: 'x');
    expect(jsonDecode(requests.single.body), {
      'product_id': 'hexciv-win64', 'visitor_id': visitor, 'source': 'x',
    });
  });

  test('already-purchased result still updates the view model without a URL', () async {
    checkoutResponse = {'already_purchased': true};
    final model = ShopProductViewModel(
      gateway: ShopService(client: client), productId: 'hexciv-win64',
    );
    addTearDown(model.dispose);
    final start = await model.startCheckout(attribution: labels);
    expect(start?.alreadyPurchased, isTrue);
    expect(start?.checkoutUrl, isNull);
    expect(model.purchased, isTrue);
  });

  test('checkout failure remains visible and clears working state', () async {
    responseStatus = 503;
    final model = ShopProductViewModel(
      gateway: ShopService(client: client), productId: 'hexciv-win64',
    );
    addTearDown(model.dispose);
    expect(await model.startCheckout(attribution: labels), isNull);
    expect(model.actionError, isNotNull);
    expect(model.working, isFalse);
  });
}
