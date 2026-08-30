import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/fx_rate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Client okClient(double jpy, {int? asOfUnix}) {
    return MockClient((request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'result': 'success',
          'rates': <String, dynamic>{'JPY': jpy, 'EUR': 0.9},
          if (asOfUnix != null) 'time_last_update_unix': asOfUnix,
        }),
        200,
      );
    });
  }

  FxRateService service(
    http.Client client, {
    DateTime Function()? now,
    Duration ttl = const Duration(hours: 12),
  }) {
    return FxRateService(
      client: client,
      prefsProvider: SharedPreferences.getInstance,
      now: now,
      ttl: ttl,
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('fetches and parses USD/JPY', () async {
    final rate =
        await service(okClient(162.39, asOfUnix: 1700000000)).getUsdJpy();
    expect(rate, isNotNull);
    expect(rate!.jpyPerUnit, 162.39);
    expect(rate.asOf.toUtc().year, 2023);
  });

  test('caches to prefs and serves cache while fresh (no 2nd fetch)', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'result': 'success',
          'rates': <String, dynamic>{'JPY': 160.0},
        }),
        200,
      );
    });
    final svc = service(client);
    final first = await svc.getUsdJpy();
    final second = await svc.getUsdJpy();
    expect(first!.jpyPerUnit, 160.0);
    expect(second!.jpyPerUnit, 160.0);
    expect(calls, 1, reason: 'fresh cache should avoid a second network call');
  });

  test('falls back to last cached rate when fetch fails', () async {
    // Seed a stale cached rate.
    final good = service(okClient(155.0));
    await good.getUsdJpy();

    // New service (fresh memory) with a failing client + forceRefresh.
    final failing = MockClient((request) async => http.Response('boom', 500));
    final svc = service(failing);
    final rate = await svc.getUsdJpy(forceRefresh: true);
    expect(rate, isNotNull);
    expect(rate!.jpyPerUnit, 155.0, reason: 'should reuse cached rate');
  });

  test('returns null when no cache and fetch fails', () async {
    final failing = MockClient((request) async => throw Exception('offline'));
    final rate = await service(failing).getUsdJpy();
    expect(rate, isNull);
  });

  test('ignores result:error payloads', () async {
    final errClient = MockClient((request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{'result': 'error', 'error-type': 'x'}),
        200,
      );
    });
    final rate = await service(errClient).getUsdJpy();
    expect(rate, isNull);
  });

  test('refetches once TTL elapses', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'result': 'success',
          'rates': <String, dynamic>{'JPY': 160.0 + calls},
        }),
        200,
      );
    });
    var clock = DateTime(2026, 1, 1, 10);
    final svc =
        service(client, now: () => clock, ttl: const Duration(hours: 1));
    final first = await svc.getUsdJpy();
    expect(first!.jpyPerUnit, 161.0);
    clock = clock.add(const Duration(hours: 2));
    final second = await svc.getUsdJpy();
    expect(second!.jpyPerUnit, 162.0);
    expect(calls, 2);
  });
}
